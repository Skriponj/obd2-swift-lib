//
//  Sanner.swift
//  OBD2Swift
//
//  Created by Max Vitruk on 24/05/2017.
//  Copyright © 2017 Lemberg. All rights reserved.
//

import Foundation

enum ReadInputError: Error {
    case initResponseUnreadable
}

enum InitScannerError: Error {
    case outputTimeout
    case inputTimeout
}

public typealias StateChangeCallback = (_ state: ScanState) -> ()

class `Scanner`: StreamHolder {
    
    typealias CallBack = (Bool, Error?) -> ()
    
    
    var defaultSensors: [UInt8] = [0x0C, 0x0D]
    
    var supportedSensorList = [Int]()
    
    private var repeatCommands = Set<DataRequest>()

    var state: ScanState = .none {
        didSet {
            if state == .none {
                obdQueue.cancelAllOperations()
            }
            stateChanged?(state)
        }
    }
    
    var stateChanged: StateChangeCallback?
    
    var `protocol`: ScanProtocol = .none
    
    var currentPIDGroup: UInt8 = 0x00
    
    init(host: String, port: Int) {
        super.init()
        self.host = host
        self.port = port
        
        delegate = self
    }
    
    open func request(command: DataRequest, response : @escaping (_ response:Response) -> ()){
        
        let request = CommandOperation(inputStream: inputStream, outputStream: outputStream, command: command)
        
        request.onReceiveResponse = response
        request.queuePriority = .high
        request.completionBlock = {
            print("Request operation completed")
        }
        
        obdQueue.addOperation(request)
    }
    
    
    open func startRepeatCommand(command: DataRequest, delay: UInt32, response : @escaping (_ response:Response) -> ()) {
        if repeatCommands.contains(command) {
            print("Command alredy on repeat loop and can be observed")
            return
        }
        repeatCommands.insert(command)
        request(repeat: command, delay: delay, response: response)
    }
    
    open func stopRepeatCommand(command: DataRequest) {
        repeatCommands.remove(command)
    }
    
    open func isRepeating(command: DataRequest) -> Bool {
        return repeatCommands.contains(command)
    }
    
    private func request(repeat command: DataRequest, delay: UInt32, response : @escaping (_ response:Response) -> ()) {
        
        let request = CommandOperation(inputStream: inputStream, outputStream: outputStream, command: command)
        
        request.queuePriority = .low
        request.onReceiveResponse = response
        request.completionBlock = { [weak self] in
            print("Request operation completed")
            if let error = request.error {
                print("Error occured \(error)")
                self?.state = .none
            } else {
                guard let strong = self else { return }
                if strong.repeatCommands.contains(command) {
                    strong.request(repeat: command, delay: delay, response: response)
                }
            }
        }
        
        obdQueue.addOperation(request)
    }
    
    open func startScan(callback: @escaping CallBack){
        
        if state != .none {
            return
        }
        
        state = .openingConnection
        
        obdQueue.cancelAllOperations()
        
        createStreams()
        Logger.info("I/O streams created")
        // Open connection to OBD
        Logger.info("Start open connection")
        
        let openConnectionOperation = OpenOBDConnectionOperation(inputStream: inputStream, outputStream: outputStream)
        
        openConnectionOperation.completionBlock = { [weak self] in
            if let error = openConnectionOperation.error {
                callback(false, error)
                print("open operation completed with error \(error)")
                Logger.error("""
                        \n
                        Session ID: \(Logger.currentSessionId ?? "EMPTY DATA")
                        Open connection faild!
                        Description: \(error.localizedDescription)
                        Error: \(error)
                        """)
                self?.state = .none
                self?.obdQueue.cancelAllOperations()
            } else {
                self?.state = .initializing
                print("open operation completed without errors")
                Logger.info("Open connection succesfull")
            }
        }
        
        obdQueue.addOperation(openConnectionOperation)
        
        // Initialize connection with OBD
        
        let initOperation = InitScanerOperation(inputStream: inputStream, outputStream: outputStream)
        initOperation.completionBlock = { [weak self] in
            if let error = initOperation.error {
//                callback(false, error)
                self?.state = .none
                self?.obdQueue.cancelAllOperations()
                Logger.error("""
                        \n
                        Session ID: \(Logger.currentSessionId ?? "EMPTY DATA")
                        Init connection faild!
                        Description: \(error.localizedDescription)
                        Error: \(error)
                    """)
            } else {
                self?.state = .connected
                Logger.info("Connection init successful")
                callback(true, nil)
            }
        }
        
        obdQueue.addOperation(initOperation)
    }
    
    open func pauseScan() {
        obdQueue.isSuspended = true
    }
    
    open func resumeScan() {
        obdQueue.isSuspended = false
    }
    
    open func cancelScan() {
        repeatCommands.removeAll()
        obdQueue.cancelAllOperations()
    }
    
    open func disconnect() {
        cancelScan()
        inputStream.close()
        outputStream.close()
        state = .none
    }
    
    open func isService01PIDSupported(pid : Int) -> Bool {
        var supported = false
        
        for supportedPID in supportedSensorList {
            if supportedPID == pid {
                supported = true
                break
            }
        }
        
        return supported
    }
}

extension Scanner: StreamFlowDelegate {
    
    func didOpen(stream: Stream){
        
    }
    
    func error(_ error: Error, on stream: Stream){
        
    }
    
    func hasInput(on stream: Stream){
        //
        //    do {
        //
        //        if state == .init {
        //          try readInitResponse()
        //        } else if state == .idle || state == .waiting {
        //            waitingForVoltageCommand ? readVoltageResponse() : readInput()
        //
        //        } else {
        //          print("Error: Received bytes in unknown state: \(state)")
        //        }
        //
        //    } catch {
        //
        //        print("Error: Init response unreadable. Need reconnect")
        //        //TODO: try reconnect
        //    }
        //
        //
    }
}

extension Scanner {
    enum State : UInt {
        case unknown			= 1
        case reset				= 2
        case spacesOff          = 4
        case headersOff         = 8
        case echoOff			= 16
        case version 			= 32
        case search       = 64
        case `protocol`   = 128
        case complete     = 256
        
        static var all : [State] {
            return [.unknown, .reset, .spacesOff, .headersOff, .echoOff, .version, .search, .`protocol`, .complete]
        }
        
        static func <<= (left: State, right: UInt) -> State {
            let move = left.rawValue << right
            return self.all.filter({$0.rawValue == move}).first ?? .unknown
        }
        
        mutating func next() {
            self = self <<= 1
        }
    }
}
