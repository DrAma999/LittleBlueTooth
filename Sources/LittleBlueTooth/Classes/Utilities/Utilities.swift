//
//  Utilities.swift
//  LittleBlueTooth
//
//  Created by Andrea Finollo on 12/06/2020.
//  Copyright © 2020 Andrea Finollo. All rights reserved.
//

import Foundation
public extension Data {
    /// Deserialize a range of `Data` into a specific type
    /// - parameter start: start position
    /// - parameter lenght: number of bytes (8 bit) from start that you want to keep in range
    /// - returns: Deserializaztion into a specific type.
    func extract<T>(start: Int, length: Int) throws -> T {
        if start + length > self.count {
            throw LittleBluetoothError.deserializationFailedDataOfBounds(start: start, length: length, count: self.count)
        }
        return self.subdata(in: start..<start + length).withUnsafeBytes { $0.load(as: T.self) }
    }
}

/// Confomancy for `Data` object to `Writable` and `Readable` protocol
extension Data: Writable, Readable {
    public var data: Data {
        self
    }
    public init(from data: Data) {
        self = data
    }
}

extension UInt8: Writable, Readable {
   public var data: Data {
          Data([self])
    }
    public init(from data: Data) {
        self = data.map{$0}.first!
    }
}

public extension LittleBlueTooth {
    /// Function to create a `Data` object from an array of `Writable` objects
    static func assemble(_ writables: [Writable]) -> Data {
        var data = Data()
        
        writables.forEach { (bite) in
            data.append(bite.data)
        }
        
        return data
    }
}

extension OptionSet where RawValue: FixedWidthInteger {

    func elements() -> AnySequence<Self> {
        var remainingBits = rawValue
        var bitMask: RawValue = 1
        return AnySequence {
            return AnyIterator {
                while remainingBits != 0 {
                    defer { bitMask = bitMask &* 2 }
                    if remainingBits & bitMask != 0 {
                        remainingBits = remainingBits & ~bitMask
                        return Self(rawValue: bitMask)
                    }
                }
                return nil
            }
        }
    }
}
