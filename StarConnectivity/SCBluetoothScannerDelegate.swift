//
//  SCBluetoothScannerDelegate.swift
//  StarConnectivity
//
//  Created by Mathieu Vignau on 9/28/16.
//  Copyright © 2016 RED. All rights reserved.
//

import Foundation

public protocol SCBluetoothScannerDelegate: class {
    func scanner(_ scanner: SCBluetoothScanner, didFindCentral central: SCPeer)
    func scanner(_ scanner: SCBluetoothScanner, didLooseCentral central: SCPeer)
    func bluetoothStateUpdated(state:SCBluetoothState)
}

public extension SCBluetoothScannerDelegate {
    public func scanner(_ scanner: SCBluetoothScanner, didFindCentral central: SCPeer) {}
    public func scanner(_ scanner: SCBluetoothScanner, didLooseCentral central: SCPeer) {}
    public func bluetoothStateUpdated(state:SCBluetoothState) {}
}
