import Cocoa
import Carbon

struct HistoryItem: Codable, Identifiable {
    let id: UUID
    let text: String
    let date: Date
    let isBarcode: Bool

    init(text: String, isBarcode: Bool = false) {
        self.id = UUID()
        self.text = text
        self.date = Date()
        self.isBarcode = isBarcode
    }

    var previewTitle: String {
        let singleLine = text
            .replacingOccurrences(of: "\r\n", with: " ↵ ")
            .replacingOccurrences(of: "\n", with: " ↵ ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = isBarcode ? "[QR/Barcode] " : ""
        let combined = prefix + singleLine
        if combined.count > 48 {
            return String(combined.prefix(48)) + "…"
        }
        return combined.isEmpty ? "(Vacío)" : combined
    }

    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct HotKeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var displayString: String

    // Default: Cmd + Shift + 2 (keyCode 19 is '2' on US/ISO keyboards)
    static let defaultCombo = HotKeyCombo(
        keyCode: UInt32(kVK_ANSI_2),
        carbonModifiers: UInt32(cmdKey | shiftKey),
        displayString: "⌘⇧2"
    )

    static let presets: [HotKeyCombo] = [
        HotKeyCombo(keyCode: UInt32(kVK_ANSI_2), carbonModifiers: UInt32(cmdKey | shiftKey), displayString: "⌘⇧2"),
        HotKeyCombo(keyCode: UInt32(kVK_ANSI_X), carbonModifiers: UInt32(cmdKey | shiftKey), displayString: "⌘⇧X"),
        HotKeyCombo(keyCode: UInt32(kVK_ANSI_S), carbonModifiers: UInt32(cmdKey | shiftKey), displayString: "⌘⇧S"),
        HotKeyCombo(keyCode: UInt32(kVK_ANSI_T), carbonModifiers: UInt32(optionKey | cmdKey), displayString: "⌥⌘T"),
        HotKeyCombo(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(controlKey | optionKey), displayString: "⌃⌥Espacio")
    ]

    var nsEventModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if (carbonModifiers & UInt32(cmdKey)) != 0 { flags.insert(.command) }
        if (carbonModifiers & UInt32(shiftKey)) != 0 { flags.insert(.shift) }
        if (carbonModifiers & UInt32(optionKey)) != 0 { flags.insert(.option) }
        if (carbonModifiers & UInt32(controlKey)) != 0 { flags.insert(.control) }
        return flags
    }

    var keyEquivalentCharacter: String {
        switch Int(keyCode) {
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_A: return "a"
        case kVK_ANSI_B: return "b"
        case kVK_ANSI_C: return "c"
        case kVK_ANSI_D: return "d"
        case kVK_ANSI_E: return "e"
        case kVK_ANSI_F: return "f"
        case kVK_ANSI_G: return "g"
        case kVK_ANSI_H: return "h"
        case kVK_ANSI_I: return "i"
        case kVK_ANSI_J: return "j"
        case kVK_ANSI_K: return "k"
        case kVK_ANSI_L: return "l"
        case kVK_ANSI_M: return "m"
        case kVK_ANSI_N: return "n"
        case kVK_ANSI_O: return "o"
        case kVK_ANSI_P: return "p"
        case kVK_ANSI_Q: return "q"
        case kVK_ANSI_R: return "r"
        case kVK_ANSI_S: return "s"
        case kVK_ANSI_T: return "t"
        case kVK_ANSI_U: return "u"
        case kVK_ANSI_V: return "v"
        case kVK_ANSI_W: return "w"
        case kVK_ANSI_X: return "x"
        case kVK_ANSI_Y: return "y"
        case kVK_ANSI_Z: return "z"
        case kVK_Space: return " "
        default: return ""
        }
    }
}

final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let keepLineBreaks = "keepLineBreaks"
        static let detectBarcodes = "detectBarcodes"
        static let playSound = "playSound"
        static let showHUD = "showHUD"
        static let additiveClipboard = "additiveClipboard"
        static let history = "captureHistory"
        static let hotKey = "globalHotKey"
        static let maxHistoryCount = 15

        // Module 1: Paste Plain Text Pro / URL Cleaner
        static let autoCleanClipboard = "autoCleanClipboard"
        static let stripURLTrackers = "stripURLTrackers"

        // Module 2: Automated Screenshot Organizer
        static let autoOrganizeScreenshots = "autoOrganizeScreenshots"
        static let moveScreenshotsToFolder = "moveScreenshotsToFolder"
        static let organizeByCategorySubfolders = "organizeByCategorySubfolders"
        static let watchedScreenshotsPath = "watchedScreenshotsPath"
        static let organizedScreenshotsPath = "organizedScreenshotsPath"
    }

    private init() {
        defaults.register(defaults: [
            Keys.keepLineBreaks: true,
            Keys.detectBarcodes: true,
            Keys.playSound: true,
            Keys.showHUD: true,
            Keys.additiveClipboard: false,
            Keys.autoCleanClipboard: false,
            Keys.stripURLTrackers: true,
            Keys.autoOrganizeScreenshots: false,
            Keys.moveScreenshotsToFolder: true,
            Keys.organizeByCategorySubfolders: true
        ])
    }

    var keepLineBreaks: Bool {
        get { defaults.bool(forKey: Keys.keepLineBreaks) }
        set { defaults.set(newValue, forKey: Keys.keepLineBreaks) }
    }

    var detectBarcodes: Bool {
        get { defaults.bool(forKey: Keys.detectBarcodes) }
        set { defaults.set(newValue, forKey: Keys.detectBarcodes) }
    }

    var playSound: Bool {
        get { defaults.bool(forKey: Keys.playSound) }
        set { defaults.set(newValue, forKey: Keys.playSound) }
    }

    var showHUD: Bool {
        get { defaults.bool(forKey: Keys.showHUD) }
        set { defaults.set(newValue, forKey: Keys.showHUD) }
    }

    var additiveClipboard: Bool {
        get { defaults.bool(forKey: Keys.additiveClipboard) }
        set { defaults.set(newValue, forKey: Keys.additiveClipboard) }
    }

    // MARK: - Module 1 Settings (Text & URL Cleaner)

    var autoCleanClipboard: Bool {
        get { defaults.bool(forKey: Keys.autoCleanClipboard) }
        set { defaults.set(newValue, forKey: Keys.autoCleanClipboard) }
    }

    var stripURLTrackers: Bool {
        get { defaults.bool(forKey: Keys.stripURLTrackers) }
        set { defaults.set(newValue, forKey: Keys.stripURLTrackers) }
    }

    // MARK: - Module 2 Settings (Screenshot Organizer)

    var autoOrganizeScreenshots: Bool {
        get { defaults.bool(forKey: Keys.autoOrganizeScreenshots) }
        set { defaults.set(newValue, forKey: Keys.autoOrganizeScreenshots) }
    }

    var moveScreenshotsToFolder: Bool {
        get { defaults.bool(forKey: Keys.moveScreenshotsToFolder) }
        set { defaults.set(newValue, forKey: Keys.moveScreenshotsToFolder) }
    }

    var organizeByCategorySubfolders: Bool {
        get { defaults.bool(forKey: Keys.organizeByCategorySubfolders) }
        set { defaults.set(newValue, forKey: Keys.organizeByCategorySubfolders) }
    }

    var watchedScreenshotsPath: String {
        get {
            if let saved = defaults.string(forKey: Keys.watchedScreenshotsPath), !saved.isEmpty {
                return (saved as NSString).expandingTildeInPath
            }
            // Check macOS system screenshot location preference if custom set
            if let sysDomain = UserDefaults.standard.persistentDomain(forName: "com.apple.screencapture"),
               let loc = sysDomain["location"] as? String, !loc.isEmpty {
                let expanded = (loc as NSString).expandingTildeInPath
                if FileManager.default.fileExists(atPath: expanded) {
                    return expanded
                }
            }
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path
        }
        set {
            defaults.set(newValue, forKey: Keys.watchedScreenshotsPath)
        }
    }

    var organizedScreenshotsPath: String {
        get {
            if let saved = defaults.string(forKey: Keys.organizedScreenshotsPath), !saved.isEmpty {
                return (saved as NSString).expandingTildeInPath
            }
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Pictures")
                .appendingPathComponent("SnipText Capturas").path
        }
        set {
            defaults.set(newValue, forKey: Keys.organizedScreenshotsPath)
        }
    }

    // MARK: - HotKey & History

    var hotKey: HotKeyCombo {
        get {
            guard let data = defaults.data(forKey: Keys.hotKey),
                  let combo = try? JSONDecoder().decode(HotKeyCombo.self, from: data) else {
                return HotKeyCombo.defaultCombo
            }
            return combo
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.hotKey)
            }
        }
    }

    var history: [HistoryItem] {
        get {
            guard let data = defaults.data(forKey: Keys.history),
                  let items = try? JSONDecoder().decode([HistoryItem].self, from: data) else {
                return []
            }
            return items
        }
        set {
            let trimmed = Array(newValue.prefix(Keys.maxHistoryCount))
            if let data = try? JSONEncoder().encode(trimmed) {
                defaults.set(data, forKey: Keys.history)
            }
        }
    }

    func addHistoryItem(text: String, isBarcode: Bool) {
        var current = history
        if let first = current.first, first.text == text {
            current.removeFirst()
        }
        current.insert(HistoryItem(text: text, isBarcode: isBarcode), at: 0)
        history = current
    }

    func clearHistory() {
        history = []
    }
}
