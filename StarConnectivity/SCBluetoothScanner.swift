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
    
    private let cbCentralManager:CBCentralManager
    private var cbCentralManagerDelegate:CentralManagerDelegate!
    private let scannedCentralService:CBUUID
    
    public  var allowDuplicatesCentralScan = false
    public  var centralScanTimeout:Double = 10
    private var centralScanTimeoutTimer:NSTimer?
    private(set) public var isScanning = false
    private var scanningRequested = false
    
    private var availableCentrals = [ScannedCentral]()
    
    public init(serviceToBrowse service:SCUUID) {
        scannedCentralService = service
        
        cbCentralManager = CBCentralManager()
        super.init()
        cbCentralManagerDelegate = CentralManagerDelegate(outer: self)
        cbCentralManager.delegate = cbCentralManagerDelegate
    }
    
    public func startScanning() {
        scanningRequested = true
        if cbCentralManager.state == .PoweredOn {
            isScanning = true
            cbCentralManager.scanForPeripheralsWithServices([scannedCentralService], options: [CBCentralManagerScanOptionAllowDuplicatesKey:true])
            centralScanTimeoutTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(checkPeripheralScanTimeout), userInfo: nil, repeats: true)
        }
    }
    
    public func stopScanning() {
        isScanning = false
        scanningRequested = false
        cbCentralManager.stopScan()
        centralScanTimeoutTimer?.invalidate()
    }
    
    private func didFindCentral(central:SCPeer) {
        delegate?.scanner(self, didFindCentral: central)
    }
    
    private func didRefindCentral(central:SCPeer) {
        if allowDuplicatesCentralScan {
            didFindCentral(central)
        }
    }
    
    private func didLooseCentral(central:SCPeer) {
        delegate?.scanner(self, didLooseCentral: central)
    }
    
    @objc private func checkPeripheralScanTimeout() {
        while let index = availableCentrals.indexOf({$0.lastSeen.timeIntervalSinceNow < -centralScanTimeout}) {
            didLooseCentral(availableCentrals[index].peer)
            availableCentrals.removeAtIndex(index)
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
        
        @objc func centralManagerDidUpdateState(central: CBCentralManager) {
            if central.state == .PoweredOn && outer.scanningRequested {
                outer.startScanning()
            }
            outer.delegate?.bluetoothStateUpdated(SCBluetoothState(rawValue: central.state.rawValue)!)
        }
        
        @objc func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {

            if let pid = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
                
                if pid.characters.count < 3 || pid.substringToIndex(pid.startIndex.advancedBy(3)) != "SC#" {
                    return
                }
                
                if let index = outer.availableCentrals.indexOf({$0.peripheral == peripheral}) {
                    
                    if outer.availableCentrals[index].advertisingUID == pid {
                        outer.availableCentrals[index].lastSeen = NSDate()
                        outer.didRefindCentral(outer.availableCentrals[index].peer)
                        return
                    } else {
                        outer.didLooseCentral(outer.availableCentrals[index].peer)
                        outer.availableCentrals.removeAtIndex(index)
                    }
                }
                
                if discoveredPeripherals.indexOf(peripheral) != nil {
                    return
                }
                
                peripheral.delegate = self
                discoveredPeripherals.append(peripheral)
                discoveredPeripheralsID[peripheral] = pid
                central.connectPeripheral(peripheral, options: nil)
            }
        }
        
        @objc func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
            peripheral.discoverServices([outer.scannedCentralService])
        }
        
        @objc func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
            if peripheral.services != nil {
                for service in peripheral.services! {
                    if service.UUID == outer.scannedCentralService {
                        peripheral.discoverCharacteristics(nil, forService: service)
                        return
                    }
                }
            }
            outer.cbCentralManager.cancelPeripheralConnection(peripheral)
        }
        
        @objc func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
            
            if service.characteristics != nil {
                for characteristic in service.characteristics! {
                    if characteristic.UUID == SCCommon.DISCOVERYINFO_CHARACTERISTIC_UUID {
                        peripheral.readValueForCharacteristic(characteristic)
                        return
                    }
                }
            }
            
            outer.cbCentralManager.cancelPeripheralConnection(peripheral)
        }
        
        @objc func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
            if characteristic.UUID == SCCommon.DISCOVERYINFO_CHARACTERISTIC_UUID && characteristic.value != nil && outer.isScanning && error == nil {
                if let peer = SCPeer(fromDiscoveryData: characteristic.value!) {
                    let p = ScannedCentral(peer: peer, peripheral: peripheral, lastSeen: NSDate(), advertisingUID: discoveredPeripheralsID[peripheral]!)
                    outer.availableCentrals.append(p)
                    outer.didFindCentral(peer)
                }
            }
            
            outer.cbCentralManager.cancelPeripheralConnection(peripheral)
        }
        
        @objc func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
            if let index = discoveredPeripherals.indexOf(peripheral) {
                discoveredPeripherals.removeAtIndex(index)
                discoveredPeripheralsID.removeValueForKey(peripheral)
            }
        }
        
        
    }
    
    private struct ScannedCentral {
        let peer:SCPeer
        let peripheral:CBPeripheral
        var lastSeen:NSDate
        let advertisingUID:String
    }
    

}
