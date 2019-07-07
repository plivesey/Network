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

    }
}

