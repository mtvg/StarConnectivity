//
//  SCDataReception.swift
//  StarConnectivity
//
//  Created by Mathieu Vignau on 9/22/16.
//  Copyright © 2016 RED. All rights reserved.
//

import Foundation

internal class SCDataReception: NSObject {
    var onData:((Data, SCPriorityQueue)->())?
    var onInternalData:((Data, SCPriorityQueue)->())?
    
    private var receptionQueues = [UInt8:SCReceptionQueue]()
    
    func parse(packet data:Data) {
        var packetPointer = 0
        
        var header:UInt8 = 0
        data.copyBytes(to: &header, count: 1)
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
            queue.dataBuffer.count = 0
            packetPointer += data.copyBytes(to: UnsafeMutableBufferPointer(start: &queue.totalLength, count:1), from: packetPointer..<packetPointer+4)
        }
        
        queue.dataBuffer.append(data.subdata(in: packetPointer..<data.count))
        
        if queue.dataBuffer.count == Int(queue.totalLength) {
            let data = Data(queue.dataBuffer)
            if priorityQueue > 0xF {
                onInternalData?(data, SCPriorityQueue(rawValue: priorityQueue-0x10)!)
            } else {
                onData?(data, SCPriorityQueue(rawValue: priorityQueue)!)
            }
            
            queue.dataBuffer.count = 0
            queue.totalLength = 0
        }
        
    }
    
    private class SCReceptionQueue {
        var dataBuffer = Data()
        var totalLength:UInt32 = 0
    }
}
    
