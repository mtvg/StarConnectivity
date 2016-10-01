//
//  SCBluetoothPeripheralDelegate.swift
//  StarConnectivity
//
//  Created by Mathieu Vignau on 9/10/16.
//  Copyright © 2016 RED. All rights reserved.
//

import Foundation

public protocol SCBluetoothPeripheralDelegate: class {
    func peripheral(peripheral: SCBluetoothPeripheral, didConnectCentral central: SCPeer)
    func peripheral(peripheral: SCBluetoothPeripheral, didDisconnectCentral central: SCPeer, withError error:NSError?)
    func peripheral(peripheral: SCBluetoothPeripheral, didReceivedData data: NSData, onPriorityQueue priorityQueue:UInt8, fromCentral central:SCPeer)
    func bluetoothStateUpdated(state:SCBluetoothState)
}

public extension SCBluetoothPeripheralDelegate {
    public func peripheral(peripheral: SCBluetoothPeripheral, didConnectCentral central: SCPeer) {}
    public func peripheral(peripheral: SCBluetoothPeripheral, didDisconnectCentral central: SCPeer, withError error:NSError?) {}
    public func peripheral(peripheral: SCBluetoothPeripheral, didReceivedData data: NSData, onPriorityQueue priorityQueue:UInt8, fromCentral central:SCPeer) {}
    public func bluetoothStateUpdated(state:SCBluetoothState) {}
}
