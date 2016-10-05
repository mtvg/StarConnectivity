//
//  main.swift
//  sctestcentral
//
//  Created by Mathieu Vignau on 10/5/16.
//  Copyright © 2016 RED. All rights reserved.
//

import Foundation

let stdin = FileHandle.standardInput


let service = UUID(uuidString: "0799eb34-73a7-48c0-8839-615cdf1b495b")
let myPeer = SCPeer(withUUID: service!)
//let myPeer = SCPeer(withDiscoveryInfo: ["host":"matthieuv-macpro"])!

class MyCentralDelegate : SCBluetoothCentralDelegate {
    func central(_ central: SCBluetoothCentral, didConnect peripheral: SCPeer) {
        print("Connected to peripheral with info \(peripheral.discoveryData)")
    }
    func central(_ central: SCBluetoothCentral, didDisconnect peripheral: SCPeer) {
        print("Disconnected from peripheral")
    }
    func central(_ central: SCBluetoothCentral, didReceive data: Data, on priorityQueue: SCPriorityQueue, from peripheral: SCPeer) {
        print("Received and sending back \(data.count) bytes on queue \(priorityQueue)")
        central.send(data: data, on: priorityQueue)
    }
}

//let adv = SCBluetoothAdvertiser(centralPeer:myPeer, serviceUUID: service!)
//adv.startAdvertising()

let central = SCBluetoothCentral(centralPeer: myPeer)
let del = MyCentralDelegate()
central.delegate = del


stdinLoop: while true {
    
    if stdin.availableData.count > 0 {
        central.disconnect()
    }
}
