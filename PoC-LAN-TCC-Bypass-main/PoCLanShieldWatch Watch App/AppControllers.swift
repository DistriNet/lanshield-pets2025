//
//  AppControllers.swift
//  PoC-LanShield
//
//  Created by Alex - SEEMOO on 20.12.24.
//

import Foundation
import os
import SwiftUI
import WatchConnectivity

class WatchController: NSObject, WCSessionDelegate {
    static let shared = WatchController()
    
    let session: WCSession
    
    private override init() {
        
        session = WCSession.default

        super.init()
        
        session.delegate = self
        session.activate()
    }
    
    func activate() {
        session.activate()
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        os_log(.debug, "Watch activation state: \(String(describing: activationState))")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if let command = message["command"] as? String {
            if command == "router" {
                Task {
                    await AttackController.shared.startRouterAttack()
                    replyHandler(["log": AttackController.shared.log])
                }
            }else if command == "bonjour", let service = message["service"] as? String {
                Task {
                    await AttackController.shared.startDiscoveryAttack(service: service)
                    replyHandler(["log": AttackController.shared.log])
                }
            }
        }
    }
    
}


class AttackController: ObservableObject {
    static let shared = AttackController()
    
    @Published var appState: AppState = .waiting
    @Published var log = ""
    @Published var routerAttack: RouterExploit?
    @Published var bonjourAttack: DataExtractionExploit?
    
    func startRouterAttack() async {
        await MainActor.run {
            appState = .runningRouter
        }
        
        
        do {
            let routerAttack = RouterExploit(baseURL: URL(string: "http://192.168.1.1")!)
            await MainActor.run {
                log = routerAttack.log
                self.routerAttack = routerAttack
            }
            try await routerAttack.start()
            await MainActor.run {
                self.log = routerAttack.log
                self.appState = .done
            }
        }catch {
            os_log(.error, "Failed with error \(error)")
            self.log += "Failed with error \(error)"
        }
        
    }
    
    func startDiscoveryAttack(service: String) async {
        let extractionExploit = DataExtractionExploit()
        bonjourAttack = extractionExploit
        
        do {
            self.appState = .runningDiscovery
            try await extractionExploit.startAudioStreamingAndBonjour(service: service)
        }catch {
            self.bonjourAttack?.log += "Failed with error \(error)"
        }
        
        self.log = extractionExploit.log
        self.appState = .done
    }
}

enum AppState {
    case waiting
    case runningRouter
    case runningDiscovery
    case done
}

