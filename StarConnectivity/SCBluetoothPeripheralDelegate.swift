//
//  SCBluetoothPeripheralDelegate.swift
//  StarConnectivity
//
//  Created by Mathieu Vignau on 9/10/16.
//  Copyright © 2016 RED. All rights reserved.
//

import Foundation

public protocol SCBluetoothPeripheralDelegate: class {
    func peripheral(_ peripheral: SCBluetoothPeripheral, didConnect central: SCPeer)
    func peripheral(_ peripheral: SCBluetoothPeripheral, didDisconnect central: SCPeer, withError error:Error?)
    func peripheral(_ peripheral: SCBluetoothPeripheral, didReceive data: Data, on priorityQueue:SCPriorityQueue, from central:SCPeer)
    func peripheral(_ peripheral: SCBluetoothPeripheral, didUpdateBluetoothState state:SCBluetoothState)
}

public extension SCBluetoothPeripheralDelegate {
    func peripheral(_ peripheral: SCBluetoothPeripheral, didConnect central: SCPeer) {}
    func peripheral(_ peripheral: SCBluetoothPeripheral, didDisconnect central: SCPeer, withError error:Error?) {}
    func peripheral(_ peripheral: SCBluetoothPeripheral, didReceive data: Data, on priorityQueue:SCPriorityQueue, from central:SCPeer) {}
    func peripheral(_ peripheral: SCBluetoothPeripheral, didUpdateBluetoothState state:SCBluetoothState) {}
}
