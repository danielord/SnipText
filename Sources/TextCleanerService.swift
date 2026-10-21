import Cocoa

enum TextCaseStyle {
    case uppercase
    case lowercase
    case titleCase
    case sentenceCase
}

final class TextCleanerService {
    static let shared = TextCleanerService()

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount

    /// Known tracking query parameters across Google, Meta, YouTube, Spotify, TikTok, Amazon, X/Twitter, Mailchimp, HubSpot, etc.
    private let trackingParameters: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "utm_id",
        "fbclid", "gclid", "dclid", "gbraid", "wbraid", "msclkid", "twclid", "ttclid",
        "igshid", "igsh", "mc_cid", "mc_eid", "_ga", "_gl", "_hsenc", "_hsmi",
        "hsCtaTracking", "mkt_tok", "yclid", "vero_id", "oly_enc_id", "oly_anon_id",
        "rb_clickid", "s_kwcid", "si", "feature", "ref_src", "ref_url", "spm"
    ]

    private init() {}

    func syncMonitoringState() {
        if AppSettings.shared.autoCleanClipboard {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    func startMonitoring() {
        guard timer == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.65, repeats: true) { [weak self] _ in
            self?.checkPasteboardIfChanged()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func markPasteboardUpdatedByApp() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    private func checkPasteboardIfChanged() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        // Do not overwrite if user copied files or an image without string
        if let types = pasteboard.types,
           types.contains(.fileURL) || types.contains(.tiff) || types.contains(.png) {
            if pasteboard.string(forType: .string) == nil {
                return
            }
        }

        guard let original = pasteboard.string(forType: .string), !original.isEmpty else { return }

        let hasRichFormatting: Bool = {
            guard let types = pasteboard.types else { return false }
            return types.contains(.rtf) || types.contains(.html) || types.contains(.rtfd)
        }()

        let cleaned = cleanText(
            original,
            stripTrackers: AppSettings.shared.stripURLTrackers,
            collapseExtraSpaces: false
        )

        if cleaned != original || hasRichFormatting {
            pasteboard.clearContents()
            pasteboard.setString(cleaned, forType: .string)
            lastChangeCount = pasteboard.changeCount

            if cleaned != original {
                HUDToast.shared.show(
                    title: L10n.tr("URL / Text Auto-Cleaned", "URL / Texto limpiado automáticamente"),
                    subtitle: cleaned
                )
            }
        }
    }

    // MARK: - Core Cleaning Logic

    func cleanText(_ input: String, stripTrackers: Bool = true, collapseExtraSpaces: Bool = false) -> String {
        var result = input
            .replacingOccurrences(of: "\u{00A0}", with: " ") // non-breaking space
            .replacingOccurrences(of: "\u{200B}", with: "")  // zero-width space
            .replacingOccurrences(of: "\r\n", with: "\n")

        if stripTrackers {
            result = removeURLTrackers(in: result)
        }

        if collapseExtraSpaces {
            let lines = result.components(separatedBy: "\n").map { line -> String in
                line.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            }.filter { !$0.isEmpty }
            result = lines.joined(separator: AppSettings.shared.keepLineBreaks ? "\n" : " ")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func removeURLTrackers(in text: String) -> String {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return text
        }

        let nsText = text as NSString
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let rawURLString = nsText.substring(with: match.range)
            if let cleanedURL = cleanSingleURLString(rawURLString), cleanedURL != rawURLString {
                mutable.replaceCharacters(in: match.range, with: cleanedURL)
            }
        }
        return mutable as String
    }

    private func cleanSingleURLString(_ rawURLString: String) -> String? {
        guard var components = URLComponents(string: rawURLString) else { return nil }
        guard let queryItems = components.queryItems, !queryItems.isEmpty else { return rawURLString }

        let filtered = queryItems.filter { item in
            let lowerName = item.name.lowercased()
            if lowerName.hasPrefix("utm_") { return false }
            if trackingParameters.contains(lowerName) { return false }
            return true
        }

        if filtered.count == queryItems.count {
            return rawURLString
        }

        components.queryItems = filtered.isEmpty ? nil : filtered
        return components.url?.absoluteString ?? rawURLString
    }

    // MARK: - Manual Menu Invocations

    func cleanClipboardNow(collapseSpaces: Bool = false) {
        let pasteboard = NSPasteboard.general
        guard let current = pasteboard.string(forType: .string), !current.isEmpty else {
            HUDToast.shared.show(
                title: L10n.tr("Clipboard is Empty", "Portapapeles vacío"),
                subtitle: L10n.tr("No text found in clipboard to clean", "No hay texto en el portapapeles para limpiar"),
                isWarning: true
            )
            return
        }

        let cleaned = cleanText(current, stripTrackers: true, collapseExtraSpaces: collapseSpaces)
        pasteboard.clearContents()
        pasteboard.setString(cleaned, forType: .string)
        lastChangeCount = pasteboard.changeCount
        AppSettings.shared.addHistoryItem(text: cleaned, isBarcode: false)

        HUDToast.shared.show(
            title: collapseSpaces
                ? L10n.tr("Extra Spaces & Formatting Cleaned", "Espacios y formato limpiados")
                : L10n.tr("Plain Text & URLs Cleaned", "Texto plano y URLs limpiadas"),
            subtitle: cleaned
        )
    }

    func transformClipboardCase(_ style: TextCaseStyle) {
        let pasteboard = NSPasteboard.general
        guard let current = pasteboard.string(forType: .string), !current.isEmpty else {
            HUDToast.shared.show(
                title: L10n.tr("Clipboard is Empty", "Portapapeles vacío"),
                subtitle: L10n.tr("Copy some text first to transform it", "Copia algún texto primero para transformarlo"),
                isWarning: true
            )
            return
        }

        let transformed: String
        let label: String
        switch style {
        case .uppercase:
            transformed = current.uppercased(with: Locale.current)
            label = L10n.tr("Converted to UPPERCASE", "Convertido a MAYÚSCULAS")
        case .lowercase:
            transformed = current.lowercased(with: Locale.current)
            label = L10n.tr("Converted to lowercase", "Convertido a minúsculas")
        case .titleCase:
            transformed = current.localizedCapitalized
            label = L10n.tr("Converted to Title Case", "Convertido a Tipo Título")
        case .sentenceCase:
            transformed = toSentenceCase(current)
            label = L10n.tr("Converted to Sentence case", "Convertido a Tipo Oración")
        }

        pasteboard.clearContents()
        pasteboard.setString(transformed, forType: .string)
        lastChangeCount = pasteboard.changeCount
        AppSettings.shared.addHistoryItem(text: transformed, isBarcode: false)

        HUDToast.shared.show(title: label, subtitle: transformed)
    }

    private func toSentenceCase(_ text: String) -> String {
        let lower = text.lowercased(with: Locale.current)
        var result = ""
        var capitalizeNext = true
        for char in lower {
            if capitalizeNext && char.isLetter {
                result.append(String(char).uppercased(with: Locale.current))
                capitalizeNext = false
            } else {
                result.append(char)
                if char == "." || char == "!" || char == "?" || char == "\n" {
                    capitalizeNext = true
                }
            }
        }
        return result
    }
}
