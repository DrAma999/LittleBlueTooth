//
//  LittleBlueTooth.swift
//  LittleBlueTooth
//
//  Created by Andrea Finollo on 10/06/2020.
//  Copyright © 2020 Andrea Finollo. All rights reserved.
//

import Foundation
import Combine
#if TEST
import CoreBluetoothMock
#else
import CoreBluetooth
#endif

public protocol Readable {
    init(from data: Data) throws
}

public protocol Writable {
    var data: Data {get}
}
/**
`LittleBlueTooth` can control only one peripheral at time. It has an `id` properties to identifiy different instances.
Please note that Apple do not enacourage the use of more `CBCentralManger` instances, due to resurce hits.
 [Link](https://developer.apple.com/forums/thread/20810)
 */
public class LittleBlueTooth: Identifiable {
    
    // MARK: - Public variables
    /// LittleBlueTooth instance identifier
    public let id = UUID()
    
    /// This is usefull when you have auto-reconnection and want to do some task right after a connection.
    /// All other tasks will be delyed until this one ends.
    public var connectionTasks: AnyPublisher<Void, LittleBluetoothError>?
    
    /// Connected peripheral. `nil` if not connected or a connection is not requested
    public var peripheral: Peripheral?
    
    /// Publisher that streams peripheral state  available only when a connection is requested for fine grained control
    public var peripheralStatePublisher: AnyPublisher<PeripheralState, Never> {
        _peripheralStatePublisher.eraseToAnyPublisher()
    }

    /// Publisher that streams `ConnectionEvent`
    public lazy var connectionEventPublisher: AnyPublisher<ConnectionEvent, Never> = { [unowned self] in
        return self.centralProxy.connectionEventPublisher.share().eraseToAnyPublisher()
    }()
    /// Publish name and service changes
    public var changesStatePublisher: AnyPublisher<PeripheralChanges, Never> {
        _peripheralChangesPublisher.eraseToAnyPublisher()
    }
    
    /// Publish all values from `CBCharacteristic` that you are already listening to.
    /// It's up to you to filter them and convert raw data to the `Readable` object.
    /// Better if you make it connectable using the `makeConnectable()` and connect to it only when you are sure that a `Peripheral` is connectd
    public var listenPublisher: AnyPublisher<CBCharacteristic, LittleBluetoothError> {
        return
            ensureBluetoothState()
            .flatMap { [unowned self] _ in
                self.ensurePeripheralConnected()
            }
            .flatMap { [unowned self] _ in
                self.peripheral!.listenPublisher
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private variables
    /// Cancellable operation idendified by a `UUID` key
    private var disposeBag = [UUID : AnyCancellable]()
    /// Scan cancellable operation
    private var scanning: AnyCancellable?
    /// Peripheral state  publisher. It will be created after `Peripheral` instance creation.
    private var peripheralStatePublisherCancellable: Cancellable?
    /// Peripheral changes  publisher. It will be created after `Peripheral` instance creation.
    private var peripheralChangesPublisherCancellable: Cancellable?
    /// Cancellable connection event subscriber.
    private var connectionEventSubscriber: AnyCancellable?
    private var connectionEventSubscriberPeri: AnyCancellable?


    /// Peripheral state connectable publisher. It will be connected after `Peripheral` instance creation.
    private lazy var _peripheralStatePublisher: Publishers.MakeConnectable<AnyPublisher<PeripheralState, Never>> = { [unowned self] in
        let statePublisher =
        Just(())
        .flatMap {
            self.peripheral!.peripheralStatePublisher
        }
        .eraseToAnyPublisher()
        .makeConnectable()
       return statePublisher
    }()

    /// Peripheral changes connectable publisher. It will be connected after `Peripheral` instance creation.
    private lazy var _peripheralChangesPublisher: Publishers.MakeConnectable<AnyPublisher<PeripheralChanges, Never>> = { [unowned self] in
        let changesPublisher =
        Just(())
        .flatMap {
            self.peripheral!.changesPublisher
        }
        .eraseToAnyPublisher()
        .makeConnectable()
        return changesPublisher
    }()
    
    /// Used to inject error to ensure peripheral is connected before any operation, it buffers the last result and throw error if peripheral disconnect for a specific error
    
    var cbCentral: CBCentralManager
    var centralProxy = CBCentralManagerDelegateProxy()
    
    // MARK: - Init
    public init() {
        #if TEST
        self.cbCentral = CBCentralManagerFactory.instance(delegate: self.centralProxy, queue: nil)
        #else
        self.cbCentral = CBCentralManager(delegate: self.centralProxy, queue: nil)
        #endif
        self.connectionEventSubscriber =
        connectionEventPublisher
        // This delay to make able other subscribers to receive notification
        .delay(for: .milliseconds(500), scheduler: DispatchQueue.global())
        .sink { [unowned self] (event) in
            if case ConnectionEvent.disconnected( _, _) = event {
                self.cleanUpForDisconnection()
            }
        }
    }
    
    deinit {
        print("Deinit: \(self)")
        disposeBag.forEach { (key, value) in
            value.cancel()
        }
        scanning?.cancel()
        connectionEventSubscriber?.cancel()
        disposeBag.removeAll()
        guard let peri = peripheral else {
            return
        }
        cbCentral.cancelPeripheralConnection(peri.cbPeripheral)
        
    }

    // MARK: - Listen
    
    /// Returns a multicast publisher once you attached all the subscriber you must call `connect()`
    /// - parameter characteristic: Characteristc you want to be notified.
    /// - parameter valueType: The type of the value you want the raw `Data` be converted
    /// - returns: A multicast publisher that will send out values of the type you choose.
    /// - important: The type of the value must be conform to `Readable`
    public func connectableListenPublisher<T: Readable>(for characteristic: LittleBlueToothCharacteristic, valueType: T.Type, queue: DispatchQueue = DispatchQueue.main) -> AnyPublisher<T, LittleBluetoothError> {
        
           let listen = ensureBluetoothState()
           .subscribe(on: queue)
           .print("ConnectableListenPublisher")
           .flatMap { [unowned self] _ in
               self.ensurePeripheralConnected()
           }
           .flatMap { periph in
               periph.listenPublisher
           }
           .filter { charact -> Bool in
             charact.uuid == characteristic.characteristic
           }
           .tryMap { (characteristic) -> T in
               guard let data = characteristic.value else {
                   throw LittleBluetoothError.emptyData
               }
               return try T.init(from: data)
           }.mapError { (error) -> LittleBluetoothError in
               if let er = error as? LittleBluetoothError {
                   return er
               }
               return .emptyData
           }
           .share()
           .multicast{ PassthroughSubject() }
           .eraseToAnyPublisher()

        return listen

       }
    
       
    /// Returns a shared publisher for listening to a specific characteristic.
    /// - parameter characteristic: Characteristc you want to be notified.
    /// - parameter forType: The type of the value you want the raw `Data` be converted
    /// - returns: A shared publisher that will send out values of the type you choose.
    /// - important: The type of the value must be conform to `Readable`
    public func startListen<T: Readable>(from charact: LittleBlueToothCharacteristic, forType: T.Type, queue: DispatchQueue = DispatchQueue.main) -> AnyPublisher<T, LittleBluetoothError> {
        let lis = ensureBluetoothState()
        .subscribe(on: queue)
        .print("StartListenPublisher")
        .flatMap { [unowned self] _ in
            self.ensurePeripheralConnected()
        }
        .flatMap { (periph) -> AnyPublisher<(CBCharacteristic, Peripheral), LittleBluetoothError> in
            return periph.startListen(from: charact.characteristic, of: charact.service)
                .map { (characteristic) -> (CBCharacteristic, Peripheral) in
                    (characteristic, periph)
            }
            .eraseToAnyPublisher()
        }
        .flatMap { (_ ,periph) in
            periph.listenPublisher
        }
        .filter { characteristic -> Bool in
            charact.characteristic == characteristic.uuid
        }
        .tryMap { (characteristic) -> T in
            guard let data = characteristic.value else {
                throw LittleBluetoothError.emptyData
            }
            return try T.init(from: data)
        }.mapError { (error) -> LittleBluetoothError in
            if let er = error as? LittleBluetoothError {
                return er
            }
            return .emptyData
        }
        .eraseToAnyPublisher()
        return lis
        
    }
    
    /// Returns a  publisher with the `CBCharacteristic` where the notify command has been activated.
    /// After starting the listen command you should subscribe to the `listenPublisher` to be notified.
    /// - parameter characteristic: Characteristc you want to be notified.
    /// - returns: A  publisher with the `CBCharacteristic` where the notify command has been activated.
    /// - important: This publisher only activate the notification on a specific characteristic, it will not send notified values.
    /// After starting the listen command you should subscribe to the `listenPublisher` to be notified.
    public func startListen(from characteristic: LittleBlueToothCharacteristic, queue: DispatchQueue = DispatchQueue.main) -> AnyPublisher<CBCharacteristic, LittleBluetoothError> {
        
        let startListenSubject = PassthroughSubject<CBCharacteristic, LittleBluetoothError>()
        let key = UUID()
        
        self.ensureBluetoothState()
        .subscribe(on: queue)
        .print("StartListenPublisher no Value")
        .flatMap { [unowned self] _ in
            self.ensurePeripheralConnected()
        }
        .flatMap { (periph) -> AnyPublisher<CBCharacteristic, LittleBluetoothError> in
            periph.startListen(from: characteristic.characteristic, of: characteristic.service)
        }
        .sink(receiveCompletion: { [unowned self, key] (completion) in
            switch completion {
            case .finished:
                break
            case .failure(let error):
                startListenSubject.send(completion: .failure(error))
                self.removeAndCancelSubscriber(for: key)
            }
        }) { [unowned self, key] (characteristic) in
            startListenSubject.send(characteristic)
            startListenSubject.send(completion: .finished)
            self.removeAndCancelSubscriber(for: key)
        }
        .store(in: &disposeBag, for: key)
        
        return startListenSubject.eraseToAnyPublisher()
    }
    
    
    /// Stop listen from a specific characteristic
    /// - parameter characteristic: characteristic you want to stop listen
    /// - returns: A publisher with that informs you about the successful or failed task
    public func stopListen(from characteristic: LittleBlueToothCharacteristic, queue: DispatchQueue = DispatchQueue.main) -> AnyPublisher<CBCharacteristic, LittleBluetoothError> {
        return ensureBluetoothState()
        .subscribe(on: queue)
        .flatMap { [unowned self] _ in
            self.ensurePeripheralConnected()
        }
        .flatMap { (periph) -> AnyPublisher<CBCharacteristic, LittleBluetoothError> in
            periph.stopListen(from: characteristic.characteristic, of: characteristic.service)
        }.eraseToAnyPublisher()
    }

    // MARK: - Read
    
    /// Read a value from a specific charteristic
    /// - parameter characteristic: characteristic where you want to read
    /// - returns: A publisher with the value you want to read.
    /// - important: The type of the value must be conform to `Readable`
    public func read<T: Readable>(from characteristic: LittleBlueToothCharacteristic, timeout: TimeInterval? = nil, forType: T.Type, queue: DispatchQueue = DispatchQueue.main) -> AnyPublisher<T, LittleBluetoothError> {
        
        let readSubject = PassthroughSubject<T, LittleBluetoothError>()
        
        let key = UUID()
                
        ensureBluetoothState()
        .subscribe(on: queue)
        .timeout(RunLoop.SchedulerTimeType.Stride(timeout ?? TimeInterval.infinity), scheduler: RunLoop.current, customError: {.readTimeout})
        .print("ReadPublisher")
        .flatMap { [unowned self] _ in
            self.ensurePeripheralConnected()
        }
        .flatMap { periph in
            periph.read(from: characteristic.characteristic, of: characteristic.service)
        }
        .tryMap { (data) -> T in
            guard let data = data else {
                throw LittleBluetoothError.emptyData
            }
            return try T.init(from: data)
        }
        .mapError { (error) -> LittleBluetoothError in
            if let er = error as? LittleBluetoothError {
                return er
            }
            return .couldNotReadFromCharacteristic(characteristic: characteristic.characteristic, error: error)
        }
        .sink(receiveCompletion: { [unowned self, key] (completion) in
            switch completion {
            case .finished:
                break
            case .failure(let error):
                readSubject.send(completion: .failure(error))
                self.removeAndCancelSubscriber(for: key)
            }
        }) { [unowned self, key] (readvalue) in
            readSubject.send(readvalue)
            readSubject.send(completion: .finished)
            self.removeAndCancelSubscriber(for: key)
        }
        .store(in: &disposeBag, for: key)
        
        return readSubject.eraseToAnyPublisher()
    }
    
    
   // MARK: - Write

    /// Write a value to a specific charteristic
    /// - parameter characteristic: characteristic where you want to write
    /// - parameter value: The value you want to write
    /// - parameter response: An optional `Bool` value that will look for error after write operation
    /// - returns: A publisher with that informs you about eventual error
    /// - important: The type of the value must be conform to `Writable`
    public func write<T: Writable>(to characteristic: LittleBlueToothCharacteristic, timeout: TimeInterval? = nil, value: T, response: Bool = true, queue: DispatchQueue = DispatchQueue.main) -> AnyPublisher<Void, LittleBluetoothError> {
        
        let writeSubject = PassthroughSubject<Void, LittleBluetoothError>()
        
        let key = UUID()

        ensureBluetoothState()
        .subscribe(on: queue)
        .timeout(RunLoop.SchedulerTimeType.Stride(timeout ?? TimeInterval.infinity), scheduler: RunLoop.current, customError: {.writeTimeout})
        .print("WritePublisher")
        .flatMap { [unowned self] _ in
            self.ensurePeripheralConnected()
        }
        .flatMap { periph in
            periph.write(to: characteristic.characteristic, of: characteristic.service, data: value.data, response: response)
        }
        .sink(receiveCompletion: { [unowned self, key] (completion) in
            switch completion {
            case .finished:
                break
            case .failure(let error):
                writeSubject.send(completion: .failure(error))
                self.removeAndCancelSubscriber(for: key)
            }
        }, receiveValue: { [unowned self, key] (value) in
            writeSubject.send(())
            writeSubject.send(completion: .finished)
            self.removeAndCancelSubscriber(for: key)
        })
        .store(in: &disposeBag, for: key)
        
        return writeSubject.eraseToAnyPublisher()
    }
    
    
    /// Write a value to a specific charteristic and wait for a response
    /// - parameter characteristic: characteristic where you want to write and listen
    /// - parameter value: The value you want to write must conform to `Writable`
    /// - returns: A publisher with that post and error or the response of the write requests.
    /// - important: Written value must conform to `Writable`, response must conform to `Readable`
    public func writeAndListen<W: Writable, R: Readable>(from characteristic: LittleBlueToothCharacteristic, timeout: TimeInterval? = nil, value: W, queue: DispatchQueue = DispatchQueue.main) -> AnyPublisher<R, LittleBluetoothError> {

        let writeListenSubject = PassthroughSubject<R, LittleBluetoothError>()
        let key = UUID()
        
        ensureBluetoothState()
        .subscribe(on: DispatchQueue.main)
        .timeout(RunLoop.SchedulerTimeType.Stride(timeout ?? TimeInterval.infinity), scheduler: RunLoop.current, customError: {.writeAndListenTimeout})
        .print("WriteAndListePublisher")
        .flatMap { [unowned self] _ in
            self.ensurePeripheralConnected()
        }
        .flatMap { (periph) in
            periph.writeAndListen(from: characteristic.characteristic, of: characteristic.service, data: value.data)
        }
        .tryMap { (data) -> R in
            guard let data = data else {
                throw LittleBluetoothError.emptyData
            }
            return try R(from: data)
        }.mapError { (error) -> LittleBluetoothError in
            if let er = error as? LittleBluetoothError {
                return er
            }
            return .couldNotReadFromCharacteristic(characteristic: characteristic.characteristic, error: error)
        }
        .sink(receiveCompletion: { [unowned self, key] (completion) in
            switch completion {
            case .finished:
                break
            case .failure(let error):
                writeListenSubject.send(completion: .failure(error))
                self.removeAndCancelSubscriber(for: key)
            }
        }) { [unowned self, key] (readvalue) in
            writeListenSubject.send(readvalue)
            writeListenSubject.send(completion: .finished)
            self.removeAndCancelSubscriber(for: key)
        }
        .store(in: &disposeBag, for: key)
        
        return writeListenSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Discover

    /// Starts scanning for `PeripheralDiscovery`
    /// - parameter services: Services for peripheral you are looking for
    /// - parameter options: Scanning options same as  CoreBluetooth  central manager option.
    /// - returns: A publisher with stream of disovered peripherals.
    public func startDiscovery(withServices services: [CBUUID]?, timeout: TimeInterval? = nil, options: [String : Any]? = nil, queue: DispatchQueue = DispatchQueue.main) -> AnyPublisher<PeripheralDiscovery, LittleBluetoothError> {
        if self.cbCentral.isScanning {
            return Result<PeripheralDiscovery, LittleBluetoothError>.Publisher(.failure(.alreadyScanning)).eraseToAnyPublisher()
        }
        
        let scanSubject = PassthroughSubject<PeripheralDiscovery, LittleBluetoothError>()
        
        scanning =
        ensureBluetoothState()
        .subscribe(on: queue)
        .timeout(RunLoop.SchedulerTimeType.Stride(timeout ?? TimeInterval.infinity), scheduler: RunLoop.current, customError: {.scanTimeout})
        .print("DiscoverPublisher")
        .flatMap { [unowned self] _  -> Publishers.SetFailureType<PassthroughSubject<PeripheralDiscovery, Never>, LittleBluetoothError> in
            self.cbCentral.scanForPeripherals(withServices: services, options: options)
            return self.centralProxy.centralDiscoveriesPublisher.setFailureType(to: LittleBluetoothError.self)
        }
        .sink(receiveCompletion: { [unowned self] (completion) in
            switch completion {
            case .finished:
                break
            case .failure(let error):
                scanSubject.send(completion: .failure(error))
                self.cbCentral.stopScan()
                self.scanning?.cancel()
                self.scanning = nil
            }
        }) { (discovery) in
            scanSubject.send(discovery)
        }
        
        return scanSubject.eraseToAnyPublisher()
    }
    
    /// Stops peripheral discovery
    /// - returns: A publisher when discovery has been stopped
    public func stopDiscovery() -> AnyPublisher<Void, LittleBluetoothError> {
        return Deferred {
            Future<Void, LittleBluetoothError> { [unowned self] promise in
                self.cbCentral.stopScan()
                self.scanning?.cancel()
                self.scanning = nil
                promise(.success(()))
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - Connect
    
    /// Starts connection for `PeripheralIdentifier`
    /// - parameter options: Connecting options same as  CoreBluetooth  central manager option.
    /// - returns: A publisher with the just connected `Peripheral`.
    public func connect(to peripheralIdentifier: PeripheralIdentifier, timeout: TimeInterval? = nil, options: [String : Any]? = nil, queue: DispatchQueue = DispatchQueue.main) -> AnyPublisher<Peripheral, LittleBluetoothError> {
        if let periph = peripheral, periph.state == .connecting || periph.state == .connected {
            return Result<Peripheral, LittleBluetoothError>.Publisher(.failure(.peripheralAlreadyConnectedOrConnecting(periph))).eraseToAnyPublisher()
        }
        
        let connectSubject = PassthroughSubject<Peripheral, LittleBluetoothError>()
        let key = UUID()
        
        ensureBluetoothState()
        .subscribe(on: queue)
        .print("ConnectPublisher")
        .timeout(RunLoop.SchedulerTimeType.Stride(timeout ?? TimeInterval.infinity), scheduler: RunLoop.current, customError: {.connectTimeout})
        .tryMap { [unowned self] _ -> Void in
            let filtered = self.cbCentral.retrievePeripherals(withIdentifiers: [peripheralIdentifier.id]).filter { (periph) -> Bool in
                periph.identifier == peripheralIdentifier.id
            }
            if filtered.count == 0 {
                throw LittleBluetoothError.peripheralNotFound
            }
            self.peripheral = Peripheral(filtered.first!)
            self.peripheralStatePublisherCancellable = self._peripheralStatePublisher.connect()
            self.peripheralChangesPublisherCancellable = self._peripheralChangesPublisher.connect()
            self.cbCentral.connect(filtered.first!, options: options)
        }.mapError { error in
            error as! LittleBluetoothError
        }
        .flatMap { [unowned self] _ in
            self.centralProxy.connectionEventPublisher.setFailureType(to: LittleBluetoothError.self)
        }
        .tryMap { [unowned self] (event) -> CBPeripheral in
            switch event {
            case .connected(let periph):
                return periph
            case .connectionFailed(_, let error?):
                self.cbCentral.cancelPeripheralConnection(self.peripheral!.cbPeripheral)
                self.peripheral = nil
                throw error
            case .connectionFailed(let periph, _):
                self.cbCentral.cancelPeripheralConnection(self.peripheral!.cbPeripheral)
                self.peripheral = nil
                throw LittleBluetoothError.couldNotConnectToPeripheral(PeripheralIdentifier(peripheral: periph), nil)
            case .disconnected(_, let error?):
                self.cbCentral.cancelPeripheralConnection(self.peripheral!.cbPeripheral)
                self.peripheral = nil
                throw error
            case .disconnected(let periph, _):
                self.cbCentral.cancelPeripheralConnection(self.peripheral!.cbPeripheral)
                self.peripheral = nil
                throw LittleBluetoothError.peripheralDisconnected(PeripheralIdentifier(peripheral: periph), nil)
            }
        }
        .mapError { (error) -> LittleBluetoothError in
                error as! LittleBluetoothError
        }
        .map { [unowned self] peripheral -> Peripheral in
            return self.peripheral!
        }
        .flatMap { [unowned self] peripheral -> AnyPublisher<Peripheral, LittleBluetoothError> in
            if let connTask = self.connectionTasks {
                return connTask.map {
                    peripheral
                }.eraseToAnyPublisher()
            }
            return Just(peripheral).setFailureType(to: LittleBluetoothError.self).eraseToAnyPublisher()
        }
        .sink(receiveCompletion: { [unowned self, key] (completion) in
            switch completion {
            case .finished:
                break
            case .failure(let error):
                connectSubject.send(completion: .failure(error))
                self.peripheral = nil
                self.removeAndCancelSubscriber(for: key)
            }
        }, receiveValue: { [unowned self, key] (peripheral) in
            connectSubject.send(peripheral)
            connectSubject.send(completion: .finished)
            self.removeAndCancelSubscriber(for: key)
        })
        .store(in: &disposeBag, for: key)
        
        return connectSubject.eraseToAnyPublisher()
    }

    /// Starts connection for `PeripheralDiscovery`
    /// - parameter options: Connecting options same as  CoreBluetooth  central manager option.
    /// - returns: A publisher with the just connected `Peripheral`.
    public func connect(to discovery: PeripheralDiscovery, timeout: TimeInterval? = nil, options: [String : Any]? = nil) -> AnyPublisher<Peripheral, LittleBluetoothError> {
        if cbCentral.isScanning {
            scanning?.cancel()
            scanning = nil
            cbCentral.stopScan()
        }
        let peripheralIdentifier = PeripheralIdentifier(peripheral: discovery.cbPeripheral)
        
        return connect(to: peripheralIdentifier, timeout: timeout, options: options)
    }
    
    // MARK: - Disconnect

    /// Disconnect the connected `Peripheral`
    /// - returns: A publisher with the just disconnected `Peripheral` or a `LittleBluetoothError`
    @discardableResult
    public func disconnect(queue: DispatchQueue = DispatchQueue.main) -> AnyPublisher<Peripheral, LittleBluetoothError> {
        
        guard let periph = self.peripheral else {
            return Result<Peripheral, LittleBluetoothError>.Publisher(.failure(.peripheralNotConnectedOrAlreadyDisconnected)).eraseToAnyPublisher()
        }
        
        let disconnectionSubject = PassthroughSubject<Peripheral, LittleBluetoothError>()
        let key = UUID()
        
        self.centralProxy.connectionEventPublisher
        .subscribe(on: queue)
        .print("DisconnectPublisher")
        .filter{ (event) -> Bool in
            if case ConnectionEvent.disconnected(_, error: _) = event {
                return true
            }
            return false
        }
        .sink { [unowned self, key, periph] (event) in
            if case ConnectionEvent.disconnected( _, let error) = event {
                if error != nil {
                    disconnectionSubject.send(completion: .failure(error!))
                } else {
                    disconnectionSubject.send(periph)
                    disconnectionSubject.send(completion: .finished)
                }
                self.removeAndCancelSubscriber(for: key)
                // Everything is cleaned in the connection event observer
            }
        }
        .store(in: &disposeBag, for: key)
        
        self.cbCentral.cancelPeripheralConnection(peripheral!.cbPeripheral)
        return disconnectionSubject.eraseToAnyPublisher()
    }
    
    
    // MARK: - Private
    private func ensureBluetoothState() -> AnyPublisher<BluetoothState, LittleBluetoothError> {
        let centralState =
            self.centralProxy.centralStatePublisher
            .print("CentralStatePublisher")
            .tryFilter { [unowned self] (state) -> Bool in
                switch state {
                case .poweredOff:
                    if let periph = self.peripheral {
                        let connEvent = ConnectionEvent.disconnected(periph.cbPeripheral, error: .bluetoothPoweredOff)
                        self.centralProxy.connectionEventPublisher.send(connEvent)
                    }
                    throw LittleBluetoothError.bluetoothPoweredOff
                case .unauthorized:
                    throw LittleBluetoothError.bluetoothUnauthorized
                case .unsupported:
                    throw LittleBluetoothError.bluetoothUnsupported
                case .unknown, .resetting:
                    return false
                case .poweredOn:
                    return true
                }
            }
            .mapError { (error) -> LittleBluetoothError in
                error as! LittleBluetoothError
            }
            .map { state -> BluetoothState in
                print("CBManager state: \(state)")
                return state
            }
            
        .eraseToAnyPublisher()

        return centralState
    }
   
    private func ensurePeripheralConnected() -> AnyPublisher<Peripheral, LittleBluetoothError> {
        guard let periph = peripheral, periph.state == .connected else {
            let state = peripheral?.state
            return Result<Peripheral, LittleBluetoothError>.Publisher(.failure(.peripheralNotConnected(state: state ?? .disconnected))).eraseToAnyPublisher()
        }
        return self.centralProxy.connectionEventPublisher
        .print("EnsurePeripheralConnectedPublisher")
        .tryMap { [unowned self] (event) -> Peripheral in
            switch event {
            case .disconnected(_, let error?):
                throw error
            case .disconnected(let periph, _):
                throw LittleBluetoothError.peripheralDisconnected(PeripheralIdentifier(peripheral: periph), nil)
            default:
                return self.peripheral!
            }
        }
        .mapError { (error) -> LittleBluetoothError in
            error as! LittleBluetoothError
        }
        .merge(with: Just(periph).setFailureType(to: LittleBluetoothError.self))

        .eraseToAnyPublisher()
    }
    
    private func removeAndCancelSubscriber(for key: UUID) {
        let sub = disposeBag[key]
        disposeBag.removeValue(forKey: key)
        sub?.cancel()
    }
    
    private func cleanUpForDisconnection() {
        self.peripheralStatePublisherCancellable?.cancel()
        self.peripheralStatePublisherCancellable = nil
        self.peripheralChangesPublisherCancellable?.cancel()
        self.peripheralChangesPublisherCancellable = nil
        self.peripheral = nil
    }

}

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
