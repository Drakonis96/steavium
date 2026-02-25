import Foundation
import GameController
import IOKit.hid

@MainActor
final class GamepadMonitor {
    private let onUpdate: ([GamepadDeviceInfo]) -> Void
    private let pollingInterval: TimeInterval = 4.0
    private let hidRefreshInterval: TimeInterval = 15.0
    private var observers: [NSObjectProtocol] = []
    private var pollingTimer: Timer?
    private var lastHIDRefresh: Date = .distantPast
    private var cachedHIDDevices: [GamepadDeviceInfo] = []

    init(onUpdate: @escaping ([GamepadDeviceInfo]) -> Void) {
        self.onUpdate = onUpdate
    }

    func start() {
        guard observers.isEmpty else { return }

        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: .GCControllerDidConnect,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshNow(forceHIDRefresh: true)
                }
            }
        )
        observers.append(
            center.addObserver(
                forName: .GCControllerDidDisconnect,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshNow(forceHIDRefresh: true)
                }
            }
        )

        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshNow(forceHIDRefresh: false)
            }
        }

        refreshNow(forceHIDRefresh: true)
    }

    func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil

        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
        cachedHIDDevices = []
        lastHIDRefresh = .distantPast
    }

    func refreshNow(forceHIDRefresh: Bool = true) {
        onUpdate(collectGamepads(forceHIDRefresh: forceHIDRefresh))
    }

    private func collectGamepads(forceHIDRefresh: Bool) -> [GamepadDeviceInfo] {
        let controllerDevices = GCController.controllers().map { controller -> GamepadDeviceInfo in
            let primaryName = controller.vendorName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let category = controller.productCategory.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = if let primaryName, !primaryName.isEmpty {
                primaryName
            } else if !category.isEmpty {
                category
            } else {
                "Control compatible"
            }

            let identifier = "gc:\(displayName.lowercased()):\(ObjectIdentifier(controller).hashValue)"
            return GamepadDeviceInfo(
                id: identifier,
                name: displayName,
                source: .gameController,
                vendorID: nil,
                productID: nil
            )
        }

        var combined = controllerDevices
        let knownNames = Set(controllerDevices.map { normalizeName($0.name) })
        let shouldRefreshHID = forceHIDRefresh ||
            Date().timeIntervalSince(lastHIDRefresh) >= hidRefreshInterval
        if shouldRefreshHID {
            cachedHIDDevices = collectHIDGamepads()
            lastHIDRefresh = Date()
        }
        for hidDevice in cachedHIDDevices {
            if knownNames.contains(normalizeName(hidDevice.name)) {
                continue
            }
            combined.append(hidDevice)
        }

        combined.sort { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return combined
    }

    private func collectHIDGamepads() -> [GamepadDeviceInfo] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matchingCriteria: [[String: Int]] = [
            [
                kIOHIDDeviceUsagePageKey as String: Int(kHIDPage_GenericDesktop),
                kIOHIDDeviceUsageKey as String: Int(kHIDUsage_GD_Joystick)
            ],
            [
                kIOHIDDeviceUsagePageKey as String: Int(kHIDPage_GenericDesktop),
                kIOHIDDeviceUsageKey as String: Int(kHIDUsage_GD_GamePad)
            ],
            [
                kIOHIDDeviceUsagePageKey as String: Int(kHIDPage_GenericDesktop),
                kIOHIDDeviceUsageKey as String: Int(kHIDUsage_GD_MultiAxisController)
            ]
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matchingCriteria as CFArray)

        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            return []
        }
        defer {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }

        guard let cfDevices = IOHIDManagerCopyDevices(manager) else {
            return []
        }
        let devices = cfDevices as NSSet

        var results: [GamepadDeviceInfo] = []
        for case let hidDevice as IOHIDDevice in devices {
            let name = hidStringProperty(device: hidDevice, key: kIOHIDProductKey)
                ?? hidStringProperty(device: hidDevice, key: kIOHIDManufacturerKey)
                ?? "Control HID"
            let vendorID = hidIntProperty(device: hidDevice, key: kIOHIDVendorIDKey)
            let productID = hidIntProperty(device: hidDevice, key: kIOHIDProductIDKey)
            let locationID = hidIntProperty(device: hidDevice, key: kIOHIDLocationIDKey) ?? 0
            let identifier = "hid:\(vendorID ?? -1):\(productID ?? -1):\(locationID)"

            results.append(
                GamepadDeviceInfo(
                    id: identifier,
                    name: name,
                    source: .hid,
                    vendorID: vendorID,
                    productID: productID
                )
            )
        }

        return results
    }

    private func hidStringProperty(device: IOHIDDevice, key: String) -> String? {
        guard let value = IOHIDDeviceGetProperty(device, key as CFString) else {
            return nil
        }
        if let stringValue = value as? String {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    private func hidIntProperty(device: IOHIDDevice, key: String) -> Int? {
        guard let value = IOHIDDeviceGetProperty(device, key as CFString) else {
            return nil
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }

    private func normalizeName(_ rawName: String) -> String {
        rawName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
