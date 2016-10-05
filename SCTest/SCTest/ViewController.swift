//
//  ViewController.swift
//  SCTest
//
//  Created by Mathieu Vignau on 10/5/16.
//  Copyright © 2016 RED. All rights reserved.
//

import UIKit

class ViewController: UIViewController, SCBluetoothPeripheralDelegate, SCBluetoothScannerDelegate {
    
    var peripheral:SCBluetoothPeripheral?
    var scanner:SCBluetoothScanner?
    
    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.isIdleTimerDisabled = true
        
        /*scanner = SCBluetoothScanner(serviceToBrowse: UUID(uuidString: "0799eb34-73a7-48c0-8839-615cdf1b495b")!)
         scanner?.centralScanTimeout = 10
         scanner?.delegate = self
         scanner?.startScanning()*/
    }
    
    func scanner(_ scanner: SCBluetoothScanner, didFind central: SCPeer) {
        print("Found central with info: \(central.discoveryInfo)")
    }
    
    func scanner(_ scanner: SCBluetoothScanner, didLoose central: SCPeer) {
        print("Lost central: \(central.discoveryData as NSData)")
    }
    
    func peripheral(_ peripheral: SCBluetoothPeripheral, didReceive data: Data, on priorityQueue: SCPriorityQueue, from central: SCPeer) {
        print("Received \(data.count) bytes on queue \(priorityQueue)")
    }
    
    func peripheral(_ peripheral: SCBluetoothPeripheral, didConnect central: SCPeer) {
        DispatchQueue.main.async {
            self.label.text = "Connected"
        }
        print("peripheral didConnectCentral")
    }
    
    func peripheral(_ peripheral: SCBluetoothPeripheral, didDisconnect central: SCPeer, withError error: Error?) {
        DispatchQueue.main.async {
            self.label.text = "Disconnected"
        }
        
        self.peripheral = nil
        self.peripheral?.delegate = nil
        
        
        if error != nil {
            print("peripheral didDisconnectCentral with Error")
            DispatchQueue.main.async {
                self.connectToCentral()
            }
        } else {
            print("peripheral didDisconnectCentral")
        }
    }
    
    func connectToCentral() {
        if peripheral != nil {
            return
        }
        peripheral = SCBluetoothPeripheral(peripheralPeer: SCPeer(), toCentralPeer: SCPeer(withUUID: UUID(uuidString: "0799eb34-73a7-48c0-8839-615cdf1b495b")!))
        peripheral?.delegate = self
        self.label.text = "Connecting..."
    }
    
    @IBAction func onSend(_ sender: AnyObject) {
        let bytes = [UInt8](repeating:UInt8(arc4random_uniform(256)), count:500)
        let data = Data(bytes)
        let queue = arc4random_uniform(0x10)
        print("Sending \(data.count) bytes on queue \(queue)")
        peripheral?.send(data: data, on: SCPriorityQueue(queue))
    }
    
    @IBAction func onConnect(_ sender: AnyObject) {
        connectToCentral()
    }
    
    @IBAction func onDisconnect(_ sender: AnyObject) {
        peripheral?.disconnect()
    }
}
