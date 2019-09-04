//
//  TCPSocketClient.swift
//  LDSoketClientDemo
//
//  Created by lidong on 2019/9/3.
//  Copyright © 2019年 macbook. All rights reserved.
//

import UIKit
import CocoaAsyncSocket

enum SocketConnectStatus {
    case disconnected /// 未连接
    case connecting /// 连接中
    case connected /// 已连接
}

protocol TCPSocketClientDelegate {
    /// 读取数据
    func socket(_ socket: TCPSocketClient, didReadData: Data);
    /// 链接状态发生变化
    func socket(_ socket: TCPSocketClient, connectStatus: SocketConnectStatus);
}

/// 向需要发送的数据包前面插入指定长度的数据包，
/// 便于服务端拆包，
/// 数据包内包含需要发送数据的长度
/// (需要和服务端配合决定)
private let headDataLength = 4

class TCPSocketClient: NSObject {

    /// Socket单例
    static let shareSocket: TCPSocketClient = TCPSocketClient()
    
    /// 代理
    private var delegate: TCPSocketClientDelegate?
    
    /// socket
    private var clientSocket: GCDAsyncSocket?
    
    /// 地址
    private var host: String?
    
    /// 端口号
    private var port: UInt16?
    
    /// 是否已经链接
    private var _isConnection: Bool = false
    
    /// 心跳Timer
    private var heartTimer: Timer?
    
    /// 链接服务器并设置代理
    ///
    /// - Parameters:
    ///   - delegate: 代理回调接受者
    ///   - toHost: 服务器地址
    ///   - onPort: 端口号
    func connectServerWithDelegate(_ delegate: TCPSocketClientDelegate, toHost host: String, onPort port: UInt16) {
        self.clientSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        self.delegate = delegate
        self.host = host
        self.port = port
        self.connectServer()
    }
    
    /// 链接服务
    private func connectServer() {
        guard let clientSocket = self.clientSocket, let host = self.host, let port = self.port else { return }
        do {
            try clientSocket.connect(toHost: host, onPort: port)
            print("连接成功")
        } catch {
            print("连接失败")
        }
        clientSocket.readData(withTimeout: -1, tag: 0)
    }
    
    /// 断开连接
    func disconnectServer() {
        self.clientSocket?.disconnect()
    }
    
    /// 发送消息
    ///
    /// - Parameters:
    ///   - data: 发送的数据
    ///   - tag: 发送标识
    func sendData(_ data: Data, tag: Int) {
        if _isConnection {
            
            /// 最终发送的数据包
            let sendData = NSMutableData()
            /// 需要发送数据的长度
            var dataLength = data.count
            /// 通过数据的长度生成一个包含数据长度的data，
            let lengthData = Data(bytes: &dataLength, count: dataLength)
            
            /// 需要在头部插入的数据包
            var newLengthData = Data()
            if (dataLength == 0) {
                newLengthData = Data(repeating: 0, count: headDataLength)
            } else if (dataLength < headDataLength) {
                newLengthData.append(lengthData)
                newLengthData.append(Data(repeating: 0, count: headDataLength - dataLength))
            } else {
                newLengthData = lengthData.subdata(in: Range(NSRange(location: 0, length: headDataLength))!)
            }
            
            sendData.append(newLengthData)
            sendData.append(data)
            let newSendData = sendData.copy() as! Data
            
            self.clientSocket?.write(newSendData, withTimeout: -1, tag: tag)
        }
    }
    
    /// 是否是链接状态
    ///
    /// - Returns: 链接状态
    func isConnection() -> Bool {
        return _isConnection
    }
    
    /// 发送心跳
    func beginSendHeartBeat() {
        self.heartTimer?.invalidate()
        self.heartTimer = nil
        self.heartTimer = Timer(timeInterval: 5, target: self, selector: #selector(sendHeartBeat(_:)), userInfo: nil, repeats: true)
        RunLoop.current.add(self.heartTimer!, forMode: .common)
    }
    
    /// 发送心跳数据包
    ///
    /// - Parameter timer: Timer
    @objc private func sendHeartBeat(_ timer: Timer) {
        
        /// 心跳数据包 (和服务端确认过发送格式)
        let heartBeat: [UInt8] = [0xab, 0xcd, 0x00, 0x00]
        let heartBeatData = Data(bytes: heartBeat, count: heartBeat.count)
        
        /// 心跳数据包 前面加入headDataLength个字节长度，用于拆包
        var newHeartBeatData = Data(bytes: heartBeat, count: headDataLength)
        newHeartBeatData.append(heartBeatData)
        self.clientSocket?.write(newHeartBeatData, withTimeout: -1, tag: 0)
    }
    
}

extension TCPSocketClient: GCDAsyncSocketDelegate {
 
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("链接成功")
        _isConnection = true
        self.delegate?.socket(self, connectStatus: .connected)
        sock.readData(withTimeout: -1, tag: 0)
        self.beginSendHeartBeat()
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("断开链接")
        _isConnection = false
        self.delegate?.socket(self, connectStatus: .disconnected)
        if self.heartTimer != nil {
            self.heartTimer?.invalidate()
            self.heartTimer = nil
        }
        self.clientSocket?.delegate = nil
        self.clientSocket = nil
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        let serverString = String(data: data, encoding: .utf8)
        print("服务端回包了--内容--\(serverString ?? "")---长度--\(data.count)")
        self.delegate?.socket(self, didReadData: data)
        sock.readData(withTimeout: -1, tag: 0)
    }
    
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        print("socket did write data tag = \(tag) \n")
    }

}
