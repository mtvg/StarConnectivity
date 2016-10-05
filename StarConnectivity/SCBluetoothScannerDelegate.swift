//
//  SCBluetoothScannerDelegate.swift
//  StarConnectivity
//
//  Created by Mathieu Vignau on 9/28/16.
//  Copyright © 2016 RED. All rights reserved.
//

import Foundation

public protocol SCBluetoothScannerDelegate: class {
    func scanner(_ scanner: SCBluetoothScanner, didFind central: SCPeer)
    func scanner(_ scanner: SCBluetoothScanner, didLoose central: SCPeer)
    func scanner(_ scanner: SCBluetoothScanner, didUpdateBluetoothState state:SCBluetoothState)
}

public extension SCBluetoothScannerDelegate {
    func scanner(_ scanner: SCBluetoothScanner, didFind central: SCPeer) {}
    func scanner(_ scanner: SCBluetoothScanner, didLoose central: SCPeer) {}
    func scanner(_ scanner: SCBluetoothScanner, didUpdateBluetoothState state:SCBluetoothState) {}
}
