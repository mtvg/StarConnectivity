//
//  SCBluetoothCentral.swift
//  StarConnectivity
//
//  Created by Mathieu Vignau on 7/2/16.
//  Copyright © 2016 RED. All rights reserved.
//

import Foundation
import CoreBluetooth

public class SCBluetoothCentral :NSObject {
    
    public weak var delegate:SCBluetoothCentralDelegate?
    public var delegateQueue = DispatchQueue.main
    public let centralPeer:SCPeer
    
    private let cbCentralManager:CBCentralManager
    private var cbCentralManagerDelegate:CentralManagerDelegate!
    private let scannedPeripheralService:CBUUID
    
    private var connectedDevices = [Device]()
    
    public init(centralPeer peer:SCPeer) {
        
        cbCentralManager = CBCentralManager(delegate: nil, queue: DispatchQueue(label: "starConnectivity_bluetoothCentralQueue"), options: [CBPeripheralManagerOptionShowPowerAlertKey:true])
        centralPeer = peer
        scannedPeripheralService = CBUUID(nsuuid: peer.identifier)
        super.init()
        cbCentralManagerDelegate = CentralManagerDelegate(outer: self)
        cbCentralManager.delegate = cbCentralManagerDelegate
    }
    
    public func send(data:Data, on priorityQueue:SCPriorityQueue, to peers:[SCPeer]?=nil, flushQueue:Bool=false) {
        send(data: data, to: peers, on: priorityQueue, flushQueue: flushQueue, internalData: false)
    }
    
    public func disconnect(peers:[SCPeer]?=nil) {
        for device in connectedDevices {
            if device.peer != nil && (peers == nil || peers!.index(where: {$0 === device.peer!}) != nil) {
                device.disconnect()
            }
        }
    }
    
    private func send(data:Data, to peers:[SCPeer]?, on priorityQueue:SCPriorityQueue, flushQueue:Bool, internalData:Bool) {
        for device in connectedDevices {
            if device.peer != nil && (peers == nil || peers!.index(where: {$0 === device.peer!}) != nil) {
                device.send(data: data, on: priorityQueue, flushQueue: flushQueue, internalData: internalData)
            }
        }
    }
    
    private func remove(peripheral:CBPeripheral) {
        
        if let dIndex = connectedDevices.index(where: {$0.peripheral == peripheral}) {
            if let peer = connectedDevices[dIndex].peer {
                delegateQueue.async {
                    self.delegate?.central(self, didDisconnect: peer)
                }
            }
            connectedDevices[dIndex].peer = nil
            connectedDevices.remove(at: dIndex)
        }
        
    }
    

    private class Device: NSObject, CBPeripheralDelegate {
        let peripheral:CBPeripheral
        let rxchar:CBCharacteristic
        let txchar:CBCharacteristic
        let infochar:CBCharacteristic
        var peer:SCPeer?
        
        private let transmission = SCDataTransmission()
        private let reception = SCDataReception()
        private var isWriting = false
        
        private weak var outer: SCBluetoothCentral!
        
        init(outer:SCBluetoothCentral, peripheral:CBPeripheral, rxchar: CBCharacteristic, txchar: CBCharacteristic, infochar: CBCharacteristic) {
            self.outer = outer
            self.peripheral = peripheral
            self.rxchar = rxchar
            self.txchar = txchar
            self.infochar = infochar
            
            super.init()
            
            reception.onData = onReceptionData
            reception.onInternalData = onReceptionInternalData
        }
        
        
        func send(data:Data, on priorityQueue:SCPriorityQueue, flushQueue:Bool=false, internalData:Bool=false, callback:((Bool) -> Void)?=nil) {
            transmission.add(data: data, to: priorityQueue, flushQueue: flushQueue, internalData: internalData, callback: callback)
            flushData()
        }
        
        func onReceptionData(data:Data, queue:SCPriorityQueue) {
            if peer == nil {
                return
            }
            outer.delegateQueue.async {
                self.outer.delegate?.central(self.outer, didReceive: data, on: queue, from: self.peer!)
            }
        }
        
        func onReceptionInternalData(data:Data, queue:SCPriorityQueue) {
            if queue == SCCommon.INTERNAL_CONNECTION_QUEUE && data == SCCommon.INTERNAL_PERIPHERAL_DISCONNECTION_REQUEST_DATA {
                disconnect(soft: false)
            }
        }
        
        func flushData(repeatLastPacket:Bool=false) {
            if isWriting {
                return
            }
            
            
            if let packet = transmission.getNextPacket(repeatLastPacket: repeatLastPacket) {
                peripheral.writeValue(packet, for: rxchar, type: .withResponse)
                isWriting = true
            }
        }
        
        func disconnect(soft:Bool=true) {
            if soft {
                send(data: SCCommon.INTERNAL_CENTRAL_DISCONNECTION_DATA, on: SCCommon.INTERNAL_CONNECTION_QUEUE, flushQueue: false, internalData: true)
                // TODO: Hard disconnect on timeout
            } else {
                peripheral.setNotifyValue(false, for: txchar)
            }
            
        }
        
        func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
            isWriting = false
            flushData(repeatLastPacket: error != nil)
        }
        
        func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            if let charval = characteristic.value, characteristic == txchar && error == nil && charval.count > 1 {
                reception.parse(packet: charval)
            }
        }
        
        func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
            if characteristic == txchar {
                if error == nil {
                    outer.cbCentralManager.cancelPeripheralConnection(peripheral)
                } else {
                    outer.remove(peripheral: peripheral)
                }
            }
        }
        
    }
    
    private class CentralManagerDelegate: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
        
        private weak var outer: SCBluetoothCentral!
        private var oldPeripheralState:CBPeripheralManagerState?
        
        var discoveredPeripherals = [CBPeripheral]()
        
        init(outer: SCBluetoothCentral) {
            self.outer = outer
            super.init()
        }
        
        func centralManagerDidUpdateState(_ central: CBCentralManager) {
            if central.state == .poweredOn {
                central.scanForPeripherals(withServices: [outer.scannedPeripheralService], options: [CBCentralManagerScanOptionAllowDuplicatesKey:true])
            }
            outer.delegateQueue.async {
                self.outer.delegate?.central(self.outer, didUpdateBluetoothState: SCBluetoothState(rawValue: central.state.rawValue)!)
            }
        }
        
        func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
            if discoveredPeripherals.index(of: peripheral) != nil {
                return
            }
            peripheral.delegate = self
            discoveredPeripherals.append(peripheral)
            central.connect(peripheral, options: nil)
        }
        
        func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
            peripheral.discoverServices(nil)
        }
        
        func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
            if let pIndex = discoveredPeripherals.index(of: peripheral) {
                discoveredPeripherals.remove(at: pIndex)
            }
            
            outer.remove(peripheral: peripheral)
        }
        
        // Peripheral connection only handeling
        
        func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            if peripheral.services != nil {
                for service in peripheral.services! {
                    if service.uuid == outer.scannedPeripheralService {
                        peripheral.discoverCharacteristics(nil, for: service)
                        return
                    }
                }
            }
            
            outer.cbCentralManager.cancelPeripheralConnection(peripheral)
        }
        
        func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
            if service.characteristics != nil {
                
                var txchar:CBCharacteristic?
                var rxchar:CBCharacteristic?
                var infochar:CBCharacteristic?
                
                for characteristic in service.characteristics! {
                    if characteristic.uuid == SCCommon.TX_CHARACTERISTIC_UUID {
                        txchar = characteristic
                    }
                    if characteristic.uuid == SCCommon.RX_CHARACTERISTIC_UUID {
                        rxchar = characteristic
                    }
                    if characteristic.uuid == SCCommon.DISCOVERYINFO_CHARACTERISTIC_UUID {
                        infochar = characteristic
                    }
                }
                
                
                if txchar != nil && rxchar != nil && infochar != nil {
                    let device = Device(outer: outer, peripheral: peripheral, rxchar: rxchar!, txchar: txchar!, infochar: infochar!)
                    outer.connectedDevices.append(device)
                    peripheral.readValue(for: device.infochar)
                    
                    return
                }
                
            }
            
            outer.cbCentralManager.cancelPeripheralConnection(peripheral)
            
        }
        
        func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            if let dIndex = outer.connectedDevices.index(where: {$0.peripheral == peripheral}) {
                let device = outer.connectedDevices[dIndex]
                if characteristic == device.infochar && characteristic.value != nil {
                    peripheral.setNotifyValue(true, for: device.txchar)
                    return
                }
            }
            
            outer.cbCentralManager.cancelPeripheralConnection(peripheral)
        }
        
        func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
            if let dIndex = outer.connectedDevices.index(where: {$0.peripheral == peripheral}), error == nil {
                let device = outer.connectedDevices[dIndex]
                if characteristic == device.txchar && characteristic.isNotifying {
                    if let peer = SCPeer(fromDiscoveryData: device.infochar.value!) {
                        device.peer = peer
                        peripheral.delegate = device
                        outer.delegateQueue.async {
                            self.outer.delegate?.central(self.outer, didConnect: peer)
                        }
                        
                        return
                    }
                }
            }
            
            outer.cbCentralManager.cancelPeripheralConnection(peripheral)
        }
        
    }



}

