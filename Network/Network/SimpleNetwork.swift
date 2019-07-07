//
//  Network.swift
//  Infra
//
//  Created by Peter Livesey on 3/23/19.
//  Copyright © 2019 Aspen Designs. All rights reserved.
//

import Foundation

class SimpleNetwork {
    static let shared = SimpleNetwork()

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
    let session: URLSession = URLSession()

    // MARK: - API

    /**
     Sends a data request and parses the result into a model. To specify the model type, you'll need to include the type in your completion block.

     For instance:

     ```Network.shared.send(request) { result: Result<MyModel, Error> in ```
     */
    func send<T: Model>(_ request: Requestable, completion: @escaping (Result<T, Error>)->Void) {
        // Go to a background queue as request.urlRequest() may do json parsing
        DispatchQueue.global(qos: .userInitiated).async {
            let urlRequest = request.urlRequest()

            Log.verbose("Send: \(urlRequest.url?.absoluteString ?? "") - \(urlRequest.httpMethod ?? "")")

            // Send the request
            let task = self.session.dataTask(with: urlRequest) { data, response, error in
                let result: Result<T, Error>

                if let error = error {
                    // First, check if the network just returned an error
                    result = .failure(error)
                } else if let error = self.error(from: response) {
                    // Next, check if the status code was valid
                    result = .failure(error)
                } else if let data = data {
                    // Otherwise, let's try parsing the data
                    do {
                        let decoder = JSONDecoder()
                        result = .success(try decoder.decode(T.self, from: data))
                    } catch {
                        result = .failure(error)
                    }
                } else {
                    Log.assertFailure("Missing both data and error from NSURLSession. This should never happen.")
                    result = .failure(NetworkError.noDataOrError)
                }

                DispatchQueue.main.async {
                    completion(result)
                }
            }

            task.resume()
        }
    }

    // MARK: Helpers

    private func error(from response: URLResponse?) -> Error? {
        guard let response = response as? HTTPURLResponse else {
            Log.assertFailure("Missing http response when trying to parse a status code.")
            return nil
        }

        let statusCode = response.statusCode

        if statusCode >= 200 && statusCode <= 299 {
            return nil
        } else {
            Log.error("Invalid status code from \(response.url?.absoluteString ?? "unknown"): \(statusCode)")
            return StatusCodeError(code: statusCode)
        }
    }
}
