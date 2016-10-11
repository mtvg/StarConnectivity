//
//  SCPeer.swift
//  StarConnectivity
//
//  Created by Mathieu Vignau on 7/2/16.
//  Copyright © 2016 RED. All rights reserved.
//


// Discovery Data format for protocol version 1:
//   [0-15]           [16]             [17-18]          [19-418]
//  16 bytes         1 byte            2 bytes        0 to 400bits
// Peer UUID   Protocol Version     Payload Size   Optionnal Payload



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
        
        var payloadLength:UInt16 = 0
        _ = discoveryData.copyBytes(to: UnsafeMutableBufferPointer(start: &payloadLength, count: 1), from: 17..<19)
        
        let payloadEnd = Int(19+payloadLength)
        if discoveryData.count > 19, discoveryData.count >= payloadEnd {
            discoveryInfo = JSON(data: discoveryData.subdata(in: 19..<payloadEnd))
        }
        
    }
    
    public func update(discoveryInfo:JSON) -> Bool {
        let oldInfo = self.discoveryInfo
        self.discoveryInfo = discoveryInfo
        let infoIsValid = generateDiscoveryData()
        if !infoIsValid {
            self.discoveryInfo = oldInfo
        }
        return infoIsValid
    }
    
    private func generateDiscoveryData() -> Bool {
        var buildDiscoveryData = Data()
        buildDiscoveryData.append(UnsafeBufferPointer(start: &identifier, count: 1))
        buildDiscoveryData.append(protocolVersion)
        
        if discoveryInfo != nil, let infoData = try? discoveryInfo?.rawData() {
            if infoData == nil || infoData!.count > 400 {
                return false
            }
            var payloadLength = UInt16(infoData!.count)
            buildDiscoveryData.append(UnsafeBufferPointer(start: &payloadLength, count: 1))
            buildDiscoveryData.append(infoData!)
        }
        
        discoveryData = buildDiscoveryData
        
        return true
    }
}


public func ==(lpeer: SCPeer, rpeer: SCPeer) -> Bool {
    return lpeer.discoveryData == rpeer.discoveryData
}
