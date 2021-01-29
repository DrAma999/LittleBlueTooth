//
//  Log.swift
//  LittleBlueTooth
//
//  Created by Andrea Finollo on 29/01/21.
//

import Foundation
import Combine

extension Publisher {
    func customPrint(_ prefix: String = "", to: TextOutputStream? = nil, isEnabled: Bool = true) -> AnyPublisher<Self.Output, Self.Failure> {
        if isEnabled {
            return print(prefix, to: to).eraseToAnyPublisher()
        }
        return AnyPublisher(self)
    }
}
