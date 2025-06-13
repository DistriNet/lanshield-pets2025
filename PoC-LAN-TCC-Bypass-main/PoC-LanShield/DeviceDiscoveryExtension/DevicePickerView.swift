/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Utilities for the device-picker UI view.
*/

import SwiftUI
import AVRouting
import AVKit
import os

struct DevicePickerView: UIViewRepresentable {

    func makeUIView(context: Context) -> UIView {

        let routePickerView = AVRoutePickerView()

        routePickerView.delegate = context.coordinator
        
        routePickerView.customRoutingController = RouteManager.shared.routingController
        
        routePickerView.backgroundColor = UIColor.white
        routePickerView.activeTintColor = UIColor.red
        routePickerView.tintColor = UIColor.systemBlue
        routePickerView.prioritizesVideoDevices = true

        return routePickerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, AVRoutePickerViewDelegate {
        
        func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) {
            var rows = [AVCustomRoutingActionItem]()
            if let type = UTType("de.tu-darmstadt.example-protocol") {
                let customRow1 = AVCustomRoutingActionItem()
                customRow1.type = type
                rows.append(customRow1)
            }else {
                os_log(.error, "Couldn't find UTType for de.tu-darmstadt.example-protocol")
            }
            
            RouteManager.shared.routingController.customActionItems = rows
            os_log(.debug, "Added custom action to routing controller")
        }
    }
}

class RouteManager: NSObject, AVCustomRoutingControllerDelegate {
    static let shared = RouteManager()
    
    var routingController = AVCustomRoutingController()
    
    override init() {
        super.init()
        routingController.delegate = self
    }
    
    func customRoutingController(_ controller: AVCustomRoutingController, eventDidTimeOut event: AVCustomRoutingEvent) {
        os_log("Event timed out \(event)")
    }
    
    func customRoutingController(_ controller: AVCustomRoutingController, didSelect customActionItem: AVCustomRoutingActionItem) {
        os_log("Did select route: \(customActionItem)")
    }
    
    
    func customRoutingController(_ controller: AVCustomRoutingController, handle event: AVCustomRoutingEvent) async -> Bool {
        os_log(.info, "Received custom routing event: \(event)")
        RouteManager.shared.routingController.setActive(true, for: event.route)
        return true
    }
    

}
