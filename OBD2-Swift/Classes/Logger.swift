//
//  Logger.swift
//  OBD2Swift
//
//  Created by Hellen Soloviy on 5/31/17.
//  Copyright © 2017 Lemberg. All rights reserved.
//

import Foundation
import UIKit

//func print(_ string: String) {
//    Logger.shared.log(string)
////    NSLog(string)
//}

enum LoggerMessageType {
    
    case debug
    case error
    case info
    case verbose //default
    case warning
    
}


enum LoggerSourceType {
    
    case console
    case file //default
    
}

open class Logger {
    
    static var sourceType: LoggerSourceType = .console
    static let queue = OperationQueue()
    private static let loggerFormatter = DateFormatter()
    
    static let logDirName = "OBD_Logs"
    public static var filePaths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first?.appending("//OBD2Logger.txt") ?? "/OBD2Logger.txt"
    static public var currentSessionId: String?
    
    public static func warning(_ message:String) {
        newLog(message, type: .warning)
    }
    
    public static func info(_ message:String) {
        newLog(message, type: .info)
    }
    
    public static func error(_ message:String) {
        newLog(message, type: .error)
    }
    
    public static func logToNewSessionWith(host: String, port: Int) {
        loggerFormatter.dateFormat = "y-MM-dd H-mm-ss-SSSS"
        
        let logsDirectoryPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!.appending("/\(logDirName)")
        if !FileManager.default.fileExists(atPath: logsDirectoryPath) {
            try? FileManager.default.createDirectory(atPath: logsDirectoryPath, withIntermediateDirectories: false, attributes: nil)
        }
        
        guard let fileList = try? FileManager.default.contentsOfDirectory(atPath: logsDirectoryPath) else {
            return
        }
        
        var existLogFilePath: String? {
            
            let oneDay: TimeInterval = 60 * 60 * 24
            for fileName in fileList {
                
                let fileNameWithoutExtension = fileName.replacingOccurrences(of: ".log", with: "")
                let fileNameComponents = fileNameWithoutExtension.components(separatedBy: "_")
                if fileNameComponents.count != 2 {
                    print("The file is not an OBD log. Ignore.")
                    continue
                }
                
                let logDate = loggerFormatter.date(from: fileNameComponents[1])
                if logDate == nil {
                    print("Invalid log date. Ignore.")
                    continue
                }
                
                if abs(logDate!.timeIntervalSinceNow) < oneDay {
                    return logsDirectoryPath.appending("/\(fileName)")
                } else {
                    //Remove old log file
                    try? FileManager.default.removeItem(atPath: logsDirectoryPath.appending("/\(fileName)"))
                }
            }
            
            return nil
        }
        
        if let path = existLogFilePath {
            // Write to exist file
            filePaths = path
        } else {
            // Write to a new file
            filePaths = logsDirectoryPath.appending("/OBDLog_\(loggerFormatter.string(from: Date())).log")
        }
        
        let logSessionId = UUID().uuidString
        currentSessionId = logSessionId
        
        Logger.info("""
            
            ==============================================================
            """)
        Logger.info("Start new log session")
        Logger.info("Log session ID: \(logSessionId)")
        Logger.info("""
            
            CONNECTION INFO:
            host: \(host)
            port: \(port)
            
            DEVICE INFO:
            Model: \(UIDevice.current.model)
            iOS ver: \(UIDevice.current.systemVersion)
            
        """)
    }
    
    public static func shareFile(on viewController: UIViewController) {
        
        let activityVC = UIActivityViewController(activityItems: fileToShare(), applicationActivities: nil)
        viewController.present(activityVC, animated: true, completion: nil)
        
    }
    
    public static func fileToShare() -> [Any] {
        
        let comment = "Logger file"
        let fileURL = URL(fileURLWithPath: filePaths)
        return [comment, fileURL] as [Any]
        
    }

    
    public static func cleanLoggerFile() {
        
        do {
            try  " ".write(toFile: filePaths, atomically: true, encoding: String.Encoding.utf8)
        } catch let error {
            print("Failed writing to log file: \(filePaths), Error: " + error.localizedDescription)
        }
    }
    
    
    private static func newLog(_ message:String, type: LoggerMessageType = .verbose) {
        
        queue.maxConcurrentOperationCount = 1
        loggerFormatter.dateFormat = "y-MM-dd H:mm:ss.SSSS"
        queue.addOperation {
            
            let log = "[\(loggerFormatter.string(from: Date()))] [\(type)] \(message)"

            var content = ""
            if FileManager.default.fileExists(atPath: filePaths) {
                content =  try! String(contentsOfFile: filePaths, encoding: String.Encoding.utf8)
            }
            
            do {
                try  "\(content)\n\(log)".write(toFile: filePaths, atomically: true, encoding: String.Encoding.utf8)
                
            } catch let error {
                print("Failed writing to log file: \(filePaths), Error: " + error.localizedDescription)
            }
            
        }

    }
    
    
}
