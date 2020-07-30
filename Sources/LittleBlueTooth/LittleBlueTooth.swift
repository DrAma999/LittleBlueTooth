//
//  LittleBlueTooth.swift
//  LittleBlueTooth
//
//  Created by Andrea Finollo on 10/06/2020.
//  Copyright © 2020 Andrea Finollo. All rights reserved.
//

import Foundation
import Combine
import os.log
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
    /// All other tasks will be delayed until this one ends.
    public var connectionTasks: AnyPublisher<Void, LittleBluetoothError>?
    
    /// This handler must be used to handle connection process after a disconnession.
    /// You can inspect the error and decide if an automatic connection is necessary.
    /// If you return `true` the connection process will start, once the peripheral has been found a connection will be established.
    /// If you return `false` iOS will not try to establish a connection
    /// Connection process will remain active also in background if the app has the right
    /// permission, to cancel just call `disconnect`.
    /// When a connection will be established an `.autoConnected(PeripheralIdentifier)` event will be streamed to
    /// the `connectionEventPublisher`
    public var autoconnectionHandler: AutoconnectionHandler?
    
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
    
    /// Publish all values from `LittleBlueToothCharacteristic` that you are already listening to.
    /// It's up to you to filter them and convert raw data to the `Readable` object.
    public var listenPublisher: AnyPublisher<LittleBlueToothCharacteristic, LittleBluetoothError> {
        return _listenPublisher
            .map { (characteristic) -> LittleBlueToothCharacteristic in
                LittleBlueToothCharacteristic(with: characteristic)
            }
            .eraseToAnyPublisher()
    }
    
    public var restoreStatePublisher: AnyPublisher<CentralRestorer, Never> {
        return centralProxy.willRestoreStatePublisher
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
    /// Notification  publisher. It will be created after `Peripheral` instance creation.
    private var listenPublisherCancellable: Cancellable?
    /// Cancellable connection event subscriber.
    private var connectionEventSubscriber: AnyCancellable?
    private var connectionEventSubscriberPeri: AnyCancellable?

    private lazy var _listenPublisher: Publishers.Multicast<AnyPublisher<CBCharacteristic, LittleBluetoothError>, PassthroughSubject<CBCharacteristic, LittleBluetoothError>>
        = {  [unowned self] in
            let pub =
                ensureBluetoothState()
                .flatMap { [unowned self] _ in
                    self.ensurePeripheralReady()
                }
                .flatMap { [unowned self] _ in
                    self.peripheral!.listenPublisher
                }
                .share()
                .eraseToAnyPublisher()
            return Publishers.Multicast(upstream: pub, createSubject:{ PassthroughSubject() })
    }()
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
    
    private var restoreStateCancellable: AnyCancellable?
    
    /// Used to inject error to ensure peripheral is connected before any operation, it buffers the last result and throw error if peripheral disconnect for a specific error
    
    var cbCentral: CBCentralManager
    var centralProxy = CBCentralManagerDelegateProxy()
    
    // MARK: - Init
    public init(with configuration: LittleBluetoothConfiguration) {
        #if TEST
        self.cbCentral = CBCentralManagerFactory.instance(delegate: self.centralProxy, queue: configuration.centralManagerQueue, options: configuration.centralManagerOptions, forceMock: true)
        #else
        self.cbCentral = CBCentralManager(delegate: self.centralProxy, queue: configuration.centralManagerQueue, options: configuration.centralManagerOptions)
        #endif
        self.autoconnectionHandler = configuration.autoconnectionHandler
        if (configuration.restoreHandler == nil &&
            configuration.centralManagerOptions?[CBCentralManagerOptionRestoreIdentifierKey] != nil) ||
            (configuration.restoreHandler != nil &&
                configuration.centralManagerOptions?[CBCentralManagerOptionRestoreIdentifierKey] == nil) {
            print("If you want to use state preservation/restoration you should probablu want to implement the `restoreHandler`")
        }
        attachSubscribers(with: configuration.restoreHandler)
//        os_log(
//            "LBT init options %{public}@",
//            log: OSLog.LittleBT_Log_General,
//            type: .debug,
//            configuration.centralManagerOptions?.description ?? ""
//        )
    }
    
    func attachSubscribers(with restorehandler: ((Restored) -> Void)?) {
        self.connectionEventSubscriber =
            connectionEventPublisher
            .flatMap { [unowned self] (event) -> AnyPublisher<ConnectionEvent, Never> in
                print("Received event \(event)")
                switch event {
                case .connected(let periph),
                     .autoConnected(let periph):
                    self.listenPublisherCancellable = self._listenPublisher.connect()

                    if let connTask = self.connectionTasks {
                        // I'm doing a copy of the connectionTask so if something fails
                        // next time it will start over.
                        // TEMPORARY WORKAROUND: Those Dispatch async will make the states flow correctly in the process: first connect, then ready. Without it would be the contrary
                        return AnyPublisher(connTask)
                            .catch { [unowned self] (error) -> Just<Void> in
                                DispatchQueue.main.async {
                                    self.centralProxy.connectionEventPublisher.send(ConnectionEvent.notReady(periph, error: error))
                                }
                                return Just(())
                        }
                        .map { _ in
                            DispatchQueue.main.async {
                                self.centralProxy.connectionEventPublisher.send(ConnectionEvent.ready(periph))
                            }
                            return event
                        }
                        .eraseToAnyPublisher()
                    } else {
                        DispatchQueue.main.async {
                            self.centralProxy.connectionEventPublisher.send(ConnectionEvent.ready(periph))
                        }
                        return Just(event).eraseToAnyPublisher()
                    }
                default:
                    return Just(event).eraseToAnyPublisher()
                }
            }
                // This delay to make able other subscribers to receive notification
            .delay(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [unowned self] (event) in
                print("Sinking event \(event)")
                if case ConnectionEvent.disconnected( let peripheral, let error) = event {
                    self.cleanUpForDisconnection()
                    if let autoCon = self.autoconnectionHandler {
                        let periph = PeripheralIdentifier(peripheral: peripheral)
                        if autoCon(periph, error) == true {
                            _ = self.connect(to: periph, autoreconnect: true)
                        }
                    }
            }
        }
        if let handler = restorehandler {
            self.restoreStateCancellable = centralProxy.willRestoreStatePublisher
            .map { [unowned self] (restorer) -> Restored in
                let restored = self.restore(restorer)
                return restored
            }
            .sink(receiveValue: { (restored) in
                handler(restored)
            })
        }
    }
    
    deinit {
        print("Deinit: \(self)")
        disposeBag.forEach { (_, value) in
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
    public func connectableListenPublisher<T: Readable>(for characteristic: LittleBlueToothCharacteristic, valueType: T.Type, queue: DispatchQueue = DispatchQueue.main) -> Publishers.Multicast<AnyPublisher<T, LittleBluetoothError>, PassthroughSubject<T, LittleBluetoothError>> {
        
           let listen = ensureBluetoothState()
           .print("ConnectableListenPublisher")
           .flatMap { [unowned self] _ in
               self.ensurePeripheralReady()
           }
           .flatMap { (periph) -> AnyPublisher<(CBCharacteristic, Peripheral), LittleBluetoothError> in
               return periph.startListen(from: characteristic.id, of: characteristic.service)
                   .map { (characteristic) -> (CBCharacteristic, Peripheral) in
                       (characteristic, periph)
               }
               .eraseToAnyPublisher()
           }
           .flatMap { (_ ,periph) in
               periph.listenPublisher
           }
           .filter { charact -> Bool in
             charact.uuid == characteristic.id
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
           .eraseToAnyPublisher()
        return Publishers.Multicast(upstream: listen, createSubject:{ PassthroughSubject() })
       }
    
       
    /// Returns a shared publisher for listening to a specific characteristic.
    /// - parameter characteristic: Characteristc you want to be notified.
    /// - parameter forType: The type of the value you want the raw `Data` be converted
    /// - returns: A shared publisher that will send out values of the type you choose.
    /// - important: The type of the value must be conform to `Readable`
    public func startListen<T: Readable>(from charact: LittleBlueToothCharacteristic, queue: DispatchQueue = DispatchQueue.main) -> AnyPublisher<T, LittleBluetoothError> {
        let lis = ensureBluetoothState()
        .print("StartListenPublisher")
        .flatMap { [unowned self] _ in
            self.ensurePeripheralReady()
        }
        .flatMap { (periph) -> AnyPublisher<(LittleBlueToothCharacteristic, Peripheral), LittleBluetoothError> in
            return periph.startListen(from: charact.id, of: charact.service)
                .map { (characteristic) -> (LittleBlueToothCharacteristic, Peripheral) in
                    (LittleBlueToothCharacteristic(with: characteristic), periph)
            }
            .eraseToAnyPublisher()
        }
        .flatMap { (_ ,periph) in
            periph.listenPublisher
        }
        .filter { characteristic -> Bool in
            charact.id == characteristic.uuid
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
    
    /// Returns a  publisher with the `LittleBlueToothCharacteristic` where the notify command has been activated.
    /// After starting the listen command you should subscribe to the `listenPublisher` to be notified.
    /// - parameter characteristic: Characteristc you want to be notified.
    /// - returns: A  publisher with the `LittleBlueToothCharacteristic` where the notify command has been activated.
    /// - important: This publisher only activate the notification on a specific characteristic, it will not send notified values.
    /// After starting the listen command you should subscribe to the `listenPublisher` to be notified.
    public func startListen(from characteristic: LittleBlueToothCharacteristic, queue: DispatchQueue = DispatchQueue.main) -> AnyPublisher<LittleBlueToothCharacteristic, LittleBluetoothError> {
        
        let startListenSubject = PassthroughSubject<LittleBlueToothCharacteristic, LittleBluetoothError>()
        let key = UUID()
        
        self.ensureBluetoothState()
        .print("StartListenPublisher no Value")
        .flatMap { [unowned self] _ in
            self.ensurePeripheralReady()
        }
        .flatMap { (periph) -> AnyPublisher<CBCharacteristic, LittleBluetoothError> in
            periph.startListen(from: characteristic.id, of: characteristic.service)
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
            startListenSubject.send(LittleBlueToothCharacteristic(with: characteristic))
            startListenSubject.send(completion: .finished)
            self.removeAndCancelSubscriber(for: key)
        }
        .store(in: &disposeBag, for: key)
        
        return startListenSubject.eraseToAnyPublisher()
    }
    
    
    /// Stop listen from a specific characteristic
    /// - parameter characteristic: characteristic you want to stop listen
    /// - returns: A publisher with that informs you about the successful or failed task
    public func stopListen(from characteristic: LittleBlueToothCharacteristic, queue: DispatchQueue = DispatchQueue.main) -> AnyPublisher<LittleBlueToothCharacteristic, LittleBluetoothError> {
        
        let stopSubject = PassthroughSubject<LittleBlueToothCharacteristic, LittleBluetoothError>()
        
        let key = UUID()
        ensureBluetoothState()
        .flatMap { [unowned self] _ in
            self.ensurePeripheralReady()
        }
        .flatMap { (periph) -> AnyPublisher<CBCharacteristic, LittleBluetoothError> in
            periph.stopListen(from: characteristic.id, of: characteristic.service)
        }
        .sink(receiveCompletion: { [unowned self, key] (completion) in
            switch completion {
            case .finished:
                break
            case .failure(let error):
                stopSubject.send(completion: .failure(error))
                self.removeAndCancelSubscriber(for: key)
            }
        }) { [unowned self, key] (readvalue) in
            stopSubject.send(LittleBlueToothCharacteristic(with:readvalue))
            stopSubject.send(completion: .finished)
            self.removeAndCancelSubscriber(for: key)
        }
        .store(in: &disposeBag, for: key)
        
        return stopSubject.eraseToAnyPublisher()
    }

    // MARK: - Read
    
    /// Read a value from a specific charteristic
    /// - parameter characteristic: characteristic where you want to read
    /// - returns: A publisher with the value you want to read.
    /// - important: The type of the value must be conform to `Readable`
    public func read<T: Readable>(from characteristic: LittleBlueToothCharacteristic, timeout: TimeInterval? = nil, queue: DispatchQueue = DispatchQueue.main) -> AnyPublisher<T, LittleBluetoothError> {
        
        let readSubject = PassthroughSubject<T, LittleBluetoothError>()
        let key = UUID()
        let timeout: DispatchTimeInterval = (timeout != nil) ? timeout!.dispatchInterval : .never
        
        ensureBluetoothState()
        .print("ReadPublisher")
        .flatMap { [unowned self] _ in
            self.ensurePeripheralReady()
        }
        .flatMap { periph in
            periph.read(from: characteristic.id, of: characteristic.service)
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
            return .couldNotReadFromCharacteristic(characteristic: characteristic.id, error: error)
        }
        .timeout(DispatchQueue.SchedulerTimeType.Stride(timeout), scheduler: DispatchQueue.main, customError: {.readTimeout})
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
        let timeout: DispatchTimeInterval = (timeout != nil) ? timeout!.dispatchInterval : .never

        ensureBluetoothState()
        .print("WritePublisher")
        .flatMap { [unowned self] _ in
            self.ensurePeripheralReady()
        }
        .flatMap { periph in
            periph.write(to: characteristic.id, of: characteristic.service, data: value.data, response: response)
        }
        .timeout(DispatchQueue.SchedulerTimeType.Stride(timeout), scheduler: DispatchQueue.main, customError: {.writeTimeout})
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
        let timeout: DispatchTimeInterval = (timeout != nil) ? timeout!.dispatchInterval : .never

        ensureBluetoothState()
        .print("WriteAndListePublisher")
        .flatMap { [unowned self] _ in
            self.ensurePeripheralReady()
        }
        .flatMap { (periph) in
            periph.writeAndListen(from: characteristic.id, of: characteristic.service, data: value.data)
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
            return .couldNotReadFromCharacteristic(characteristic: characteristic.id, error: error)
        }
        .timeout(DispatchQueue.SchedulerTimeType.Stride(timeout), scheduler: DispatchQueue.main, customError: {.writeAndListenTimeout})
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
            self.cbCentral.stopScan()
//            return Result<PeripheralDiscovery, LittleBluetoothError>.Publisher(.failure(.alreadyScanning)).eraseToAnyPublisher()
        }
        
        let scanSubject = PassthroughSubject<PeripheralDiscovery, LittleBluetoothError>()
        let timeout: DispatchTimeInterval = (timeout != nil) ? timeout!.dispatchInterval : .never

        scanning =
        ensureBluetoothState()
        .print("DiscoverPublisher")
        .map { [unowned self] _  -> Void in
            if self.cbCentral.isScanning {
                self.cbCentral.stopScan()
            }
            return ()
        }
        .flatMap { [unowned self] _  -> Publishers.SetFailureType<PassthroughSubject<PeripheralDiscovery, Never>, LittleBluetoothError> in
            self.cbCentral.scanForPeripherals(withServices: services, options: options)
            return self.centralProxy.centralDiscoveriesPublisher.setFailureType(to: LittleBluetoothError.self)
        }
        .timeout(DispatchQueue.SchedulerTimeType.Stride(timeout), scheduler: DispatchQueue.main, customError: {.scanTimeout})
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
    private func connect(to peripheralIdentifier: PeripheralIdentifier, timeout: TimeInterval? = nil, options: [String : Any]? = nil, queue: DispatchQueue = DispatchQueue.main) -> AnyPublisher<Peripheral, LittleBluetoothError> {
        return connect(to: peripheralIdentifier, options: options, queue: queue, autoreconnect: false)
    }
    
    private func connect(to peripheralIdentifier: PeripheralIdentifier, timeout: TimeInterval? = nil, options: [String : Any]? = nil, queue: DispatchQueue = DispatchQueue.main, autoreconnect: Bool) -> AnyPublisher<Peripheral, LittleBluetoothError> {
        if let periph = peripheral, periph.state == .connecting || periph.state == .connected {
            return Result<Peripheral, LittleBluetoothError>.Publisher(.failure(.peripheralAlreadyConnectedOrConnecting(periph))).eraseToAnyPublisher()
        }
        
        let connectSubject = PassthroughSubject<Peripheral, LittleBluetoothError>()
        let key = UUID()
        let timeout: DispatchTimeInterval = (timeout != nil) ? timeout!.dispatchInterval : .never
        
        ensureBluetoothState()
        .print("ConnectPublisher")
        .tryMap { [unowned self] _ -> Void in
            let filtered = self.cbCentral.retrievePeripherals(withIdentifiers: [peripheralIdentifier.id]).filter { (periph) -> Bool in
                periph.identifier == peripheralIdentifier.id
            }
            if filtered.isEmpty {
                throw LittleBluetoothError.peripheralNotFound
            }
            self.peripheral = Peripheral(filtered.first!)
            self.peripheralStatePublisherCancellable = self._peripheralStatePublisher.connect()
            self.peripheralChangesPublisherCancellable = self._peripheralChangesPublisher.connect()
            self.centralProxy.isAutoconnectionActive = autoreconnect
            self.cbCentral.connect(filtered.first!, options: options)
        }.mapError { error in
            error as! LittleBluetoothError
        }
        .flatMap { [unowned self] _ in
            self.centralProxy.connectionEventPublisher.setFailureType(to: LittleBluetoothError.self)
        }
        .filter{ (event) -> Bool in
            print("Connct to event: \(event)")
            switch event {
                case .connected( _),
                     .autoConnected( _):
               return false
            default:
                return true
            }
        }
        .prefix(1)
        .tryMap { [unowned self] (event) -> CBPeripheral in
            switch event {
            case .ready(let periph):
                return periph
            case .notReady(_, let error?):
                self.cbCentral.cancelPeripheralConnection(self.peripheral!.cbPeripheral)
                self.peripheral = nil
                throw error
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
            default:
                fatalError("Connection event not handled")
            }
        }
        .mapError { (error) -> LittleBluetoothError in
                error as! LittleBluetoothError
        }
        .map { [unowned self] peripheral -> Peripheral in
            return self.peripheral!
        }
        .timeout(DispatchQueue.SchedulerTimeType.Stride(timeout), scheduler: DispatchQueue.main, customError: {.connectTimeout})
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
    private func restore(_ restorer: CentralRestorer) -> Restored {
          // Restore scan if scanning
          if restorer.centralManager.isScanning {
              let restoreDiscoverServices = restorer.services
              let restoreScanOptions = restorer.scanOptions
              let restoreDiscoveryPublisher = self.startDiscovery(withServices: restoreDiscoverServices, options: restoreScanOptions)
//            os_log("LBT Scan restore %{public}@", log: OSLog.LittleBT_Log_General, type: .debug, restorer.centralManager.isScanning ? "true" : "false")
              return .scan(discoveryPublisher: restoreDiscoveryPublisher)
          }
          if let periph = restorer.peripherals.first, let cbPeripheral = periph.cbPeripheral {
              self.peripheral = Peripheral(cbPeripheral)
              switch cbPeripheral.state {
              case .connected:
                  // If autoconnection was made in background I should receive a callback from connect and the connection state publisher should take care of putting the peripheral in ready. But probably I must connect other connectable
                  self.peripheralChangesPublisherCancellable = self._peripheralChangesPublisher.connect()
                  self.peripheralStatePublisherCancellable = self._peripheralStatePublisher.connect()
                  print("Peripheral already connected")
              case .connecting:
                  // If autoconnection was made in background I should receive a callback from connect and the connection state publisher should take care of putting the peripheral in ready. But probably I must connect other connectable
                  self.peripheralChangesPublisherCancellable = self._peripheralChangesPublisher.connect()
                  self.peripheralStatePublisherCancellable = self._peripheralStatePublisher.connect()
                  print("Peripheral connecting")
              case .disconnected:
                  // A disconnetion event will be sent to the connection event publisher
                  // If a reconection handler is set it will dispatch a new connection
                  self.peripheralStatePublisherCancellable = self._peripheralStatePublisher.connect()
                  print("Peripheral disconnected")
              case .disconnecting:
                  // A disconnetion event will be sent to the connection event publisher
                  // If a reconection handler is set it will dispatch a new connection
                  self.peripheralStatePublisherCancellable = self._peripheralStatePublisher.connect()

                  print("Peripheral disconnecting")
              @unknown default:
                  fatalError("Connection event in default not handled")
              }
//            #if !TEST
//              os_log("LBT Periph restore %{public}@, has delegate: %{public}@ state %{public}d", log: OSLog.LittleBT_Log_General, type: .debug, cbPeripheral.description, cbPeripheral.delegate != nil ? "true" : "false", cbPeripheral.state.rawValue)
//            #endif
              return Restored.peripheral(self.peripheral!)
          }
          return Restored.nothing
      }
    
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
   
    private func ensurePeripheralReady() -> AnyPublisher<Peripheral, LittleBluetoothError> {
        guard let periph = peripheral, periph.state == .connected else {
            let state = peripheral?.state
            return Result<Peripheral, LittleBluetoothError>.Publisher(.failure(.peripheralNotConnected(state: state ?? .disconnected))).eraseToAnyPublisher()
        }
        return self.centralProxy.connectionEventPublisher
        .print("EnsurePeripheralReadyPublisher")
        .tryFilter { (event) -> Bool in
            switch event {
            case .disconnected(_, let error?):
                throw error
            case .disconnected(let periph, _):
                throw LittleBluetoothError.peripheralDisconnected(PeripheralIdentifier(peripheral: periph), nil)
            case .autoConnected(_),
                 .connected(_),
                 .connectionFailed(_, _),
                 .notReady(_, _):
                return false
            case .ready(_):
                return true
            }
        }
        .map { [unowned self] (_) -> Peripheral in
            return self.peripheral!
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
        self.listenPublisherCancellable?.cancel()
        self.listenPublisherCancellable = nil
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

extension TimeInterval {
    var dispatchInterval: DispatchTimeInterval {
        let microseconds = Int64(self * TimeInterval(USEC_PER_SEC)) // perhaps use nanoseconds, though would more often be > Int.max
        return microseconds < Int.max ? DispatchTimeInterval.microseconds(Int(microseconds)) : DispatchTimeInterval.seconds(Int(self))
    }
}

extension OSLog {
    public static var Subsystem = Bundle.main.bundleIdentifier!
    public static var General = "LittleBluetooth"

    public static let LittleBT_Log_General = OSLog(subsystem: Subsystem, category: General)

}
