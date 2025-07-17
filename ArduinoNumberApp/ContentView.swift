//
//  ContentView.swift
//  ArduinoNumberApp
//
//  Created by Gabriel Wang on 7/16/25.
//

import SwiftUI
import CoreBluetooth


// MARK: - Main App View
struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    @State private var showingDebugLog = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Connection Status
                statusCard
                
                // Received Data
                if bleManager.isConnected {
                    dataCard
                }
                
                // Device List
                deviceListCard
                
                // Controls
                controlButtons
                
                Spacer()
            }
            .padding()
            .navigationTitle("Arduino BLE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Debug") {
                        showingDebugLog = true
                    }
                }
            }
            .sheet(isPresented: $showingDebugLog) {
                DebugLogView(debugLog: bleManager.debugLog)
            }
        }
    }
    
    private var statusCard: some View {
        VStack(spacing: 10) {
            HStack {
                Circle()
                    .fill(bleManager.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(bleManager.connectionStatus)
                    .font(.headline)
                
                Spacer()
                
                if bleManager.isConnected && bleManager.rssi != 0 {
                    Text("RSSI: \(bleManager.rssi) dBm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if bleManager.isConnected {
                Text("Connected to Arduino")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var dataCard: some View {
        VStack(spacing: 10) {
            Text("Received Number")
                .font(.headline)
            
            Text("\(bleManager.receivedNumber)")
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var deviceListCard: some View {
        VStack(alignment: .leading) {
            deviceListHeader
            deviceListContent
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var deviceListHeader: some View {
        Text("Discovered Devices")
            .font(.headline)
    }
    
    private var deviceListContent: some View {
        Group {
            if bleManager.discoveredPeripherals.isEmpty {
                emptyDeviceListView
            } else {
                deviceList
            }
        }
    }
    
    private var emptyDeviceListView: some View {
        Text("No devices found")
            .foregroundColor(.secondary)
            .italic()
    }
    
    private var deviceList: some View {
            ForEach(bleManager.discoveredPeripherals, id: \.identifier) { peripheral in
                DeviceRowView(
                    peripheral: peripheral,
                    isConnected: bleManager.isConnected,
                    connectedPeripheralID: bleManager.connectedPeripheralID,
                    onConnect: {
                        bleManager.connect(to: peripheral)
                    }
                )
            }
        }
    private var controlButtons: some View {
        HStack(spacing: 20) {
            scanButton
            
            if bleManager.isConnected {
                disconnectButton
            }
        }
    }
    
    private var scanButton: some View {
        Button(action: {
            if bleManager.isScanning {
                bleManager.stopScanning()
            } else {
                bleManager.startScanning()
            }
        }) {
            HStack {
                Image(systemName: bleManager.isScanning ? "stop.circle" : "magnifyingglass")
                Text(bleManager.isScanning ? "Stop Scan" : "Scan")
            }
            .padding()
            .background(bleManager.isScanning ? Color.red : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
    
    private var disconnectButton: some View {
        Button(action: {
            bleManager.disconnect()
        }) {
            HStack {
                Image(systemName: "xmark.circle")
                Text("Disconnect")
            }
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
}

// MARK: - Device Row View
struct DeviceRowView: View {
    let peripheral: CBPeripheral
    let isConnected: Bool
    let connectedPeripheralID: UUID?
    let onConnect: () -> Void
    
    var body: some View {
        Button(action: onConnect) {
            HStack {
                deviceInfo
                Spacer()
                connectionIndicator
            }
            .padding(.vertical, 5)
        }
        .disabled(isConnected)
    }
    
    private var deviceInfo: some View {
        VStack(alignment: .leading) {
            Text(peripheral.name ?? "Unknown Device")
                .font(.subheadline)
                .foregroundColor(.primary)
            Text(peripheral.identifier.uuidString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var connectionIndicator: some View {
        Group {
            if isConnected && connectedPeripheralID == peripheral.identifier {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
    }
}


