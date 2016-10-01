//
//  SCBluetoothPeripheral.swift
//  StarConnectivity
//
//  Created by Mathieu Vignau on 9/10/16.
//  Copyright © 2016 RED. All rights reserved.
//

import Foundation
import CoreBluetooth

public class SCBluetoothPeripheral : NSObject {
    
    public weak var delegate:SCBluetoothPeripheralDelegate?
    public let centralPeer:SCPeer
    public let peer:SCPeer
    
    private(set) public var connected = false
    private var cancelingConnection = false
    private var disconnectionInitiated = false
    
    private let serviceUUID:CBUUID
    private let advData:[String:AnyObject]
    private let cbPeripheralManager:CBPeripheralManager
    private var cbPeripheralManagerDelegate:PeripheralManagerDelegate!
    private var txchar:CBMutableCharacteristic?
    private var rxchar:CBMutableCharacteristic?
    private var infochar:CBMutableCharacteristic?
    
    private var advertisingRequested = false
    private var servicesInitialised = false
    
    private let transmission = SCDataTransmission()
    private var isWriting = false
    private var lastPacketDidNotTransmit = false
    
    public init(peripheralPeer peer:SCPeer, toCentralPeer centralPeer:SCPeer) {
        self.centralPeer = centralPeer
        self.peer = peer
        
        serviceUUID = CBUUID(NSUUID: centralPeer.identifier)
        
        advData = [CBAdvertisementDataServiceUUIDsKey : [serviceUUID]]
        cbPeripheralManager = CBPeripheralManager(delegate: nil, queue: dispatch_queue_create("starConnectivity_bluetoothPeripheralQueue", DISPATCH_QUEUE_CONCURRENT))
        
        super.init()
        cbPeripheralManagerDelegate = PeripheralManagerDelegate(outer: self)
        cbPeripheralManager.delegate = cbPeripheralManagerDelegate
        
        startAdvertising()
    }
    
    private func initService() {
        let service = CBMutableService(type: serviceUUID, primary: true)
        infochar = CBMutableCharacteristic(type: SCCommon.DISCOVERYINFO_CHARACTERISTIC_UUID, properties: CBCharacteristicProperties.Read, value: peer.discoveryData, permissions: CBAttributePermissions.Readable)
        txchar = CBMutableCharacteristic(type: SCCommon.TX_CHARACTERISTIC_UUID, properties: CBCharacteristicProperties.Notify, value: nil, permissions: CBAttributePermissions.Readable)
        rxchar = CBMutableCharacteristic(type: SCCommon.RX_CHARACTERISTIC_UUID, properties: [CBCharacteristicProperties.Write, CBCharacteristicProperties.WriteWithoutResponse], value: nil, permissions: CBAttributePermissions.Writeable)
        service.characteristics = [infochar!, txchar!, rxchar!]
        cbPeripheralManager.addService(service)
    }
    
    public func sendData(data:NSData, onPriorityQueue priorityQueue:UInt8, flushQueue:Bool=false, callback:(Bool -> Void)?=nil) {
        sendData(data, onPriorityQueue: priorityQueue, flushQueue: flushQueue, internalData: false, callback: callback)
    }
    
    public func disconnect() {
        if disconnectionInitiated {
            return
        }
        
        disconnectionInitiated = true
        if connected {
            sendData(SCCommon.INTERNAL_PERIPHERAL_DISCONNECTION_REQUEST_DATA, onPriorityQueue: SCCommon.INTERNAL_CONNECTION_QUEUE, flushQueue: false, internalData: true)
        } else {
            cancelingConnection = true
            stopAdvertising()
            cbPeripheralManager.removeAllServices()
        }
    }
    
    deinit {
        disconnect()
    }
    
    private func startAdvertising() {
        advertisingRequested = true
        
        if cbPeripheralManager.state == .PoweredOn {
            if !servicesInitialised {
                initService()
                servicesInitialised = true
            }
            cbPeripheralManager.startAdvertising(advData)
            print("Now advertising on channel \(serviceUUID) with info \(peer.discoveryData)")
        }
    }
    
    private func stopAdvertising() {
        advertisingRequested = false
        cbPeripheralManager.stopAdvertising()
    }
    
    private func transmitted() {
        print("Data transmitted")
    }
    
    private func sendData(data:NSData, onPriorityQueue priorityQueue:UInt8, flushQueue:Bool, internalData:Bool, callback:(Bool -> Void)?=nil) {
        transmission.addToQueue(data, onPriorityQueue: priorityQueue, flushQueue: flushQueue, internalData: internalData, callback: callback)
        flushData()
    }
    
    private func flushData() {
        if isWriting {
            return
        }
        
        isWriting = true
        while let packet = transmission.getNextPacket(lastPacketDidNotTransmit) {
            lastPacketDidNotTransmit = !cbPeripheralManager.updateValue(packet, forCharacteristic: txchar!, onSubscribedCentrals: nil)
            if lastPacketDidNotTransmit {
                return
            }
        }
        isWriting = false
    }
    
    private func onReceptionData(data:NSData, queue:UInt8) {
        delegate?.peripheral(self, didReceivedData: data, onPriorityQueue: queue, fromCentral: peer)
    }
    
    private func onReceptionInternalData(data:NSData, queue:UInt8) {
        if queue == SCCommon.INTERNAL_CONNECTION_QUEUE && data.isEqualToData(SCCommon.INTERNAL_CENTRAL_DISCONNECTION_DATA) {
            disconnect()
        }
    }
    
    private func onSubscribed() {
        stopAdvertising()
        
        if cancelingConnection {
            sendData(SCCommon.INTERNAL_PERIPHERAL_DISCONNECTION_REQUEST_DATA, onPriorityQueue: SCCommon.INTERNAL_CONNECTION_QUEUE, flushQueue: false, internalData: true)
            return
        }
        
        connected = true
        delegate?.peripheral(self, didConnectCentral: centralPeer)
    }
    
    private func onUnsubscribed() {
        connected = false
        var error:NSError?
        if !disconnectionInitiated {
            error = NSError(domain: "UnexpectedDisconnection", code: -1, userInfo: [NSLocalizedDescriptionKey:"Unexpected disconnection from Central"])
        }
        delegate?.peripheral(self, didDisconnectCentral: centralPeer, withError: error)
        
        cbPeripheralManager.removeAllServices()
        servicesInitialised = false
        
        cbPeripheralManager.delegate = nil
    }
    
    private class PeripheralManagerDelegate: NSObject, CBPeripheralManagerDelegate {
        
        private weak var outer: SCBluetoothPeripheral!
        private var oldPeripheralState:Int?
        
        private let reception = SCDataReception()
        
        init(outer: SCBluetoothPeripheral) {
            self.outer = outer
            super.init()
            reception.onData = outer.onReceptionData
            reception.onInternalData = outer.onReceptionInternalData
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
        
        @objc private func peripheralManager(peripheral: CBPeripheralManager, didReceiveWriteRequests requests: [CBATTRequest]) {
            
            for req in requests {
                if let data = req.value {
                    peripheral.respondToRequest(req, withResult: CBATTError.Success)
                    
                    reception.parsePacket(data)
                }
            }
        }
        
        @objc private func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didSubscribeToCharacteristic characteristic: CBCharacteristic) {
            outer.onSubscribed()
        }
        
        @objc private func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic) {
            outer.onUnsubscribed()
        }
        
        @objc private func peripheralManagerIsReadyToUpdateSubscribers(peripheral: CBPeripheralManager) {
            outer.isWriting = false
            outer.flushData()
        }
    }
}
