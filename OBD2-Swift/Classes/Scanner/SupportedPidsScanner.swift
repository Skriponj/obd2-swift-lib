//
//  SupportedPidsScanner.swift
//  OBD2-Swift
//
//  Created by Anton Skrypnik on 7/18/18.
//

import Foundation

public struct SupportedPid {
    public var pid: Int
    public var description: String
    public var shortDescription: String
    
    public init(pid: Int, descr: String, sDescr: String) {
        self.pid = pid
        self.description = descr
        self.shortDescription = sDescr
    }
}

open class SupportedPidsScanner {
    
    var supportedSensorList: [Int]
    
    private(set) var currentPIDGroup: UInt8 = 0x00 {
        didSet {
            print("Set new pid group \(currentPIDGroup)")
        }
    }
    
    public init() {
        supportedSensorList = []
    }
    
    public func searchForSupportedPids(response: Response) -> [SupportedPid] {
        if !supportedSensorList.isEmpty {
            supportedSensorList.removeAll()
        }
        
        let data = response.data
        var extendPIDSearch    = false
        
        if data != nil {
//            let morePIDs = buildSupportedSensorList(data: data!, pidGroup: Int(currentPIDGroup))
//
//            if !extendPIDSearch && morePIDs {
//                extendPIDSearch    = true
//            }
            
            for pidGroup in stride(from: 0x00, through: 0x40, by: 0x20) {
                buildSupportedSensorList(data: data!, pidGroup: pidGroup)
            }
        }
        
//        currentPIDGroup    += extendPIDSearch ? 0x20 : 0x00
//
//        if extendPIDSearch {
//            if currentPIDGroup > 0x40 {
//                currentPIDGroup    = 0x00
//            }
//        }else{
//            currentPIDGroup    = 0x00
//        }
        
        var pids: [SupportedPid] = []
        supportedSensorList.forEach { (pid) in
            let sensors = SensorDescriptorTable.filter{ Int($0.pid) == pid }
            if !sensors.isEmpty {
                let item = sensors.first!
                let sPid = SupportedPid(pid: Int(item.pid), descr: item.description, sDescr: item.shortDescription)
                pids.append(sPid)
            }
        }
        
        return pids
    }
    
    private func buildSupportedSensorList(data : Data, pidGroup : Int) {
        
        let bytes = data.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: data.count))
        }
        
        let bytesLen = bytes.count
        
        if bytesLen != 4 {
            return
        }
        
        /*    if(pidGroup == 0x00) {
         // If we are re-issuing the PID search command, reset any
         // previously received PIDs
         */
        
        var pid         = pidGroup + 1
        var supported    = false
        let shiftSize   = 7
        
        for i in 0..<4 {
            for y in 0...7 {
                let leftShift = UInt8(shiftSize - y)
                supported   = (((1 << leftShift) & bytes[i]) != 0)
                pid += 1
                
                if(supported) {
                    if NOT_SEARCH_PID(pid) && pid <= 0x4E && !supportedSensorList.contains(where: {$0 == pid}){
                        supportedSensorList.append(pid)
                    }
                }
            }
        }
    }
}
