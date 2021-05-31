//
//  Peripheral.swift
//  NFCtoBLE
//
//  Created by Yann Godeau on 24/05/2021.
//

import CoreBluetooth
import SwiftUI
import OSLog

/// A typealias for the updated value handler
/// - Parameter characteristicUUID : The characteristic UUID
/// - Parameter data: The value of the characteristic
public typealias DidUpdateValue = (_ characteristicUUID: CBUUID, _ data: Data?) -> Void

open class Peripheral: NSObject, ObservableObject {

    /// The name of the peripheral.
    public internal(set) var name: String
    /// The [state](x-source-tag://PeripheralState) of the peripheral.
    public internal(set) var state: PeripheralState
    /// The CBPeripheral object.
    public let cbPeripheral: CBPeripheral
    /// The known services intended to be used.
    public var knownServices: [CBUUID]?
    /// A handler that the peripheral invokes when it notify your app of a change to the value of the characteristic
    /// for which the app previously enabled notifications.
    private var didUpdateValue: DidUpdateValue?

    required public init(with cbPeripheral: CBPeripheral) {
        self.name                  = cbPeripheral.name ?? "unknow"
        self.cbPeripheral          = cbPeripheral
        self.knownServices         = [CBUUID]()
        self.state                 = .unavailable
        super.init()

        self.cbPeripheral.delegate = self
    }

    /// Adds an action to perform  when a new value is received from the peripheral.
    /// - Parameter perform : The action to perform.
    public func onValueUpdated(_ perform: @escaping DidUpdateValue) {
        self.didUpdateValue = perform
    }
}

// MARK: - CBPeripheralDelegate
extension Peripheral: CBPeripheralDelegate {

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            Logger.peripheral.error("Error discovering services: \(error!.localizedDescription)")
            return
        }
        guard var services = peripheral.services else {
            return
        }

        if knownServices!.count > 0 {
            // If known services have been defined, only these are used
            services = services.filter { knownServices!.contains($0.uuid) }
        }

        for service in services {
            if self.state != .discoveringCharacteristics {
                self.state = .discoveringCharacteristics
            }
            Logger.peripheral.info("Peripheral - Known service \(service.uuid.uuidString) discovered")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral,
                           didDiscoverCharacteristicsFor service: CBService,
                           error: Error?) {
        guard error == nil else {
            Logger.peripheral.error("Failed discovering characteristics: \(error.debugDescription)")
            return
        }
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral,
                           didUpdateValueFor characteristic: CBCharacteristic,
                           error: Error?) {
        guard error == nil else {
            Logger.peripheral.error("Failed updating value: \(error.debugDescription)")
            return
        }

        if self.state == .discoveringCharacteristics {
            self.state = .ready
        }
        self.didUpdateValue?(characteristic.uuid, characteristic.value)
    }

    public func peripheral(_ peripheral: CBPeripheral,
                           didUpdateNotificationStateFor characteristic: CBCharacteristic,
                           error: Error?) {
        guard error == nil else {
            Logger.peripheral.error("Failed updating notification state: \(error.debugDescription)")
            return
        }

        Logger.peripheral.info("Did update notification state")
    }
}
