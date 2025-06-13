//
//  NetworkDeviceLocator.swift
//  PoCLanShield_DDE
//
//  Created by Alex - SEEMOO on 23.12.24.
//

import DeviceDiscoveryExtension
import Network
import UniformTypeIdentifiers
import OSLog

/// A DeviceLocator that uses a network browser to search for devices via Bonjour.
class NetworkDeviceLocator: DeviceLocator {
    
    static let exampleServiceType = "_example._tcp"
    
    /// The network browser used to scan for devices.
    private var browser: NWBrowser = NWBrowser(for: .bonjour(type: exampleServiceType, domain: nil), using: .tcp)
    
    let logger = Logger(subsystem: "de.tu-darmstadt.seemoo.PoCLanShield.DDE", category: "DDE_Bonjour")
    
    /// The devices known to this locator.
    private var knownDevices: [DDDevice] = []
    
    init() {
    }
    
    func setupBrowser() {
        // An example Bonjour service type for the device for which to scan.
        // This must match a value contained within the NSBonjourServices array in the extension's Info.plist.
        
        
        // Create a network browser to search for devices.
        
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        browser = NWBrowser(for: .bonjour(type: NetworkDeviceLocator.exampleServiceType, domain: nil), using: .tcp)
        logger.info("Initialized NWBrowser")
    }
    
    /// The event handler that passes events back to the session.
    var eventHandler: DDEventHandler?
    
    /// Start scanning for devices using the network browser.
    func startScanning() {
        if browser.state == .cancelled {
            setupBrowser()
        }
        
        logger.info("Starting Bonjour Browser")
        browser.browseResultsChangedHandler = {[weak self] results, changes in
            self?.logger.info("Got result \(results, privacy: .public)")
            for result in results {
                self?.didDiscover(result)
            }
            

        }
        
        
        browser.stateUpdateHandler = { [weak self] browserState in
            self?.logger.info("Browser state is \(String(describing: browserState), privacy: .public)")
        }
        
        
        
        
        knownDevices = []
        browser.start(queue: .global(qos: .default))
        sendDummyDeviceEvent()
    }
    
    func sendDummyDeviceEvent() {
        logger.info("Sending Dummy Device")
        let event = DDDeviceEvent(eventType: .deviceFound, device: DDDevice(displayName: "Attack Running", category: .tv, protocolType: .audio, identifier: "Dummy"))
        eventHandler?(event)
    }
    
    /// Stop scanning for devices using the network browser.
    func stopScanning() {
        logger.info("Stopped Bonjour Browser")
        browser.cancel()
        
        browser.browseResultsChangedHandler = nil
        
        if let eventHandler = eventHandler {
            for device in knownDevices {
                let event = DDDeviceEvent(eventType: .deviceLost, device: device)
                eventHandler(event)
            }
        }
        knownDevices.removeAll()
    }
    
    /// Inform the session of the device state represented by the result.
    func didDiscover(_ result: NWBrowser.Result) {
        logger.info("Did discover device \(result.endpoint.debugDescription)")
        
        // If no event handler is set, don't report anything.
        guard let eventHandler = eventHandler else {
            return
        }
        
        // An example device identifier and name for the discovered device.
        // It's important that this come from or be associated with the device itself.
        let exampleDeviceUUID = UUID()
        let exampleDeviceIdentifier = exampleDeviceUUID.uuidString
        let exampleDeviceName = result.endpoint.debugDescription
        
        // An example protocol for the discovered device.
        // This must match the type declared in the extension's Info.plist.
        guard let exampleDeviceProtocol = UTType("de.tu-darmstadt.example-protocol") else {
            fatalError("Misconfiguration: UTType for protocol not defined.")
        }
        
        // Create a DDDevice instance representing the device.
        let device = DDDevice(displayName: exampleDeviceName, category: .tv, protocolType: exampleDeviceProtocol, identifier: exampleDeviceIdentifier)
        device.networkEndpoint = result.endpoint
        
        knownDevices.append(device)
        
        // Pass it to the event handler.
        
        let event = DDDeviceEvent(eventType: .deviceFound, device: device)
        eventHandler(event)
        
        // Send it to the UDP socket
        
        let udpMessage = "Bonjour scan result: \(exampleDeviceName); \(result.endpoint.debugDescription)"
        sendTextViaUDP(udpMessage)
        
        
    }
}
