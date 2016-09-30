//
//  SCBluetoothAdvertiserDelegate.swift
//  StarConnectivity
//
//  Created by Mathieu Vignau on 9/29/16.
//  Copyright © 2016 RED. All rights reserved.
//

import Foundation

public protocol SCBluetoothAdvertiserDelegate: class {
    func bluetoothStateUpdated(state:SCBluetoothState)
}

public extension SCBluetoothAdvertiserDelegate {
    func bluetoothStateUpdated(state:SCBluetoothState) {}
}
