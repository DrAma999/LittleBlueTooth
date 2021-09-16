//
//  Loggable.swift
//  LittleBlueTooth
//
//  Created by Andrea Finollo on 07/08/2020.
//

import Foundation
import os.log

protocol Loggable {
    var isLogEnabled: Bool {get set}
    func log(_ message: StaticString, log: OSLog, type: OSLogType, arg: [CVarArg])
}


extension Loggable  {
    func log(_ message: StaticString, log: OSLog, type: OSLogType, arg: [CVarArg]) {
        assert(arg.count <= 3)
        #if !TEST
        // https://stackoverflow.com/questions/50937765/why-does-wrapping-os-log-cause-doubles-to-not-be-logged-correctly/50942917#50942917
        guard isLogEnabled else {
            return
        }
        switch arg.count {
        case 1:
            os_log(type, log: log, message, arg[0])
        case 2:
            os_log(type, log: log, message, arg[0], arg[1])
        case 3:
            os_log(type, log: log, message, arg[0], arg[1], arg[2])
        default:
            os_log(type, log: log, message)
        }
        #endif
    }
}
