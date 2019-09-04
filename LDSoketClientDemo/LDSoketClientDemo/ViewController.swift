//
//  ViewController.swift
//  LDSoketClientDemo
//
//  Created by lidong on 2019/9/3.
//  Copyright © 2019年 macbook. All rights reserved.
//

import UIKit
import CocoaAsyncSocket

class ViewController: UIViewController {

    @IBOutlet weak var connectStatus: UILabel!
    
    @IBOutlet weak var textField: UITextField!
    
    @IBOutlet weak var messageLabel: UILabel!
    
    @IBAction func connect(_ sender: UIButton) {
        
    }
    
    @IBAction func disconnect(_ sender: UIButton) {
        
    }
    @IBAction func sendMsg(_ sender: UIButton) {
        let text = "你好"
        let data = text.data(using: .utf8)
        TCPSocketClient.shareSocket.sendData(data!, tag: 1)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        /// 可以通过命令 nc -lk 6666 来监听消息传递情况
        TCPSocketClient.shareSocket.connectServerWithDelegate(self, toHost: "192.168.31.113", onPort: 6666)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.textField.resignFirstResponder()
    }
    
}

extension ViewController: TCPSocketClientDelegate {
    func socket(_ socket: TCPSocketClient, didReadData: Data) {
        
    }
    
    func socket(_ socket: TCPSocketClient, connectStatus: SocketConnectStatus) {
        
    }
    
    
}
