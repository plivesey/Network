//
//  NetworkTask.swift
//  Infra
//
//  Created by Peter Livesey on 5/23/19.
//  Copyright © 2019 Aspen Designs. All rights reserved.
//

import Foundation

/**
 A semi-opaque object returned by the Network stack which allows you to cancel requests.
 Note: when you call cancel, the task may not yet have started. But as soon as it does start, it will immediately cancel.
 */
class NetworkTask {
    var task: URLSessionTask?
    var cancelled = false

    let queue = DispatchQueue(label: "com.peterlivesey.networkTask", qos: .utility)

    func cancel() {
        queue.sync {
            cancelled = true

            if let task = task {
                task.cancel()
            }
        }
    }
    
    func set(_ task: URLSessionTask) {
        queue.sync {
            self.task = task

            if cancelled {
                task.cancel()
            }
        }
    }
}
