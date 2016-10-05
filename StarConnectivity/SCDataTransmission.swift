//
//  SCDataTransmission.swift
//  StarConnectivity
//
//  Created by Mathieu Vignau on 9/22/16.
//  Copyright © 2016 RED. All rights reserved.
//

import Foundation

internal class SCDataTransmission: NSObject {
    
    private let MAX_ERROR = 5
    private let PACKET_SIZE = 100
    private var transmissionQueues = [SCPriorityQueue:SCTransmissionQueue]()
    private var transmissionQueuesKeys = [SCPriorityQueue]()
    
    private var lastTransmitedQueue:SCTransmissionQueue?
    private var lastTransmitedLength = 0
    
    private var lastPacketErrorCount = 0
    
    func getNextPacket(repeatLastPacket:Bool=false) -> Data? {
        
        if repeatLastPacket {
            lastPacketErrorCount += 1
            
            if lastPacketErrorCount >= MAX_ERROR, let queue = lastTransmitedQueue {
                queue.dataQueue.removeFirst()
                queue.bytesSent = 0
                lastPacketErrorCount = 0
                lastTransmitedQueue = nil
                lastTransmitedLength = 0
                
                if let callback = queue.callbackQueue.removeFirst() {
                    callback(false)
                }
            }
        } else if let queue = lastTransmitedQueue {
            
            queue.bytesSent += lastTransmitedLength
            
            if queue.bytesSent == queue.dataQueue[0].count {
                queue.dataQueue.removeFirst()
                queue.bytesSent = 0
                
                if let callback = queue.callbackQueue.removeFirst() {
                    callback(true)
                }
            }
            
            lastPacketErrorCount = 0
            lastTransmitedQueue = nil
            lastTransmitedLength = 0
        }

        
        for key in transmissionQueuesKeys {
            let queue = transmissionQueues[key]!
            if queue.dataQueue.count > 0 {
                
                // Header byte 4 last bits = priority queue
                var header:UInt8 = key << 4
                var packet = Data()
                var size = UInt32(queue.dataQueue[0].count)
                
                if key > 0xF {
                    header |= 2
                }
                if queue.bytesSent == 0 {
                    // Mark packet header as begining of data, add header byte to packet
                    header |= 1
                    packet.append(header)
                    packet.append(UnsafeBufferPointer(start: &size, count: 1))
                } else {
                    // Add header byte to packet
                    packet.append(&header, count: 1)
                }
                
                let range:Range<Int> = queue.bytesSent..<queue.bytesSent+min(PACKET_SIZE-packet.count, Int(size)-queue.bytesSent)
                packet.append(queue.dataQueue[0].subdata(in: range))
                
                lastTransmitedQueue = queue
                lastTransmitedLength = range.count
                
                return packet
            }
        }
        
        return nil
    }
    
    func add(data:Data, to priorityQueue:SCPriorityQueue, flushQueue:Bool, internalData:Bool, callback:((Bool) -> Void)?) {
        
        if priorityQueue > 0xF {
            return
        }
        
        var queueKey = priorityQueue
        if internalData {
            queueKey += 0x10
        }
        
        if transmissionQueues[queueKey] == nil {
            transmissionQueues[queueKey] = SCTransmissionQueue()
            transmissionQueuesKeys = transmissionQueues.keys.sorted(by: >)
        }
        
        let queue = transmissionQueues[queueKey]!
        
        if flushQueue {
            queue.dataQueue.removeAll()
            queue.bytesSent = 0
        }
        
        queue.dataQueue.append(data)
        queue.callbackQueue.append(callback)
    }
    
    private class SCTransmissionQueue {
        var dataQueue = [Data]()
        var callbackQueue:[((Bool) -> Void)?] = []
        var bytesSent = 0
    }
    
}
