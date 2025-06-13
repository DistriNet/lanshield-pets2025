//
//  IPCLocalSocket.swift
//  Client
//
//  Created by Alex - SEEMOO on 08.07.24.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import Network
import os

class IPCLocalSocket: NSObject, ObservableObject {
    static let shared = IPCLocalSocket()
    let logger = Logger(subsystem: "de.tu-darmstadt.IPC", category: "IPCSocket")
    var socket: NWListener?
    
    var connections = [NWConnection]()
    
    @Published var receivedMessages: [String] = []
    
    override init() {
        super.init()
    }

    func setupSocket() throws {
        if let socket = self.socket,
           socket.state == .cancelled {
            
            return
        }
        
        let nwSocket = try NWListener(using: .udp, on: .init(rawValue: 5003)!)
        nwSocket.newConnectionHandler = self.newConnection(_:)
        nwSocket.stateUpdateHandler = self.stateChanged(_:)
        nwSocket.start(queue: .global(qos: .default))
        self.socket = nwSocket
        logger.debug("Setup new socket")
    }
    
    func newConnection(_ connection: NWConnection) {
        self.connections.append(connection)
        logger.debug("New incoming connection from \(connection.debugDescription, privacy: .public)")
        connection.stateUpdateHandler = { state in
            self.logger.debug("Incoming connection state is \(String(describing: state))")
            switch state {
            case .ready:
                connection.receiveMessage { content, contentContext, isComplete, error in
                    self.logger.debug("Receiving message")
                    if let content,
                       let contentMsg = String(data: content, encoding: .utf8) {
                        self.logger.debug("Received message over UDP.")
                        self.logger.debug("Message content: \(contentMsg, privacy: .public)")
                        if contentMsg.lowercased() != "ping" {
                            DispatchQueue.main.async {
                                self.receivedMessages.append(contentMsg)
                            }
                        }
                    }else {
                        self.logger.debug("Received empty message")
                    }
                }
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .default))
    }
    
    func stateChanged(_ state: NWListener.State) {
        logger.debug("NWListener state changed \(String(describing: state), privacy: .public)")
        switch state {
        case .ready:
            sendPing()
        default:
            break
        }
    }
    
    func sendPing() {
        let connection = NWConnection(to: .hostPort(host: "localhost", port: .init(integerLiteral: 5003)), using: .udp)
        let content = "ping".data(using: .utf8)
        connection.start(queue: .global(qos: .default))
        connection.stateUpdateHandler = { state in
            self.logger.debug("Connection state is \(String(describing: state))")
            switch state {
            case .ready:
                connection.send(content: content, completion: .contentProcessed({ error in
                    if let error {
                        self.logger.error("Failed sending UDP \(error.localizedDescription, privacy: .public)")
                    }else {
                        self.logger.debug("Sent Ping message")
                    }
                }))
            default:
                break
            }
        }
    }
    
}
