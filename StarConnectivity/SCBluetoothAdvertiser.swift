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
    public var delegateQueue = DispatchQueue.main
    
    public let serviceUUID:CBUUID
    public let peer:SCPeer
    
    private var advData:[String:Any]!
    private let cbPeripheralManager:CBPeripheralManager
    private var cbPeripheralManagerDelegate:PeripheralManagerDelegate!
    
    private var advertisingRequested = false
    private var serviceInitiated = false
    
    public init(centralPeer peer:SCPeer, serviceUUID uuid: SCUUID) {
        self.serviceUUID = uuid
        self.peer = peer
        
        cbPeripheralManager = CBPeripheralManager(delegate: nil, queue: DispatchQueue(label: "starConnectivity_bluetoothAdvertiserQueue"), options: [CBPeripheralManagerOptionShowPowerAlertKey:true])
        
        super.init()
        generateUniqueBluetoothAdvertisingData()
        cbPeripheralManagerDelegate = PeripheralManagerDelegate(outer: self)
        cbPeripheralManager.delegate = cbPeripheralManagerDelegate
    }
    
    private func generateUniqueBluetoothAdvertisingData() {
        // generating unique name for this advertising session, so Browser can distinguish multiple sessions from same device
        
        let time = Int(Date().timeIntervalSince(NSCalendar.current.startOfDay(for: Date()))*9)
        
        advData = [CBAdvertisementDataServiceUUIDsKey : [serviceUUID], CBAdvertisementDataLocalNameKey : "SC#"+time.toBase95()]
    }
    
    public func startAdvertising() {
        advertisingRequested = true
        
        if cbPeripheralManager.state == .poweredOn {
            if !serviceInitiated {
                initService()
                serviceInitiated = true
            }
            generateUniqueBluetoothAdvertisingData()
            cbPeripheralManager.startAdvertising(advData)
        }
    }
    
    public func stopAdvertising() {
        advertisingRequested = false
        cbPeripheralManager.stopAdvertising()
    }
    
    private func initService() {
        let infochar = CBMutableCharacteristic(type: SCCommon.DISCOVERYINFO_CHARACTERISTIC_UUID, properties: CBCharacteristicProperties.read, value: nil, permissions: CBAttributePermissions.readable)
        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [infochar]
        cbPeripheralManager.add(service)
    }
    
    private class PeripheralManagerDelegate: NSObject, CBPeripheralManagerDelegate {
        
        private weak var outer: SCBluetoothAdvertiser!
        private var oldPeripheralState:Int?
        
        init(outer: SCBluetoothAdvertiser) {
            self.outer = outer
            super.init()
        }
        
        func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
            outer.delegateQueue.async {
                self.outer.delegate?.advertiser(self.outer, didUpdateBluetoothState: SCBluetoothState(rawValue: peripheral.state.rawValue)!)
            }
            
            if oldPeripheralState == peripheral.state.rawValue {
                return
            }
            oldPeripheralState = peripheral.state.rawValue
            
            if peripheral.state == .poweredOn && outer.advertisingRequested {
                outer.startAdvertising()
            }
        }
        
        func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
            if outer.advertisingRequested {
                request.value = outer.peer.discoveryData.subdata(in: request.offset..<outer.peer.discoveryData.count)
                peripheral.respond(to: request, withResult: .success)
            } else {
                peripheral.respond(to: request, withResult: .attributeNotFound)
            }
        }
    }

}
