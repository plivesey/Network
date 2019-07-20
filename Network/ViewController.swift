//
//  ViewController.swift
//  Network
//
//  Created by Peter Livesey on 6/29/19.
//  Copyright © 2019 PeterLivesey. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet var label: UILabel!

    @IBAction func sendGETRequest() {
        label.text = "Loading..."

        let request = Request(path: "users/1")
        Network.shared.send(request) { (result: Result<User, Error>) in
            switch result {
            case .success(let user):
                self.label.text = "\(user)"
            case .failure(let error):
                self.label.text = error.localizedDescription
            }
        }
    }

    @IBAction func sendPOSTRequest() {
        label.text = "Loading..."

        let newUser = User(id: 2, name: "Peter", username: "Livesey", email: "941ecfff8dc3@medium.com")
        let request = PostRequest(path: "/users", method: "POST", model: newUser)
        Network.shared.send(request) { (result: Result<Empty, Error>) in
            switch result {
            case .success:
                self.label.text = "Got an empty, successful result"
            case .failure(let error):
                self.label.text = error.localizedDescription
            }
        }
    }
}

