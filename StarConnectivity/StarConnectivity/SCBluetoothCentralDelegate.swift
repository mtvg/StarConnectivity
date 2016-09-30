//
//  SCBluetoothCentralDelegate.swift
//  StarConnectivity
//
//  Created by Mathieu Vignau on 7/5/16.
//  Copyright © 2016 RED. All rights reserved.
//

import Foundation

public protocol SCBluetoothCentralDelegate: class {
    func central(central: SCBluetoothCentral, didConnectPeripheral peripheral: SCPeer)
    func central(central: SCBluetoothCentral, didDisconnectPeripheral peripheral: SCPeer)
    func central(central: SCBluetoothCentral, didReceivedData data: NSData, onPriorityQueue priorityQueue:UInt8, fromPeripheral peripheral:SCPeer)
    func bluetoothStateUpdated(state:SCBluetoothState)
}

public extension SCBluetoothCentralDelegate {
    func central(central: SCBluetoothCentral, didConnectPeripheral peripheral: SCPeer) {}
    func central(central: SCBluetoothCentral, didDisconnectPeripheral peripheral: SCPeer) {}
    func central(central: SCBluetoothCentral, didReceivedData data: NSData, onPriorityQueue priorityQueue:UInt8, fromPeripheral peripheral:SCPeer) {}
    func bluetoothStateUpdated(state:SCBluetoothState) {}
}
