import AppKit
import Combine

enum HeadphoneKind: Equatable {
    case airPods        // 1st / 2nd gen
    case airPods3
    case airPods4
    case airPodsPro
    case airPodsMax
    case beats
    case generic

    /// Apple product IDs as reported by system_profiler (`device_productID`).
    private static let productIDs: [Int: HeadphoneKind] = [
        0x2002: .airPods, 0x200F: .airPods,
        0x2013: .airPods3,
        0x2019: .airPods4, 0x201B: .airPods4,
        0x200E: .airPodsPro, 0x2014: .airPodsPro, 0x2024: .airPodsPro,
        0x200A: .airPodsMax, 0x201F: .airPodsMax,
    ]

    static func detect(name: String, productID: Int?) -> HeadphoneKind {
        if let productID, let kind = productIDs[productID] { return kind }
        let lower = name.lowercased()
        if lower.contains("airpods pro") { return .airPodsPro }
        if lower.contains("airpods max") { return .airPodsMax }
        if lower.contains("airpods 4") { return .airPods4 }
        if lower.contains("airpods 3") { return .airPods3 }
        if lower.contains("airpods") { return .airPods }
        if lower.contains("beats") { return .beats }
        return .generic
    }

    var hasBuds: Bool {
        switch self {
        case .airPods, .airPods3, .airPods4, .airPodsPro: return true
        case .airPodsMax, .beats, .generic: return false
        }
    }

    var titleSymbol: String {
        switch self {
        case .airPods:    return SymbolPicker.first(["airpods"])
        case .airPods3:   return SymbolPicker.first(["airpods.gen3", "airpods"])
        case .airPods4:   return SymbolPicker.first(["airpods.gen4", "airpods.gen3", "airpods"])
        case .airPodsPro: return SymbolPicker.first(["airpodspro", "airpods"])
        case .airPodsMax: return SymbolPicker.first(["airpodsmax"])
        case .beats:      return SymbolPicker.first(["beats.headphones"])
        case .generic:    return "headphones"
        }
    }

    var leftSymbol: String {
        switch self {
        case .airPodsPro: return SymbolPicker.first(["airpodpro.left", "airpod.left"])
        case .airPods3:   return SymbolPicker.first(["airpod.gen3.left", "airpod.left"])
        case .airPods4:   return SymbolPicker.first(["airpod.gen4.left", "airpod.gen3.left", "airpod.left"])
        default:          return SymbolPicker.first(["airpod.left"])
        }
    }

    var rightSymbol: String {
        switch self {
        case .airPodsPro: return SymbolPicker.first(["airpodpro.right", "airpod.right"])
        case .airPods3:   return SymbolPicker.first(["airpod.gen3.right", "airpod.right"])
        case .airPods4:   return SymbolPicker.first(["airpod.gen4.right", "airpod.gen3.right", "airpod.right"])
        default:          return SymbolPicker.first(["airpod.right"])
        }
    }

    var caseSymbol: String {
        switch self {
        case .airPodsPro:
            return SymbolPicker.first(["airpodspro.chargingcase.wireless.fill",
                                       "airpodspro.chargingcase.wireless",
                                       "airpodspro.chargingcase.fill"])
        case .airPods3:
            return SymbolPicker.first(["airpods.gen3.chargingcase.wireless.fill",
                                       "airpods.gen3.chargingcase.wireless",
                                       "airpods.chargingcase.wireless.fill",
                                       "airpods.chargingcase.fill"])
        case .airPods4:
            return SymbolPicker.first(["airpods.gen4.chargingcase.wireless.fill",
                                       "airpods.gen4.chargingcase.wireless",
                                       "airpods.gen3.chargingcase.wireless.fill",
                                       "airpods.chargingcase.fill"])
        default:
            return SymbolPicker.first(["airpods.chargingcase.fill", "airpods.chargingcase"])
        }
    }

    /// Over-ear / single-battery devices.
    var singleSymbol: String {
        switch self {
        case .airPodsMax: return SymbolPicker.first(["airpodsmax"])
        case .beats:      return SymbolPicker.first(["beats.headphones"])
        default:          return "headphones"
        }
    }
}

enum SymbolPicker {
    /// First SF Symbol from `names` that exists on this macOS, else "headphones".
    static func first(_ names: [String]) -> String {
        names.first { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil } ?? "headphones"
    }
}

struct HeadphoneBattery: Equatable {
    /// Percentages 0...100, nil when unknown.
    var left: Int?
    var right: Int?
    var caseLevel: Int?
    var single: Int?
    var leftCharging = false
    var rightCharging = false
    var caseCharging = false
    var singleCharging = false

    var isEmpty: Bool {
        left == nil && right == nil && caseLevel == nil && single == nil
    }

    func isComplete(for kind: HeadphoneKind) -> Bool {
        kind.hasBuds ? (left != nil && right != nil) : (single != nil || left != nil || right != nil)
    }
}

@MainActor
final class HeadphoneInfo: ObservableObject {
    let name: String
    /// Bluetooth address, empty for the test device.
    let address: String
    @Published var kind: HeadphoneKind
    @Published var battery = HeadphoneBattery()

    init(name: String, address: String, kind: HeadphoneKind) {
        self.name = name
        self.address = address
        self.kind = kind
    }
}
