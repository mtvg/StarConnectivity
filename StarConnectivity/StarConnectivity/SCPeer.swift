//
//  SCPeer.swift
//  StarConnectivity
//
//  Created by Mathieu Vignau on 7/2/16.
//  Copyright © 2016 RED. All rights reserved.
//


// Discovery Data format for protocol version 1:
//   [0-15]           [16]           [17-416]
//   16 bits          1 bit        0 to 400bits
// Peer UUID   Protocol Version   Optionnal JSON



import Foundation
import CoreBluetooth

public class SCPeer {
    
    
    static private var savedCBPeripheralPeers = [CBPeripheral:SCPeer]()
    static private var savedCBCentralPeers = [CBCentral:SCPeer]()
    
    public let protocolVersion:UInt8
    public let identifier:NSUUID
    private(set) public var identifierBytes = [UInt8](count: 16, repeatedValue: 0)
    private(set) public var discoveryInfo:JSON?
    private(set) public var discoveryData:NSData!
    
    init() {
        protocolVersion = SCCommon.STARCONNECTIVITY_PROTOCOL_VERSION
        identifier = NSUUID()
        generateUuidBytes()
        generateDiscoveryData()
    }
    
    init(withUUID id:NSUUID) {
        protocolVersion = SCCommon.STARCONNECTIVITY_PROTOCOL_VERSION
        identifier = id
        generateUuidBytes()
        generateDiscoveryData()
    }
    
    init?(withDiscoveryInfo discoveryInfo:JSON) {
        protocolVersion = SCCommon.STARCONNECTIVITY_PROTOCOL_VERSION
        identifier = NSUUID()
        self.discoveryInfo = discoveryInfo
        generateUuidBytes()
        if !generateDiscoveryData() {
            return nil
        }
    }
    
    init?(fromDiscoveryData discoveryData:NSData) {
        self.discoveryData = discoveryData
        if discoveryData.length < 17 {
            return nil
        }
        
        self.discoveryData.getBytes(&identifierBytes, length: 16)
        var protocolBytes = [UInt8](count: 1, repeatedValue: 0)
        discoveryData.getBytes(&protocolBytes, length: 1)
        protocolVersion = protocolBytes[0]
        
        
        identifier = NSUUID(UUIDBytes: identifierBytes)
        
        if discoveryData.length > 17 {
            discoveryInfo = JSON(data: discoveryData.subdataWithRange(NSMakeRange(17, discoveryData.length-17)))
        }
        
    }
    
    private func generateUuidBytes() {
        identifier.getUUIDBytes(&identifierBytes)
    }
    
    private func generateDiscoveryData() -> Bool {
        let buildDiscoveryData = NSMutableData()
        buildDiscoveryData.appendBytes(identifierBytes, length: 16)
        buildDiscoveryData.appendBytes([protocolVersion], length: 1)
        
        if discoveryInfo != nil, let infoData = try? discoveryInfo?.rawData() {
            if infoData == nil || infoData?.length > 400 {
                return false
            }
            buildDiscoveryData.appendData(infoData!)
        }
        
        discoveryData = NSData(data: buildDiscoveryData)
        
        return true
    }
}


func ==(lpeer: SCPeer, rpeer: SCPeer) -> Bool {
    return lpeer.discoveryData.isEqualToData(rpeer.discoveryData)
}
