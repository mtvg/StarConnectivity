//
//  SCDataReception.swift
//  StarConnectivity
//
//  Created by Mathieu Vignau on 9/22/16.
//  Copyright © 2016 RED. All rights reserved.
//

import Foundation

internal class SCDataReception: NSObject {
    var onData:((NSData, UInt8)->())?
    var onInternalData:((NSData, UInt8)->())?
    
    private var receptionQueues = [UInt8:SCReceptionQueue]()
    
    func parsePacket(data:NSData) {
        var packetPointer = 0
        
        var header:UInt8 = 0
        data.getBytes(&header, length: 1)
        packetPointer += 1
        
        var priorityQueue:UInt8 = header >> 4
        if header&2 == 2 {
            priorityQueue += 0x10
        }
        
        if receptionQueues[priorityQueue] == nil {
            receptionQueues[priorityQueue] = SCReceptionQueue()
        }
        
        let queue = receptionQueues[priorityQueue]!
        
        if header&1 == 1 {
            data.getBytes(&queue.totalLength, range: NSMakeRange(packetPointer, 4))
            packetPointer += 4
        }
        
        queue.dataBuffer.appendData(data.subdataWithRange(NSMakeRange(packetPointer, data.length-packetPointer)))
        if queue.dataBuffer.length == Int(queue.totalLength) {
            let data = NSData(data: queue.dataBuffer)
            if priorityQueue > 0xF {
                onInternalData?(data, priorityQueue-0x10)
            } else {
                onData?(data, priorityQueue)
            }
            
            queue.dataBuffer.length = 0
            queue.totalLength = 0
        }
        
    }
    
    private class SCReceptionQueue {
        var dataBuffer = NSMutableData()
        var totalLength:UInt32 = 0
    }
}
    
