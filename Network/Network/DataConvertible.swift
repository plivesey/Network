//
//  DataConvertible.swift
//  Infra
//
//  Created by Peter Livesey on 5/22/19.
//  Copyright © 2019 Aspen Designs. All rights reserved.
//

import Foundation

/**
 A protocol for anything which can be created with data. Anything that adheres to this protocol can be returned by the network stack.
 If you want the network stack to handle a new type, just make that type adhere to this protocol.
 */
protocol DataConvertible {
    /**
     Convert data into an instance of yourself. Throw an error if this fails.
     */
    static func convert(from data: Data?) throws -> Self
}

/**
 A version of data convertible which first checks if data is nil. If it is, it will throw an error.
 */
protocol RequiredDataConvertible: DataConvertible {
    /**
     Convert data into an instance of yourself. Throw an error if this fails.
     */
    static func convert(from data: Data) throws -> Self
}

/**
 A simple error to throw if your data fails to convert.
 */
struct DataConversionError: Error {
    let message: String
}

/**
 This extension automatically unwraps data and throws an error if it's nil.
 */
extension RequiredDataConvertible {
    static func convert(from data: Data?) throws -> Self {
        if let data = data {
            return try convert(from: data)
        } else {
            throw DataConversionError(message: "Failed to get data from the server.")
        }
    }
}

/**
 Data itself is convertible by just returning itself.
 */
extension Data: RequiredDataConvertible {
    static func convert(from data: Data) throws -> Data {
        return data
    }
}

/**
 Also, optional data is convertible. This means if not data is returned, it will not error.
 */
extension Optional: DataConvertible where Wrapped == Data {
    static func convert(from data: Data?) throws -> Data? {
        return data
    }
}

/**
 Strings are data convertible.
 */
extension String: RequiredDataConvertible {
    static func convert(from data: Data) throws -> String {
        if let result = String(data: data, encoding: .utf8) {
            return result
        } else {
            throw DataConversionError(message: "Failed to parse data into a utf8 string.")
        }
    }
}

/**
 Use this whenever you don't care about what's returned by the network.
 */
struct Empty: DataConvertible {
    static func convert(from data: Data?) throws -> Empty {
        return Empty()
    }
}

/**
 I'd really like to write code like: `extension Decodable: DataConvertible`. Sadly, this is impossible in swift. So, we're using type erasure here to wrap the model in an object which does adhere to `DataConvertible`.
 There's a helper function in Network which wraps and unwraps this.
 */
struct DecodableConvertible<T: Decodable>: RequiredDataConvertible {
    let model: T

    init(_ model: T) {
        self.model = model
    }

    static func convert(from data: Data) throws -> DecodableConvertible<T> {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let model = try decoder.decode(T.self, from: data)
        return DecodableConvertible(model)
    }
}
