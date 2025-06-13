//
//  ContentView.swift
//  PoCLanShieldWatch Watch App
//
//  Created by Alex - SEEMOO on 19.12.24.
//

import SwiftUI
import WatchConnectivity
import os

struct ContentView: View {
    
    @ObservedObject var attackController = AttackController.shared
    
    @State var exploitLog = ""
    
    var body: some View {
        VStack {
            if attackController.appState == .waiting {
                Text("Waiting for command from main app...")
            }else if attackController.appState == .runningRouter {
                Text("Attacking the router!")
                ScrollView {
                    Text(attackController.routerAttack?.log ?? "")
                        .multilineTextAlignment(.leading)
                        .monospaced()
                }
                
            }else if attackController.appState == .done {
                Text("Done!")
                    .font(.title3)
                ScrollView {
                    Text(attackController.log)
                        .multilineTextAlignment(.leading)
                        .monospaced()
                }
            }else if attackController.appState == .runningDiscovery {
                Text("Running Service discovery to extract user data")
                ScrollView {
                    Text(attackController.bonjourAttack?.log ?? "")
                }
            }
        }
        .padding()
        .onAppear {
            WatchController.shared.activate()
        }
    }
}

#Preview {
    ContentView()
}

