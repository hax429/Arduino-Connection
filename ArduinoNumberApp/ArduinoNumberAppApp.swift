import SwiftUI
import CoreBluetooth

// MARK: - BLE Manager
class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // BLE UUIDs - must match Arduino code
    private let serviceUUID = CBUUID(string: "19B10000-E8F2-537E-4F6C-D104768A1214")
    private let characteristicUUID = CBUUID(string: "19B10001-E8F2-537E-4F6C-D104768A1214")
    
    // BLE objects
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    
    // Published properties for UI
    @Published var isScanning = false
    @Published var isConnected = false
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var receivedNumber: Int = 0
    @Published var connectionStatus = "Disconnected"
    @Published var debugLog: [String] = []
    @Published var rssi: Int = 0
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        addDebugLog("BLE Manager initialized")
    }
    
    // MARK: - Helper Methods
    private func addDebugLog(_ message: String) {
        let timestamp = DateFormatter.timestamp.string(from: Date())
        let logMessage = "\(timestamp): \(message)"
        DispatchQueue.main.async {
            self.debugLog.append(logMessage)
            // Keep only last 50 log entries
            if self.debugLog.count > 50 {
                self.debugLog.removeFirst()
            }
        }
        print(logMessage)
    }
    
    // MARK: - Public Methods
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            addDebugLog("❌ Cannot scan - Bluetooth not powered on")
            return
        }
        
        discoveredPeripherals.removeAll()
        isScanning = true
        addDebugLog("🔍 Starting scan for Arduino devices...")
        
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        addDebugLog("⏹️ Stopped scanning")
    }
    
    func connect(to peripheral: CBPeripheral) {
        self.peripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
        addDebugLog("🔗 Attempting to connect to: \(peripheral.name ?? "Unknown")")
        connectionStatus = "Connecting..."
    }
    
    func disconnect() {
        guard let peripheral = peripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
        addDebugLog("🔌 Disconnecting from device")
    }
    
    func readRSSI() {
        peripheral?.readRSSI()
    }
    
    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            addDebugLog("✅ Bluetooth powered on")
        case .poweredOff:
            addDebugLog("❌ Bluetooth powered off")
        case .unauthorized:
            addDebugLog("❌ Bluetooth unauthorized")
        case .unsupported:
            addDebugLog("❌ Bluetooth unsupported")
        case .resetting:
            addDebugLog("🔄 Bluetooth resetting")
        case .unknown:
            addDebugLog("❓ Bluetooth state unknown")
        @unknown default:
            addDebugLog("❓ Unknown bluetooth state")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        addDebugLog("📱 Discovered: \(peripheral.name ?? "Unknown") - RSSI: \(RSSI)")
        
        if !discoveredPeripherals.contains(peripheral) {
            discoveredPeripherals.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        addDebugLog("✅ Connected to: \(peripheral.name ?? "Unknown")")
        connectionStatus = "Connected"
        isConnected = true
        stopScanning()
        
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        addDebugLog("❌ Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        connectionStatus = "Connection failed"
        isConnected = false
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        addDebugLog("🔌 Disconnected from: \(peripheral.name ?? "Unknown")")
        connectionStatus = "Disconnected"
        isConnected = false
        self.peripheral = nil
        self.characteristic = nil
        rssi = 0
    }
    
    // MARK: - CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            addDebugLog("❌ Service discovery error: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            addDebugLog("❌ No services found")
            return
        }
        
        for service in services {
            addDebugLog("🔍 Found service: \(service.uuid)")
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([characteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            addDebugLog("❌ Characteristic discovery error: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            addDebugLog("❌ No characteristics found")
            return
        }
        
        for characteristic in characteristics {
            addDebugLog("🔍 Found characteristic: \(characteristic.uuid)")
            if characteristic.uuid == characteristicUUID {
                self.characteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic)
                addDebugLog("✅ Subscribed to notifications")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            addDebugLog("❌ Value update error: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else {
            addDebugLog("❌ No data received")
            return
        }
        
        // Convert data to integer (assuming 4-byte integer)
        let number = data.withUnsafeBytes { $0.load(as: Int32.self) }
        
        DispatchQueue.main.async {
            self.receivedNumber = Int(number)
        }
        
        addDebugLog("📥 Received number: \(number)")
        
        // Read RSSI periodically
        peripheral.readRSSI()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let error = error {
            addDebugLog("❌ RSSI read error: \(error.localizedDescription)")
            return
        }
        
        DispatchQueue.main.async {
            self.rssi = RSSI.intValue
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            addDebugLog("❌ Notification state error: \(error.localizedDescription)")
            return
        }
        
        if characteristic.isNotifying {
            addDebugLog("✅ Notifications enabled for characteristic")
        } else {
            addDebugLog("⚠️ Notifications disabled for characteristic")
        }
    }
    
    // Add this to BLEManager class
    var connectedPeripheralID: UUID? {
        return peripheral?.identifier
    }
    
}

// MARK: - Extensions
extension DateFormatter {
    static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}



// MARK: - App Entry Point
@main
struct ArduinoBLEApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
