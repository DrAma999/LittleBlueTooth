//
//  Helper.swift
//  LittleBlueTooth
//
//  Created by Andrea Finollo on 09/08/2020.
//

import Foundation
import Combine
import os.log
#if TEST
import CoreBluetoothMock
#else
import CoreBluetooth
#endif

extension AnyCancellable {
  func store(in dictionary: inout [UUID : AnyCancellable],
             for key: UUID) {
    dictionary[key] = self
  }
}
extension Publisher {

   func flatMapLatest<T: Publisher>(_ transform: @escaping (Self.Output) -> T) -> AnyPublisher<T.Output, T.Failure> where T.Failure == Self.Failure {
       return map(transform).switchToLatest().eraseToAnyPublisher()
   }
}

extension TimeInterval {
    public var dispatchInterval: DispatchTimeInterval {
        let microseconds = Int64(self * TimeInterval(USEC_PER_SEC)) // perhaps use nanoseconds, though would more often be > Int.max
        return microseconds < Int.max ? DispatchTimeInterval.microseconds(Int(microseconds)) : DispatchTimeInterval.seconds(Int(self))
    }
}

extension OSLog {
    public static var Subsystem = "it.vanillagorilla.LittleBlueTooth"
    public static var General = "General"
    public static var CentralManager = "CentralManager"
    public static var Peripheral = "Peripheral"
    public static var Restore = "Restore"

    public static let LittleBT_Log_General = OSLog(subsystem: Subsystem, category: General)
    public static let LittleBT_Log_CentralManager = OSLog(subsystem: Subsystem, category: CentralManager)
    public static let LittleBT_Log_Peripheral = OSLog(subsystem: Subsystem, category: Peripheral)
    public static let LittleBT_Log_Restore = OSLog(subsystem: Subsystem, category: Restore)

}
#if TEST
extension CBMPeripheral {
    public var description: String {
        return "Test peripheral"
    }
}
#endif
