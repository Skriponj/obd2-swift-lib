//
//  CommandOperation.swift
//  OBD2Swift
//
//  Created by Sergiy Loza on 01.06.17.
//  Copyright © 2017 Lemberg. All rights reserved.
//

import Foundation

class CommandOperation: StreamHandleOperation {
    
    class func keyPathsForValuesAffectingIsFinished() -> Set<NSObject> {
        return ["readCompleted" as NSObject, "error" as NSObject]
    }
    
    private(set) var command:DataRequest
    private(set) var reader: StreamReader
    private var readCompleted = false {
        didSet {
            self.input.remove(from: .current, forMode: .defaultRunLoopMode)
            self.output.remove(from: .current, forMode: .defaultRunLoopMode)
        }
    }

    var onReceiveResponse:((_ response:Response) -> ())?
    var delay: UInt32 = 0
    
    init(inputStream: InputStream, outputStream: OutputStream, command: DataRequest) {
        self.command = command
        self.reader = StreamReader(stream: inputStream)
        super.init(inputStream: inputStream, outputStream: outputStream)
    }
    
    override var isFinished: Bool {
        if error != nil {
            return true
        }
        return readCompleted
    }
    
    override func execute() {
        guard let data = command.data else { return }
        let writer = StreamWriter(stream: output, data: data)
        do {
            try writer.write()
        } catch let error {
            print("Error \(error) on data writing")
            self.error = InitializationError.DataWriteError
        }
    }
    
    override func inputStremEvent(event: Stream.Event) {
        if event == .hasBytesAvailable {
            do {
                if try reader.read() {
                    onReadEnd()
                }
            } catch let error {
                self.error = error
            }
        }
    }
    
    private func onReadEnd() {
        let package = Package(buffer: reader.readBuffer, length: reader.readBufferLenght)
        var response = Parser.package.read(package: package)
        // if response has error and response pid not detected - set response pid from DataRequest
        if response.error != nil && response.pid == 0 {
            var requestPidComponent = "00"
            if command.description.components(separatedBy: " ").count == 1 {
                requestPidComponent = command.description.components(separatedBy: " ")[0]
            } else {
                requestPidComponent = command.description.components(separatedBy: " ")[1]
            }
            let pid = Parser.string.toUInt8(hexString: requestPidComponent)
            response.pid = UInt8(pid)
        }
        onReceiveResponse?(response)
        readCompleted = true
    }
}
