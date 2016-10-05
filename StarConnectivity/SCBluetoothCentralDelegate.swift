//
//  SCBluetoothCentralDelegate.swift
//  StarConnectivity
//
//  Created by Mathieu Vignau on 7/5/16.
//  Copyright © 2016 RED. All rights reserved.
//

import Foundation

public protocol SCBluetoothCentralDelegate: class {
    func central(_ central: SCBluetoothCentral, didConnect peripheral: SCPeer)
    func central(_ central: SCBluetoothCentral, didDisconnect peripheral: SCPeer)
    func central(_ central: SCBluetoothCentral, didReceive data: Data, on priorityQueue:SCPriorityQueue, from peripheral:SCPeer)
    func central(_ central: SCBluetoothCentral, didUpdateBluetoothState state:SCBluetoothState)
}

public extension SCBluetoothCentralDelegate {
    func central(_ central: SCBluetoothCentral, didConnect peripheral: SCPeer) {}
    func central(_ central: SCBluetoothCentral, didDisconnect peripheral: SCPeer) {}
    func central(_ central: SCBluetoothCentral, didReceive data: Data, on priorityQueue:SCPriorityQueue, from peripheral:SCPeer) {}
    func central(_ central: SCBluetoothCentral, didUpdateBluetoothState state:SCBluetoothState){}
}
