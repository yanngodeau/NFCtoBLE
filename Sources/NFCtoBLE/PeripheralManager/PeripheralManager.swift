//
//  BLEManager.swift
//  NFCtoBLE
//
//  Created by Yann Godeau on 12/03/2021.
//

import CoreBluetooth
import OSLog

/// A typealias for the connected peripheral handler
/// - Parameter manager: The peripheral manager.
/// - Parameter peripheral: The connected peripheral on success or an error on failure.
public typealias DidConnect = (_ manager: PeripheralManager, _ peripheral: Result<Peripheral?, Error>) -> Void

/// A typealias for the discovered peripheral handler.
/// - Parameter manager: The peripheral manager.
/// - Parameter peripheral: The discovered peripheral.
/// - Parameter withPairingKey: The pairing key advertised by the peripheral.
public typealias DidDiscoverPeripheral = (_ manager: PeripheralManager,
                                          _ peripheral: Peripheral,
                                          _ withPairingKey: String?) -> Void

/// An object that scans, discovers, connects to, and manages peripherals
public class PeripheralManager: NSObject {
    /// The central manager used by the peripheral manager.
    public private(set) var centralManager: CBCentralManager?
    /// A handler that the peripheral manager invokes when it connects to a peripheral or when errors occur.
    private var didConnect: DidConnect?
    /// A handler that the peripheral manager invokes when it discovers a peripheral or when errors occur.
    private var didDiscoverPeripheral: DidDiscoverPeripheral?
    /// The discovered peripherals.
    private var peripherals: [Peripheral]
    /// The latest connected peripheral.
    var latestActivePeripheral: Peripheral?
    /// The [state](x-source-tag://PeripheralManagerState) of the peripheral manager.
    var state: PeripheralManagerState {
        didSet {
            Logger.peripheralManager.info("""
                State changed from '\(oldValue.localizedState)' to '\(self.state.localizedState)'
                """)
        }
    }
    public static var shared = PeripheralManager()

    public override init() {
        self.peripherals    = [Peripheral]()
        self.state          = .unavailable
        super.init()

        self.centralManager = CBCentralManager(delegate: self,
                                               queue: nil,
                                               options: [CBCentralManagerOptionShowPowerAlertKey:
                                                            NSNumber(value: true)])
        if centralManager!.state == .poweredOn {
            self.state = .ready
        }
    }

    // MARK: - Scanning and connection

    /// Scans for peripherals and handle the discovery.
    /// - Parameter services: The  services intended to be used.
    /// - Parameter didDiscoverPeripheral: The action to perform when the manager has discovered a peripheral.
    public func scanForPeripherals(withServices services: [CBUUID]? = nil,
                                   didDiscoverPeripheral: @escaping DidDiscoverPeripheral) {
        if self.state == .ready {
            Logger.peripheralManager.info("Start scanning")
            self.didDiscoverPeripheral = didDiscoverPeripheral
            self.state = .scanning
            centralManager!.scanForPeripherals(withServices: services,
                                               options: [CBCentralManagerScanOptionAllowDuplicatesKey:
                                                            NSNumber(value: false)])
        }
    }

    /// Asks the peripheral manager to stop scanning for peripherals.
    public func stopScan() {
        if self.state == .scanning {
            Logger.peripheralManager.info("Stop scanning")
            centralManager!.stopScan()
        }
    }

    /// Connects to a peripheral.
    /// - Parameter peripheral: The peripheral to connect to.
    /// - Parameter services: The  services intended to be used.
    /// - Parameter didConnect: The action to perform when the manager has connected to a peripheral.
    public func connect(to peripheral: Peripheral, withServices services: [CBUUID]?, didConnect: @escaping DidConnect) {
        if !peripherals.contains(peripheral) {
            peripherals.append(peripheral)
        }
        if peripheral.state != .connected {
            Logger.peripheralManager.info("Connecting to \(peripheral.name)")
            guard let index = peripherals.firstIndex(of: peripheral) else { return }
            peripherals[index].state = .connecting
            if services != nil {
                peripherals[index].knownServices = services
            }
            self.didConnect = didConnect
            centralManager!.connect(peripheral.cbPeripheral, options: nil)
        } else {
            Logger.peripheralManager.info("""
                Tried to connect to \(peripheral.name), but the peripheral is already connected
                """)
            didConnect(self, .success(peripheral))
        }
    }

    /// Asks the peripheral manager to disconnect from a peripheral.
    /// - Parameter peripheral: The peripheral to disconnect
    public func disconnect(from peripheral: Peripheral) {
        Logger.peripheralManager.info("Disconnecting from \(peripheral.name)")
        peripheral.state = .disconnecting
        centralManager!.cancelPeripheralConnection(peripheral.cbPeripheral)
    }

    /// Handles the reception of a value from the connected peripheral.
    /// - Parameter didUpdateValue: The action to perform when a value is received.
    public func peripheral(didUpdateValue: @escaping DidUpdateValue) {
        latestActivePeripheral?.onValueUpdated(didUpdateValue)
    }
}

// MARK: - CBCentralManagerDelegate
extension PeripheralManager: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if  central.state == .poweredOn {
            self.state = .ready
        } else {
            self.state = .unavailable
        }
    }

    public func centralManager(_ central: CBCentralManager,
                               didDiscover peripheral: CBPeripheral,
                               advertisementData: [String: Any],
                               rssi RSSI: NSNumber) {

        let discoveredPeripheral = Peripheral(with: peripheral)
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            let data = Data(manufacturerData)
            let pairingKey = String(data: data, encoding: .utf8)
            Logger.peripheralManager.debug("""
                Discovered peripheral: \(peripheral.name ?? "unknow")
                with pairing key '\(String(describing: pairingKey?.debugDescription))'
                """)
            self.peripherals.append(discoveredPeripheral)
            didDiscoverPeripheral?(self, discoveredPeripheral, pairingKey)
        }

    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.latestActivePeripheral = peripherals.first { $0.cbPeripheral == peripheral }
        Logger.peripheralManager.info("Connected to \(self.latestActivePeripheral!.name) !")
        self.latestActivePeripheral!.state = .connected
        self.didConnect?(self, .success(latestActivePeripheral))
        self.latestActivePeripheral!.cbPeripheral.discoverServices(latestActivePeripheral!.knownServices)
    }

    public func centralManager(_ central: CBCentralManager,
                               didDisconnectPeripheral peripheral: CBPeripheral,
                               error: Error?) {
        if self.latestActivePeripheral?.cbPeripheral != peripheral {
            Logger.peripheralManager.error("""
                Disconnected from a device that was not the lastest one known as connected.
                """)
        } else {
            Logger.peripheralManager.info("""
                Disconnected from peripheral \(String(describing: peripheral.name))
                | error: \(error.debugDescription)
                """)
            self.latestActivePeripheral?.state = .disconnected
        }
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Logger.peripheralManager.error("""
            Failed to connect peripheral \(String(describing: peripheral))
            | error: \(error.debugDescription)
            """)
        self.latestActivePeripheral = Peripheral(with: peripheral)
        self.latestActivePeripheral?.state = .failedToConnect
        self.didConnect?(self, .failure(error!))
    }

}
