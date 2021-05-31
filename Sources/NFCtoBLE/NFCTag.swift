//
//  NFCTag.swift
//  NFCtoBLE
//
//  Created by Yann Godeau on 05/05/2021.
//

import CoreNFC
import SwiftUI
import SimplyNFC
import CoreBluetooth
import OSLog

/// Represents the NFC tag used to establish a connection with a BLE device.
@propertyWrapper
public class NFCTag<T: Codable> {
    public typealias DidRead = (NFCManager, Result<CodableTag<T>, Error>) -> Void

    // MARK: - Properties
    public var wrappedValue: T?
    public var pairingKey: String = ""

    private let nfcManager = NFCManager()
    private var peripheralManager = PeripheralManager()

    public init(pairingKey: String) {
        self.pairingKey = pairingKey
    }

    public init(wrappedValue value: T?, pairingKey: String?) {
        self.wrappedValue = value
        self.pairingKey = pairingKey ?? ""
    }

    // MARK: - Functions

    /// Starts reading NFC tag
    /// - Parameter didBecomeActive: Gets called when the manager has started reading
    /// - Parameter didRead: Gets called when the manager detects NFC tag or occurs some errors
    public func read(didBecomeActive: NFCManager.DidBecomeActive? = nil, didRead: @escaping DidRead) {
        nfcManager.read { manager in
            didBecomeActive?(manager)
        } didDetect: { _, result in
            switch result {
            case .failure(let error):
                didRead(self.nfcManager, .failure(error))
            case .success:
                guard let payload = try? result.get()?.records.first?.payload,
                      let decoded = try? JSONDecoder().decode(CodableTag<T>.self, from: payload) else {
                    return
                }
                self.pairingKey = decoded.pairingKey ?? ""
                self.wrappedValue = decoded.value
                didRead(self.nfcManager, .success(decoded))
            }
        }
    }

    /// Starts writing the `@NFCTag`  property as [CodableTag](x-source-tag://CodableTag) on NFC tag
    /// - Parameter didBecomeActive: Gets called when the manager has started writing
    /// - Parameter didWrite: Gets called when the manager detects NFC tag or occurs some errors
    public func write(didBecomeActive: NFCManager.DidBecomeActive? = nil, didWrite: @escaping DidRead) {
        let codable = CodableTag<T>(pairingKey: self.pairingKey, value: self.wrappedValue)
        guard let data = try? JSONEncoder().encode(codable) else {
            return
        }
        let payload = NFCNDEFPayload(
          format: .unknown,
          type: Data(),
          identifier: Data(),
          payload: data)
        let message = NFCNDEFMessage(records: [payload])

        nfcManager.write(message: message) { manager in
            didBecomeActive?(manager)
        } didDetect: { manager, result in
            switch result {
            case .failure(let error):
                didWrite(manager, .failure(error))
                Logger.nfctag.error("Failed to write tag : \(error.localizedDescription)")
            case .success:
                didWrite(manager, .success(codable))
                Logger.nfctag.error("Successfully write tag")
            }
        }
    }

    /// Scans an NFC tag and tries to connect to the associated peripheral using the readed pairing key
    /// - Parameter services: Target services to be used
    /// - Parameter didBecomeActive: Gets called when the NFC session has becomes active
    /// - Parameter didRead: Gets called when the manager has read  a tag or occurs some errors
    /// - Parameter didConnect: Gets called when the manager has paired  with a peripheral
    public func scanToConnect(withServices services: [CBUUID]? = nil,
                              didBecomeActive: NFCManager.DidBecomeActive? = nil,
                              didRead: DidRead? = nil,
                              didConnect: @escaping DidConnect) {
        nfcManager.read { manager in
            didBecomeActive?(manager)
        } didDetect: { _, result in
            switch result {
            case .failure(let error):
                Logger.nfctag.error("Failed to read tag : \(error.localizedDescription)")
                didRead?(self.nfcManager, .failure(error))
            case .success:
                guard let payload = try? result.get()?.records.first?.payload,
                      let decoded = try? JSONDecoder().decode(CodableTag<T>.self, from: payload) else {
                    return
                }
                self.pairingKey = decoded.pairingKey ?? ""
                self.wrappedValue = decoded.value
                Logger.nfctag.info("Successfully read tag")
                didRead?(self.nfcManager, .success(decoded))
                self.connectToPeripheral(withPairingKey: self.pairingKey,
                                         withServices: services,
                                         didConnect: didConnect)
            }
        }
    }

    // MARK: - Private functions

    private func connectToPeripheral(withPairingKey pairingKey: String,
                                     withServices services: [CBUUID]?,
                                     didConnect: @escaping DidConnect) {
        peripheralManager.scanForPeripherals { manager, discoveredPeripheral, discoveredPairingKey in
            if pairingKey == discoveredPairingKey {
                self.peripheralManager.stopScan()
                self.peripheralManager.connect(to: discoveredPeripheral, withServices: services) { _, result in
                    switch result {
                    case .failure(let error):
                        Logger.nfctag.error("Failed to connect to a peripheral \(error.localizedDescription)")
                        didConnect(manager, .failure(error))
                    case .success:
                        Logger.nfctag.info("Connected to peripheral \(discoveredPeripheral.name)")
                        didConnect(manager, .success(discoveredPeripheral))
                    }
                }
            }
        }
    }

}

/// - Tag: CodableTag
public struct CodableTag<T: Codable>: Codable {
    var pairingKey: String?
    var value: T?

    init(pairingKey: String, value: T? = nil) {
        self.pairingKey = pairingKey
        self.value = value
    }
}