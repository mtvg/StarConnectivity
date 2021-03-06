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
    public var delegateQueue = DispatchQueue.main
    public let centralPeer:SCPeer
    public let peer:SCPeer
    
    private(set) public var isConnected = false
    private var cancelingConnection = false
    private var disconnectionInitiated = false
    
    private let serviceUUID:CBUUID
    private let advData:[String:Any]
    private let cbPeripheralManager:CBPeripheralManager
    private var cbPeripheralManagerDelegate:PeripheralManagerDelegate!
    private var txchar:CBMutableCharacteristic?
    private var rxchar:CBMutableCharacteristic?
    private var infochar:CBMutableCharacteristic?
    
    private var advertisingRequested = false
    private var advertisingTimer:Timer?
    
    private let transmission = SCDataTransmission()
    private var isWriting = false
    private var lastPacketDidNotTransmit = false
    
    public init(peripheralPeer peer:SCPeer, toCentralPeer centralPeer:SCPeer) {
        self.centralPeer = centralPeer
        self.peer = peer
        
        serviceUUID = CBUUID(nsuuid: centralPeer.identifier)
        
        advData = [CBAdvertisementDataServiceUUIDsKey : [serviceUUID]]
        cbPeripheralManager = CBPeripheralManager(delegate: nil, queue: DispatchQueue(label: "starConnectivity_bluetoothPeripheralQueue"), options: [CBPeripheralManagerOptionShowPowerAlertKey:true])
        
        super.init()
        cbPeripheralManagerDelegate = PeripheralManagerDelegate(outer: self)
        cbPeripheralManager.delegate = cbPeripheralManagerDelegate
        
        startAdvertising()
    }
    
    private func initService() {
        let service = CBMutableService(type: serviceUUID, primary: true)
        infochar = CBMutableCharacteristic(type: SCCommon.DISCOVERYINFO_CHARACTERISTIC_UUID, properties: CBCharacteristicProperties.read, value: peer.discoveryData, permissions: CBAttributePermissions.readable)
        txchar = CBMutableCharacteristic(type: SCCommon.TX_CHARACTERISTIC_UUID, properties: CBCharacteristicProperties.notify, value: nil, permissions: CBAttributePermissions.readable)
        rxchar = CBMutableCharacteristic(type: SCCommon.RX_CHARACTERISTIC_UUID, properties: [CBCharacteristicProperties.write, CBCharacteristicProperties.writeWithoutResponse], value: nil, permissions: CBAttributePermissions.writeable)
        service.characteristics = [infochar!, txchar!, rxchar!]
        
        cbPeripheralManager.removeAllServices()
        cbPeripheralManager.add(service)
    }
    
    public func send(data:Data, on priorityQueue:SCPriorityQueue, flushQueue:Bool=false, callback:((Bool) -> Void)?=nil) {
        send(data: data, on: priorityQueue, flushQueue: flushQueue, internalData: false, callback: callback)
    }
    
    public func disconnect() {
        if disconnectionInitiated {
            return
        }
        
        disconnectionInitiated = true
        if isConnected {
            send(data: SCCommon.INTERNAL_PERIPHERAL_DISCONNECTION_REQUEST_DATA, on: SCCommon.INTERNAL_CONNECTION_QUEUE, flushQueue: false, internalData: true)
        } else {
            cancelingConnection = true
            stopAdvertising()
            cbPeripheralManager.removeAllServices()
        }
    }
    
    deinit {
        disconnect()
    }
    
    @objc private func startAdvertising() {
        advertisingRequested = true
        
        if cbPeripheralManager.state == .poweredOn {
            initService()
            cbPeripheralManager.startAdvertising(advData)
            advertisingTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(startAdvertising), userInfo: nil, repeats: false)
        }
    }
    
    private func stopAdvertising() {
        advertisingRequested = false
        cbPeripheralManager.stopAdvertising()
        advertisingTimer?.invalidate()
    }
    
    private func send(data:Data, on priorityQueue:SCPriorityQueue, flushQueue:Bool, internalData:Bool, callback:((Bool) -> Void)?=nil) {
        transmission.add(data: data, to: priorityQueue, flushQueue: flushQueue, internalData: internalData, callback: callback)
        flushData()
    }
    
    private func flushData() {
        if isWriting {
            return
        }
        
        isWriting = true
        while let packet = transmission.getNextPacket(repeatLastPacket: lastPacketDidNotTransmit) {
            lastPacketDidNotTransmit = !cbPeripheralManager.updateValue(packet, for: txchar!, onSubscribedCentrals: nil)
            if lastPacketDidNotTransmit {
                return
            }
        }
        isWriting = false
    }
    
    private func onReceptionData(data:Data, queue:SCPriorityQueue) {
        delegateQueue.async {
            self.delegate?.peripheral(self, didReceive: data, on: queue, from: self.peer)
        }
    }
    
    private func onReceptionInternalData(data:Data, queue:SCPriorityQueue) {
        if queue == SCCommon.INTERNAL_CONNECTION_QUEUE && data == SCCommon.INTERNAL_CENTRAL_DISCONNECTION_DATA {
            disconnect()
        }
    }
    
    private func onSubscribed() {
        stopAdvertising()
        
        if cancelingConnection {
            send(data: SCCommon.INTERNAL_PERIPHERAL_DISCONNECTION_REQUEST_DATA, on: SCCommon.INTERNAL_CONNECTION_QUEUE, flushQueue: false, internalData: true)
            return
        }
        
        isConnected = true
        delegateQueue.async {
            self.delegate?.peripheral(self, didConnect: self.centralPeer)
        }
    }
    
    private func onUnsubscribed() {
        isConnected = false
        var error:NSError?
        if !disconnectionInitiated {
            error = NSError(domain: "UnexpectedDisconnection", code: -1, userInfo: [NSLocalizedDescriptionKey:"Unexpected disconnection from Central"])
        }
        delegateQueue.async {
            self.delegate?.peripheral(self, didDisconnect: self.centralPeer, withError: error)
        }
        
        cbPeripheralManager.removeAllServices()
        
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
        
        func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
            outer.delegateQueue.async {
                self.outer.delegate?.peripheral(self.outer, didUpdateBluetoothState: SCBluetoothState(rawValue: peripheral.state.rawValue)!)
            }
            
            if oldPeripheralState == peripheral.state.rawValue {
                return
            }
            oldPeripheralState = peripheral.state.rawValue
            
            if peripheral.state == .poweredOn && outer.advertisingRequested {
                outer.startAdvertising()
            }
            
        }
        
        func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
            for req in requests {
                if let data = req.value {
                    peripheral.respond(to: req, withResult: CBATTError.success)
                    
                    reception.parse(packet: data)
                }
            }
        }
        
        func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
            outer.onSubscribed()
        }
        
        func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
            outer.onUnsubscribed()
        }
        
        func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
            outer.isWriting = false
            outer.flushData()
        }
    }
}
