//
//  SCBluetoothScannerDelegate.swift
//  StarConnectivity
//
//  Created by Mathieu Vignau on 9/28/16.
//  Copyright © 2016 RED. All rights reserved.
//

import Foundation

public protocol SCBluetoothScannerDelegate: class {
    func scanner(scanner: SCBluetoothScanner, didFindCentral central: SCPeer)
    func scanner(scanner: SCBluetoothScanner, didLooseCentral central: SCPeer)
    func bluetoothStateUpdated(state:SCBluetoothState)
}

public extension SCBluetoothScannerDelegate {
    func scanner(scanner: SCBluetoothScanner, didFindCentral central: SCPeer) {}
    func scanner(scanner: SCBluetoothScanner, didLooseCentral central: SCPeer) {}
    func bluetoothStateUpdated(state:SCBluetoothState) {}
}
