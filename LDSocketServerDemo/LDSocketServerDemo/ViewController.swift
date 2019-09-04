//
//  ViewController.swift
//  LDSocketServerDemo
//
//  Created by lidong on 2019/9/3.
//  Copyright © 2019年 macbook. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBAction func sendMsg(_ sender: UIButton) {
        let text = "你好"
        let data = text.data(using: .utf8)
        TCPSocketServer.shareSocket.sendData(data!, withTag: 1)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        TCPSocketServer.shareSocket.openServer(withPort: 8888)
    }


}

