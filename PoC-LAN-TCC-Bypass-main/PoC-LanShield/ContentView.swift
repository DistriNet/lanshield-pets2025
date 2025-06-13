//
//  ContentView.swift
//  PoC-LanShield
//
//  Created by Alex - SEEMOO on 19.12.24.
//

import SwiftUI

struct ContentView: View {
    
    @State var runningExploit: Exploit?
    @State var startExpoit: Bool = false
    
    var body: some View {
        VStack {
            Text("PoC")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("As the LAN contains devices with sensitive data, iOS requires a permission for apps to access the LAN. We demonstrate several exploits that can be used to bypass this permission.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .padding()
            
            Spacer()
            
            ForEach(ExploitController.shared.exploits) { exploit in
                PoCButton(exploit: exploit) {
                    self.runningExploit = exploit
                    self.startExpoit = true
                }
            }
            
            Spacer()
            
        }
        .padding()
        .sheet(item: $runningExploit, content: { exploit in
            if exploit.name == "WebView" {
                WebViewPoC()
            }else if exploit.name == "watchOS Bypass" {
                AppleWatchPoCView()
            }else if exploit.name == "Device Discovery Extension" {
                DDEView()
            }else if exploit.name == "Safari Extension" {
                
            }else if exploit.name == "Mis-definition of LAN" {
                MisdefinitionExploitView()
            }
        })
    }
}

struct PoCButton: View {
    var exploit: Exploit
    var action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 7.5)
                    .stroke()
                    .foregroundStyle( Color(white: 0.2))
                HStack {
                    
                    Image(systemName: exploit.icon)
                        .foregroundStyle(Color.orange)
                    
                    Text(exploit.name)
                    
                    Spacer ()
                    
                    Image(systemName: "chevron.right")
                }
                .padding(.horizontal)
            }
        }
        .frame(height: 50)
    }
    
   
}



#Preview {
    ContentView()
}
