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
    private(set) public var identifier:UUID
    
    private(set) public var discoveryInfo:JSON?
    private(set) public var discoveryData:Data!
    
    public init() {
        protocolVersion = SCCommon.STARCONNECTIVITY_PROTOCOL_VERSION
        identifier = UUID()
        _ = generateDiscoveryData()
    }
    
    public init(withUUID id:UUID) {
        protocolVersion = SCCommon.STARCONNECTIVITY_PROTOCOL_VERSION
        identifier = id
        _ = generateDiscoveryData()
    }
    
    public init?(withDiscoveryInfo discoveryInfo:JSON) {
        protocolVersion = SCCommon.STARCONNECTIVITY_PROTOCOL_VERSION
        identifier = UUID()
        self.discoveryInfo = discoveryInfo
        if !generateDiscoveryData() {
            return nil
        }
    }
    
    public init?(fromDiscoveryData discoveryData:Data) {
        self.discoveryData = discoveryData
        if discoveryData.count < 17 {
            return nil
        }
        
        identifier = UUID()
        _ = discoveryData.copyBytes(to: UnsafeMutableBufferPointer(start: &identifier, count:1), from: 0..<16)
        var protocolByte:UInt8 = 0
        discoveryData.copyBytes(to: &protocolByte, from: 16..<17)
        protocolVersion = protocolByte
        
        if discoveryData.count > 17 {
            discoveryInfo = JSON(data: discoveryData.subdata(in: 17..<discoveryData.endIndex))
        }
        
    }
    
    private func generateDiscoveryData() -> Bool {
        var buildDiscoveryData = Data()
        buildDiscoveryData.append(UnsafeBufferPointer(start: &identifier, count: 1))
        buildDiscoveryData.append(protocolVersion)
        
        if discoveryInfo != nil, let infoData = try? discoveryInfo?.rawData() {
            if infoData == nil || infoData!.count > 400 {
                return false
            }
            buildDiscoveryData.append(infoData!)
        }
        
        discoveryData = buildDiscoveryData
        
        return true
    }
}


public func ==(lpeer: SCPeer, rpeer: SCPeer) -> Bool {
    return lpeer.discoveryData == rpeer.discoveryData
}
