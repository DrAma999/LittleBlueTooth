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
    func log(_ message: StaticString, log: OSLog, type: OSLogType, arg: CVarArg...)
}


extension Loggable  {
    func log(_ message: StaticString, log: OSLog, type: OSLogType, arg: CVarArg...) {
        #if !TEST
        guard isLogEnabled else {
            return
        }
        os_log(type, log: log, message, arg)
        #endif
    }
}
