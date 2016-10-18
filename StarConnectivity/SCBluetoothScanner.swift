//
//  SCBluetoothBrowser.swift
//  StarConnectivity
//
//  Created by Mathieu Vignau on 9/27/16.
//  Copyright © 2016 RED. All rights reserved.
//

import Foundation
import CoreBluetooth

public class SCBluetoothScanner : NSObject {
    
    public weak var delegate:SCBluetoothScannerDelegate?
    public var delegateQueue = DispatchQueue.main
    
    private let cbCentralManager:CBCentralManager
    private var cbCentralManagerDelegate:CentralManagerDelegate!
    private let scannedCentralService:CBUUID
    
    public  var allowDuplicatesCentralScan = false
    public  var centralScanTimeout:Double = 10
    private var centralScanTimeoutTimer:Timer?
    private(set) public var isScanning = false
    private var scanningRequested = false
    
    private var availableCentrals = [ScannedCentral]()
    
    public init(serviceToBrowse service:UUID) {
        scannedCentralService = CBUUID(nsuuid: service)
        
        cbCentralManager = CBCentralManager(delegate: nil, queue: DispatchQueue(label: "starConnectivity_bluetoothScannerQueue"), options: [CBPeripheralManagerOptionShowPowerAlertKey:true])
        super.init()
        cbCentralManagerDelegate = CentralManagerDelegate(outer: self)
        cbCentralManager.delegate = cbCentralManagerDelegate
    }
    
    public func startScanning() {
        scanningRequested = true
        if cbCentralManager.state == .poweredOn {
            isScanning = true
            cbCentralManager.scanForPeripherals(withServices: [scannedCentralService], options: [CBCentralManagerScanOptionAllowDuplicatesKey:true])
            
            centralScanTimeoutTimer = Timer(timeInterval: 1.0, target: self, selector: #selector(checkPeripheralScanTimeout), userInfo: nil, repeats: true)
            RunLoop.main.add(centralScanTimeoutTimer!, forMode: RunLoopMode.commonModes)
        }
    }
    
    public func stopScanning() {
        isScanning = false
        scanningRequested = false
        cbCentralManager.stopScan()
        centralScanTimeoutTimer?.invalidate()
    }
    
    private func didFindCentral(_ central:SCPeer) {
        delegateQueue.async {
            self.delegate?.scanner(self, didFind: central)
        }
    }
    
    private func didRefindCentral(_ central:SCPeer) {
        if allowDuplicatesCentralScan {
            didFindCentral(central)
        }
    }
    
    private func didUpdateCentral(_ central:SCPeer) {
        delegateQueue.async {
            self.delegate?.scanner(self, didUpdate: central)
        }
    }
    
    private func didLooseCentral(_ central:SCPeer) {
        delegateQueue.async {
            self.delegate?.scanner(self, didLoose: central)
        }
    }
    
    @objc private func checkPeripheralScanTimeout() {
        while let index = availableCentrals.index(where: {$0.lastSeen.timeIntervalSinceNow < -centralScanTimeout}) {
            didLooseCentral(availableCentrals[index].peer)
            availableCentrals.remove(at: index)
        }
    }
    
    private class CentralManagerDelegate: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
        
        private weak var outer: SCBluetoothScanner!
        private var oldPeripheralState:CBPeripheralManagerState?
        
        private var discoveredPeripherals = [CBPeripheral]()
        private var discoveredPeripheralsID = [CBPeripheral:String]()
        
        init(outer: SCBluetoothScanner) {
            self.outer = outer
            super.init()
        }
        
        func centralManagerDidUpdateState(_ central: CBCentralManager) {
            if central.state == .poweredOn && outer.scanningRequested {
                outer.startScanning()
            }
            outer.delegateQueue.async {
                self.outer.delegate?.scanner(self.outer, didUpdateBluetoothState: SCBluetoothState(rawValue: central.state.rawValue)!)
            }
        }
        
        func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {

            if let pid = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
                if pid.characters.count < 3 || pid.substring(to: pid.index(pid.startIndex, offsetBy: 3)) != "SC#" {
                    return
                }
                
                if let index = outer.availableCentrals.index(where: {$0.peripheral == peripheral}) {
                    
                    outer.availableCentrals[index].lastSeen = NSDate()
                    outer.didRefindCentral(outer.availableCentrals[index].peer)
                    
                    if outer.availableCentrals[index].advertisingUID == pid {
                        return
                    }
                    
                    /*else {
                        outer.didLooseCentral(outer.availableCentrals[index].peer)
                        outer.availableCentrals.remove(at: index)
                    }*/
                }
                
                if discoveredPeripherals.index(of: peripheral) != nil {
                    return
                }
                
                peripheral.delegate = self
                discoveredPeripherals.append(peripheral)
                discoveredPeripheralsID[peripheral] = pid
                central.connect(peripheral, options: nil)
            }
        }
        
        func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
            peripheral.discoverServices([outer.scannedCentralService])
        }
        
        func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            if peripheral.services != nil {
                for service in peripheral.services! {
                    if service.uuid == outer.scannedCentralService {
                        peripheral.discoverCharacteristics(nil, for: service)
                        return
                    }
                }
            }
            outer.cbCentralManager.cancelPeripheralConnection(peripheral)
        }
        
        func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
            
            if service.characteristics != nil {
                for characteristic in service.characteristics! {
                    if characteristic.uuid == SCCommon.DISCOVERYINFO_CHARACTERISTIC_UUID {
                        peripheral.readValue(for: characteristic)
                        return
                    }
                }
            }
            
            outer.cbCentralManager.cancelPeripheralConnection(peripheral)
        }
        
        func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            if characteristic.uuid == SCCommon.DISCOVERYINFO_CHARACTERISTIC_UUID && characteristic.value != nil && outer.isScanning && error == nil {
                if let peer = SCPeer(fromDiscoveryData: characteristic.value!) {
                    var newNeeded = true
                    if let index = outer.availableCentrals.index(where: {$0.peripheral == peripheral}) {
                        if outer.availableCentrals[index].peer.identifier == peer.identifier {
                            newNeeded = false
                            outer.availableCentrals[index].peer = peer
                            outer.didUpdateCentral(peer)
                            outer.availableCentrals[index].lastSeen = NSDate()
                        } else {
                            outer.didLooseCentral(outer.availableCentrals[index].peer)
                            outer.availableCentrals.remove(at: index)
                        }
                    }
                    if newNeeded {
                        let p = ScannedCentral(peer: peer, peripheral: peripheral, lastSeen: NSDate(), advertisingUID: discoveredPeripheralsID[peripheral]!)
                        outer.availableCentrals.append(p)
                        outer.didFindCentral(peer)
                    }
                }
            }
            
            outer.cbCentralManager.cancelPeripheralConnection(peripheral)
        }
        
        func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
            if let index = discoveredPeripherals.index(of: peripheral) {
                discoveredPeripherals.remove(at: index)
                discoveredPeripheralsID.removeValue(forKey: peripheral)
            }
        }
        
        
    }
    
    private struct ScannedCentral {
        var peer:SCPeer
        let peripheral:CBPeripheral
        var lastSeen:NSDate
        let advertisingUID:String
    }
    

}
