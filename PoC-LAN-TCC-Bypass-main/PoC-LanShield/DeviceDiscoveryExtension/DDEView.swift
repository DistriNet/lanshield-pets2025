//
//  DDEView.swift
//  PoC-LanShield
//
//  Created by Alex - SEEMOO on 23.12.24.
//
import Foundation
import SwiftUI
import AVFoundation
import os

struct DDEView: View {
    
    @ObservedObject var socket = IPCLocalSocket.shared
    
    var discoveredDevices: [String] {
        socket.receivedMessages.filter{$0.contains("Bonjour") || $0.contains("Bluetooth")}
    }
    
    var attackStateUpdates: [String] {
        socket.receivedMessages.filter{$0.contains("Router")}
    }
    
    var body: some View {
        VStack {
            Text("Start the attack with the button below.")
                .font(.headline)
                .padding(.bottom)
            
            Text("The app will use the Device Discovery Extension (DDE) to attack the router and extract user data. The DDE is a feature that allows app developers to scan for media receivers in the local network without requesting user permission. We use it to scan for Airplay devices and to attack a local router")
            
            DevicePickerView()
                .frame(width: 65, height: 65)
            
            Text("Extracted Data:")
                .font(.headline)
            ScrollView {
                VStack {
                    ForEach(self.discoveredDevices, id:\.self) { deviceText in
                        Text(deviceText)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            
            Text("Router Attack Results:")
                .font(.headline)
            ScrollView {
                VStack {
                    ForEach(self.attackStateUpdates, id:\.self) { updateText in
                        Text(updateText)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            
        }
        .padding()
        .onAppear() {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo)
                try self.socket.setupSocket()
            }catch {
                os_log(.error, "Failed to staert the session")
            }
            
        }
    }
}
