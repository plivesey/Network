//
//  Network.swift
//  Infra
//
//  Created by Peter Livesey on 3/23/19.
//  Copyright © 2019 Aspen Designs. All rights reserved.
//

import Foundation

class Network: NSObject, URLSessionTaskDelegate {
    static let shared = Network()

    enum NetworkError: Error {
        case noDataOrError
    }

    struct StatusCodeError: LocalizedError {
        let code: Int

        var errorDescription: String? {
            return "An error occurred communicating with the server. Please try again."
        }
    }

    /**
     The session that the app uses. Since it uses delegate: self, it must be declared lazy. You should never change this.
     */
    lazy var session: URLSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    /**
     Stores the options for each task if necessary. Since dictionaries are not thread safe, we need to wrap this.
     */
//    let taskOptions = ThreadSafe([URLSessionTask: RequestOptions]())

    // MARK: - API

    /**
     Sends a data request and parses the result into a model. To specify the model type, you'll need to include the type in your completion block.

     For instance:

     ```Network.shared.send(request) { result: Result<MyModel, Error> in ```

     See also `sendRPC` in Network+RPC.swifts
     */
    @discardableResult
    func send<T: Model>(_ request: Requestable, completion: @escaping (Result<T, Error>)->Void) -> NetworkTask {
        return send(request) { (result: Result<DecodableConvertible<T>, Error>) in
            completion(result.map { $0.model })
        }
    }

    /**
     Send a request and return anything which is DataConvertible. See DataConvertible.swift for a full list of types.

     If you don't care about what's returned, you should expect: Result<Empty, Error>.
     */
    @discardableResult
    func send<T: DataConvertible>(_ request: Requestable,
                                         completion: @escaping (Result<T, Error>)->Void) -> NetworkTask {
        return send(request) { (result: Result<T, Error>, _) in
            completion(result)
        }
    }

    /**
     Send a request and return anything which is DataConvertible. See DataConvertible.swift for a full list of types.

     This function also returns an HTTPURLResponse if it was received.

     If you don't care about what's returned, you should expect: Result<Empty, Error>.
     */
    @discardableResult
    func send<T: DataConvertible>(_ request: Requestable,
                                         completion: @escaping (Result<T, Error>, HTTPURLResponse?)->Void) -> NetworkTask {
        return send(request,
                    taskCreator: { urlRequest, completion in self.session.dataTask(with: urlRequest,
                                                                                   completionHandler: completion) },
                    dataConvertor: { try T.convert(from: $0) },
                    completion: completion)
    }

    /**
     Downloads a file directly to disk and saves it at the location specified.
     */
    @discardableResult
    func download(_ request: Requestable,
                         destination: URL,
                         unzip: Bool = false,
                         completion: @escaping (Result<Void, Error>)->Void) -> NetworkTask {
        return download(request, destination: destination, unzip: unzip) { (result, _) in
            completion(result)
        }
    }

    /**
     Downloads a file directly to disk and saves it at the location specified.

     This function also returns an HTTPURLResponse if it was received.
     */
    @discardableResult
    func download(_ request: Requestable,
                         destination: URL,
                         unzip: Bool = false,
                         completion: @escaping (Result<Void, Error>, HTTPURLResponse?)->Void) -> NetworkTask {
        return send(request,
                    taskCreator: { urlRequest, completion in self.session.downloadTask(with: urlRequest,
                                                                                       completionHandler: completion) },
                    dataConvertor: { try self.moveFile(from: $0, to: destination) },
                    completion: completion)
    }

    // MARK: - Main Networking Logic

    /**
     A wrapper function which allows us to send all of our requests down the same path. The syntax is a bit confusing, but that's ok because it's private.

     The taskCreator should create a URLSessionTask from a URLRequest and a completion block.
     The dataConvertor converts data to the expected return type.
     */
    private func send<DataType, ReturnType>(_ request: Requestable,
                                            taskCreator: @escaping ((URLRequest, @escaping (DataType?, URLResponse?, Error?)->Void)->URLSessionTask),
                                            dataConvertor: @escaping (DataType) throws -> ReturnType,
                                            completion: @escaping (Result<ReturnType, Error>, HTTPURLResponse?)->Void) -> NetworkTask {
        // Create a network task to immediately return
        let networkTask = NetworkTask()

        // Go to a background queue as request.urlRequest() may do json parsing
        DispatchQueue.global(qos: .userInitiated).async {
            let urlRequest = request.urlRequest()

            Log.verbose("Send: \(urlRequest.url?.absoluteString ?? "") - \(urlRequest.httpMethod ?? "")")

            let task = taskCreator(urlRequest) { data, response, error in
                let result: Result<ReturnType, Error>

                if let error = error {
                    result = .failure(error)
                } else if let error = self.error(from: response, with: request) {
                    result = .failure(error)
                } else if let data = data {
                    do {
                        let returnType = try dataConvertor(data)
                        result = .success(returnType)
                    } catch let error {
                        result = .failure(error)
                    }
                } else {
                    Log.assertFailure("Missing both data and error from NSURLSession. This should never happen.")
                    result = .failure(NetworkError.noDataOrError)
                }

                let urlToLog = urlRequest.url?.absoluteString ?? ""
                if case let .failure(error) = result {
                    Log.error("Request failed: \(urlToLog) - \(error)")
                } else {
                    Log.verbose("Request succeeded: \(urlToLog)")
                }

                DispatchQueue.main.async {
                    completion(result, response as? HTTPURLResponse)
                }
            }

//            if let options = request.requestOptions() {
//                self.taskOptions.access { $0[task] = options }
//            }

            task.resume()

            // Asyncronously set the real task inside the network task.
            // Note: This may happen after the NetworkTask has been cancelled but the NetworkTask object already handles this
            networkTask.set(task)
        }

        return networkTask
    }

    // MARK: Helpers

    private func error(from response: URLResponse?, with request: Requestable) -> Error? {
        guard let response = response as? HTTPURLResponse else {
            Log.assertFailure("Missing http response when trying to parse a status code.")
            return nil
        }

        let statusCode = response.statusCode

        let followRedirects = request.requestOptions()?.followRedirects ?? false
        let maxStatusCode = followRedirects ? 299 : 399
        if statusCode >= 200 && statusCode <= maxStatusCode {
            return nil
        } else {
            Log.error("Invalid status code from \(response.url?.absoluteString ?? "unknown"): \(statusCode)")
            return StatusCodeError(code: statusCode)
        }
    }

    // MARK: - File Handling

    private func moveFile(from origin: URL, to destination: URL) throws {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.moveItem(at: origin, to: destination)
    }

    // MARK: - Session Delegate

//    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
//        let shouldRedirect = taskOptions.access { return $0[task]?.followRedirects ?? true }
//        completionHandler(shouldRedirect ? request : nil)
//    }
//
//    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
//        taskOptions.access { $0[task] = nil }
//    }
}
