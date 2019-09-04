//
//  TCPSocketServer.swift
//  LDSocketServerDemo
//
//  Created by lidong on 2019/9/3.
//  Copyright © 2019年 macbook. All rights reserved.
//

import UIKit
import CocoaAsyncSocket

/// 向需要发送的数据包前面插入指定长度的数据包，
/// 便于服务端拆包，
/// 数据包内包含需要发送数据的长度
/// (需要和服务端配合决定)
private let headDataLength = 4

class TCPSocketServer: NSObject {

    /// 服务端Socket
    private var serverSocket: GCDAsyncSocket?
    
    /// 常驻线程
    private var checkThread: Thread?
    
    /// 所有已连接的客户端
    private lazy var clients: [GCDAsyncSocket] = [GCDAsyncSocket]()
    
    /// 所有客户端心跳信息
    private lazy var heartBeatDateDic: [String: Date] = [String: Date]()
    
    /// 数据缓冲区
    private lazy var dataBuffer: NSMutableData = NSMutableData()
    
    /// Socket单例
    static let shareSocket: TCPSocketServer = TCPSocketServer()
    
    /// 打开服务器端口
    ///
    /// - Parameter port: 目标端口
    func openServer(withPort port: UInt16) {
        self.serverSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        do {
            try self.serverSocket?.accept(onPort: port)
            print("打开端口号成功")
        } catch {
            print("打开端口号失败")
        }
        self.checkClientOnline()
    }
    
    /// 发送数据包
    ///
    /// - Parameters:
    ///   - data: 数据包
    ///   - tag: 数据包标识
    func sendData(_ data: Data, withTag tag: Int) {
        self.serverSocket?.write(data, withTimeout: -1, tag: tag)
        
    }
    
    /// 添加检查心跳的timer
    @objc private func checkClientOnline() {
        let timer = Timer(timeInterval: 10, target: self, selector: #selector(repeatCheckClinetOnline), userInfo: nil, repeats: true)
        RunLoop.current.add(timer, forMode: .common)
    }
    
    /// 检查所有链接的socket心跳,超过指定的时间视为断开连接
    @objc private func repeatCheckClinetOnline() {
        if self.clients.count == 0 { return }
        for i in 0..<self.clients.count {
            autoreleasepool {
                let socket = self.clients[i]
                if let connectedHost = socket.connectedHost, let heartBeatDate = self.heartBeatDateDic[connectedHost] {
                    let date = Date()
                    if date.timeIntervalSince(heartBeatDate) > 10 {
                        self.clients.remove(at: i)
                    }
                }
            }
        }
    }
    
    /// 处理已读消息
    ///
    /// - Parameters:
    ///   - data: 数据包
    ///   - socket: 客户端socket
    private func handleData(_ data: Data, socket: GCDAsyncSocket) {
        /// 心跳数据包 (和服务端确认过发送格式)
        let heartBeat: [UInt8] = [0xab, 0xcd, 0x00, 0x00]
        let heartBeatData = Data(bytes: heartBeat, count: heartBeat.count)
        
        if (data == heartBeatData) {
            print("**************心跳**************")
            guard let connectedHost = socket.connectedHost else { return }
            self.heartBeatDateDic[connectedHost] = Date()
        } else {
            let clientString = String(data: data, encoding: .utf8)
            print("客户端内容---\(clientString ?? "") 长度----\(data.count)")
        }
    }
    
}

extension TCPSocketServer: GCDAsyncSocketDelegate {
    
    /// 当有新的客户端链接时调用
    ///
    /// - Parameters:
    ///   - sock: 服务端socket
    ///   - newSocket: 新链接的socket
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        print("\(newSocket) IP: \(newSocket.connectedHost ?? "") PORT: \(newSocket.localPort)")
        if !self.clients.contains(newSocket) {
            self.clients.append(newSocket)
        }
        self.serverSocket?.readData(withTimeout: -1, tag: 0)
    }
    
    /// 读取客户端发送的消息
    ///
    /// - Parameters:
    ///   - sock: 服务端socket
    ///   - data: 数据包
    ///   - tag: 数据包标识
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        /// 数据存入缓冲区
        self.dataBuffer.append(data)
        /// 如果长度大于headDataLength个字节，表示有数据包。headDataLength字节为包头，存储包内数据长度
        while self.dataBuffer.length >= headDataLength {
            /// 获取包头，并获取长度
            var dataLength = 0
            let headData = self.dataBuffer.subdata(with: NSRange(location: 0, length: 4)) as NSData
            headData.getBytes(&dataLength, length: dataLength)
            /// 判断缓存区内是否有包
            if self.dataBuffer.length >= (dataLength + 4) {
                /// 获取去掉包头的数据
                let realData = self.dataBuffer.subdata(with: NSRange(location: 4, length: 4 + dataLength))
                /// 解析处理
                self.handleData(realData, socket: sock)
                /// 移除已经拆过的包
                self.dataBuffer = NSMutableData(data: self.dataBuffer.subdata(with: NSRange(location: dataLength + 4, length: self.dataBuffer.length - (dataLength + 4))))
            }
        }
        sock.readData(withTimeout: -1, tag: tag)
    }
    
    /// 断开连接时调用
    ///
    /// - Parameters:
    ///   - sock: 服务端socket
    ///   - err: 错误信息
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("ServerSocket断开连接")
    }
}
