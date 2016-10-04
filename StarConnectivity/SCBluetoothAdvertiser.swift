//
//  SCBluetoothAdvertiser.swift
//  StarConnectivity
//
//  Created by Mathieu Vignau on 6/30/16.
//  Copyright © 2016 RED. All rights reserved.
//

import Foundation
import CoreBluetooth

public class SCBluetoothAdvertiser : NSObject {
    
    public weak var delegate:SCBluetoothAdvertiserDelegate?
    
    public let serviceUUID:SCUUID
    public let peer:SCPeer
    
    private let advData:[String:AnyObject]
    private let cbPeripheralManager:CBPeripheralManager
    private var cbPeripheralManagerDelegate:PeripheralManagerDelegate!
    
    private var advertisingRequested = false
    private var servicesInitialised = false
    
    public init(centralPeer peer:SCPeer, serviceUUID uuid: SCUUID) {
        self.serviceUUID = uuid
        self.peer = peer
        
        // generating unique name for this advertising session, so Browser can distinguish multiple sessions from same device
        var time = NSDate().timeIntervalSince1970
        let timedata = String(NSData(bytes: &time, length: sizeof(NSTimeInterval)).base64EncodedStringWithOptions([]).characters.dropLast())
        
        advData = [CBAdvertisementDataLocalNameKey : "SC#"+timedata, CBAdvertisementDataServiceUUIDsKey : [serviceUUID]]
        cbPeripheralManager = CBPeripheralManager(delegate: nil, queue: dispatch_queue_create("starConnectivity_bluetoothAdvertiserQueue", DISPATCH_QUEUE_CONCURRENT))
        
        super.init()
        cbPeripheralManagerDelegate = PeripheralManagerDelegate(outer: self)
        cbPeripheralManager.delegate = cbPeripheralManagerDelegate
    }
    
    public func startAdvertising() {
        advertisingRequested = true
        
        if cbPeripheralManager.state == .PoweredOn {
            if !servicesInitialised {
                initService()
                servicesInitialised = true
            }
            cbPeripheralManager.startAdvertising(advData)
        }
    }
    
    public func stopAdvertising() {
        advertisingRequested = false
        cbPeripheralManager.stopAdvertising()
    }
    
    private func initService() {
        let service = CBMutableService(type: serviceUUID, primary: true)
        let infochar = CBMutableCharacteristic(type: SCCommon.DISCOVERYINFO_CHARACTERISTIC_UUID, properties: CBCharacteristicProperties.Read, value: peer.discoveryData, permissions: CBAttributePermissions.Readable)
        service.characteristics = [infochar]
        cbPeripheralManager.addService(service)
    }
    
    private class PeripheralManagerDelegate: NSObject, CBPeripheralManagerDelegate {
        
        private weak var outer: SCBluetoothAdvertiser!
        private var oldPeripheralState:Int?
        
        init(outer: SCBluetoothAdvertiser) {
            self.outer = outer
            super.init()
        }
        
        @objc func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager) {
            
            outer.delegate?.bluetoothStateUpdated(SCBluetoothState(rawValue: peripheral.state.rawValue)!)
            
            if oldPeripheralState == peripheral.state.rawValue {
                return
            }
            oldPeripheralState = peripheral.state.rawValue
            
            if peripheral.state == .PoweredOn && outer.advertisingRequested {
                outer.startAdvertising()
            }
        }
    }

}