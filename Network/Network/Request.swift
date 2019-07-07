//
//  Request.swift
//  Infra
//
//  Created by Peter Livesey on 3/23/19.
//  Copyright © 2019 Aspen Designs. All rights reserved.
//

import Foundation

/**
 A protocol to wrap request objects. This gives us a better API over URLRequest.
 */
protocol Requestable {
    /**
     Generates a URLRequest from the request. This will be run on a background thread so model parsing is allowed.
     */
    func urlRequest() -> URLRequest

    /**
     Optional. Return additional request options. The default value is nil which indicates no special request options.
     */
    func requestOptions() -> RequestOptions?
}

extension Requestable {
    func requestOptions() -> RequestOptions? {
        return nil
    }
}

/**
 This struct is intended for any options which affect how the request is handled.
 These options are persisted for the lifetime of the request while the request itself is discarded fater it's sent.
 */
struct RequestOptions {
    let followRedirects: Bool

    init(followRedirects: Bool = true) {
        self.followRedirects = followRedirects
    }
}

/**
 A simple request with no post data.
 */
struct Request: Requestable {
    let path: String
    let method: String
    let options: RequestOptions?

    init(path: String, method: String = "GET", options: RequestOptions? = nil) {
        self.path = path
        self.method = method
        self.options = options
    }

    func urlRequest() -> URLRequest {
        guard let url = URL(string: "https://jsonplaceholder.typicode.com")?.appendingPathComponent(path) else {
            Log.assertFailure("Failed to create base url")
            return URLRequest(url: URL(fileURLWithPath: ""))
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method

        return urlRequest
    }

    func requestOptions() -> RequestOptions? {
        return self.options
    }
}

/**
 A request which includes post data. This should be the form of an encodeable model.
 */
struct PostRequest<Model: Encodable>: Requestable {
    let path: String
    let method: String
    let model: Model

    func urlRequest() -> URLRequest {
        guard let url = URL(string: "https://jsonplaceholder.typicode.com")?.appendingPathComponent(path) else {
            Log.assertFailure("Failed to create base url")
            return URLRequest(url: URL(fileURLWithPath: ""))
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method

        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let data = try encoder.encode(model)
            urlRequest.httpBody = data
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } catch let error {
            Log.assertFailure("Post request model parsing failed: \(error.localizedDescription)")
        }

        return urlRequest
    }
}

/**
 Making URLRequest also conform to request so it can be used with our stack.
 */
extension URLRequest: Requestable {
    func urlRequest() -> URLRequest {
        return self
    }
}
