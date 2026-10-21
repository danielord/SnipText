import Cocoa
import Vision

struct ScreenshotClassification {
    let folderCategory: String
    let shortPrefix: String
    let keywordsSlug: String
}

final class ScreenshotOrganizerService {
    static let shared = ScreenshotOrganizerService()

    private var directoryFD: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var debounceWorkItem: DispatchWorkItem?
    private var processingPaths = Set<String>()
    private let queue = DispatchQueue(label: "com.danielordonez.SnipText.ScreenshotOrganizer", qos: .utility)

    private init() {}

    func syncMonitoringState() {
        if AppSettings.shared.autoOrganizeScreenshots {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    func startMonitoring() {
        stopMonitoring()

        let path = AppSettings.shared.watchedScreenshotsPath
        guard FileManager.default.fileExists(atPath: path) else { return }

        directoryFD = open(path, O_EVTONLY)
        guard directoryFD >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryFD,
            eventMask: [.write, .rename, .extend],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.scheduleScanForNewScreenshots()
        }

        let fdToClose = directoryFD
        source.setCancelHandler {
            close(fdToClose)
        }

        dispatchSource = source
        source.resume()
    }

    func stopMonitoring() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        if let source = dispatchSource {
            source.cancel()
            dispatchSource = nil
        }
        directoryFD = -1
    }

    private func scheduleScanForNewScreenshots() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.scanWatchedDirectory(onlyRecent: true, notifyIfZero: false)
        }
        debounceWorkItem = work
        // Wait 1.0s after macOS finishes writing screenshot file
        queue.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    /// Manual action invokable from the Menu Bar
    func organizeExistingScreenshotsNow(completion: (() -> Void)? = nil) {
        queue.async { [weak self] in
            self?.scanWatchedDirectory(onlyRecent: false, notifyIfZero: true)
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    private func scanWatchedDirectory(onlyRecent: Bool, notifyIfZero: Bool) {
        let fm = FileManager.default
        let watchedPath = AppSettings.shared.watchedScreenshotsPath
        guard let entries = try? fm.contentsOfDirectory(atPath: watchedPath) else { return }

        let now = Date()
        var candidates: [URL] = []

        for entry in entries {
            // Ignore hidden files (macOS writes temporary `.Screen Shot...` first)
            guard !entry.hasPrefix(".") else { continue }
            guard isUnorganizedScreenshotFilename(entry) else { continue }

            let fileURL = URL(fileURLWithPath: watchedPath).appendingPathComponent(entry)
            guard !processingPaths.contains(fileURL.path) else { continue }

            if onlyRecent {
                if let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
                   let created = attrs[.creationDate] as? Date,
                   now.timeIntervalSince(created) > 30 {
                    continue
                }
            }
            candidates.append(fileURL)
        }

        guard !candidates.isEmpty else {
            if notifyIfZero {
                let folderName = (watchedPath as NSString).lastPathComponent
                HUDToast.shared.show(
                    title: L10n.tr("No Pending Screenshots", "Sin capturas pendientes"),
                    subtitle: L10n.tr("No unorganized screenshots found in \(folderName)", "No se encontraron capturas sin organizar en \(folderName)")
                )
            }
            return
        }

        var organizedCount = 0
        var lastNewName = ""

        for fileURL in candidates {
            processingPaths.insert(fileURL.path)
            defer { processingPaths.remove(fileURL.path) }

            if let newURL = processSingleScreenshot(at: fileURL) {
                organizedCount += 1
                lastNewName = newURL.lastPathComponent
            }
        }

        if organizedCount == 1 {
            HUDToast.shared.show(
                title: L10n.tr("Screenshot Organized with OCR", "Captura organizada con OCR"),
                subtitle: "→ \(lastNewName)"
            )
        } else if organizedCount > 1 {
            HUDToast.shared.show(
                title: L10n.tr("\(organizedCount) Screenshots Organized", "\(organizedCount) capturas organizadas"),
                subtitle: L10n.tr("Latest: \(lastNewName)", "Última: \(lastNewName)")
            )
        }
    }

    private func isUnorganizedScreenshotFilename(_ filename: String) -> Bool {
        let lower = filename.lowercased()
        guard lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") else {
            return false
        }
        return lower.hasPrefix("captura de pantalla")
            || lower.hasPrefix("screen shot")
            || lower.hasPrefix("screenshot")
            || lower.hasPrefix("captura ")
    }

    private func processSingleScreenshot(at fileURL: URL) -> URL? {
        guard let nsImage = NSImage(contentsOf: fileURL),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let lines = extractTextLines(from: cgImage)
        let classification = classifyAndExtractSlug(from: lines)

        let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let creationDate = (attrs?[.creationDate] as? Date) ?? Date()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: creationDate)

        let ext = fileURL.pathExtension.isEmpty ? "png" : fileURL.pathExtension
        let baseName: String
        if classification.keywordsSlug.isEmpty {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HHmmss"
            baseName = "\(classification.shortPrefix)_\(dateStr)_\(timeFormatter.string(from: creationDate))"
        } else {
            baseName = "\(classification.shortPrefix)_\(classification.keywordsSlug)_\(dateStr)"
        }

        let destinationDir: URL
        if AppSettings.shared.moveScreenshotsToFolder {
            let rootDir = URL(fileURLWithPath: AppSettings.shared.organizedScreenshotsPath)
            if AppSettings.shared.organizeByCategorySubfolders {
                destinationDir = rootDir.appendingPathComponent(classification.folderCategory)
            } else {
                destinationDir = rootDir
            }
        } else {
            destinationDir = fileURL.deletingLastPathComponent()
        }

        do {
            try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
            let finalURL = uniqueDestinationURL(directory: destinationDir, baseName: baseName, ext: ext)
            try FileManager.default.moveItem(at: fileURL, to: finalURL)
            return finalURL
        } catch {
            return nil
        }
    }

    private func uniqueDestinationURL(directory: URL, baseName: String, ext: String) -> URL {
        let fm = FileManager.default
        var candidate = directory.appendingPathComponent("\(baseName).\(ext)")
        var counter = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName)_\(counter).\(ext)")
            counter += 1
        }
        return candidate
    }

    private func extractTextLines(from cgImage: CGImage) -> [String] {
        var lines: [String] = []
        let request = VNRecognizeTextRequest { req, _ in
            guard let observations = req.results as? [VNRecognizedTextObservation] else { return }
            for obs in observations {
                if let top = obs.topCandidates(1).first {
                    let clean = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty {
                        lines.append(clean)
                    }
                }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        if #available(macOS 13.0, *) {
            request.automaticallyDetectsLanguage = true
        }
        request.recognitionLanguages = ["es-ES", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        return lines
    }

    private func classifyAndExtractSlug(from lines: [String]) -> ScreenshotClassification {
        let fullTextLower = lines.joined(separator: " ").lowercased()

        // 1. Determine category & prefix
        let folderCategory: String
        let shortPrefix: String

        let receiptTerms = [
            "recibo", "factura", "ticket", "total", "subtotal", "iva", "pago", "transferencia",
            "spei", "clabe", "oxxo", "bbva", "banamex", "citibanamex", "santander", "banorte",
            "hsbc", "mercadopago", "stripe", "paypal", "amazon", "invoice", "receipt", "orden"
        ]
        let codeTerms = [
            "import ", "func ", "struct ", "class ", "let ", "var ", "const ", "function ",
            "return ", "git ", "xcode", "terminal", "error:", "warning:", "exception",
            "python", "swift", "javascript", "typescript", "docker", "npm ", "brew "
        ]
        let chatTerms = [
            "whatsapp", "telegram", "slack", "discord", "escribe un mensaje", "en línea",
            "imessage", "mensajes", "chat"
        ]

        if receiptTerms.contains(where: { fullTextLower.contains($0) }) {
            folderCategory = L10n.tr("Receipts_and_Payments", "Recibos_y_Pagos")
            shortPrefix = L10n.tr("Receipt", "Recibo")
        } else if codeTerms.contains(where: { fullTextLower.contains($0) }) {
            folderCategory = L10n.tr("Code_and_Dev", "Codigo_y_Dev")
            shortPrefix = L10n.tr("Code", "Codigo")
        } else if chatTerms.contains(where: { fullTextLower.contains($0) }) {
            folderCategory = L10n.tr("Chats", "Conversaciones")
            shortPrefix = "Chat"
        } else if fullTextLower.contains("http") || fullTextLower.contains("www.") || fullTextLower.contains(".com") {
            folderCategory = L10n.tr("Web_and_Links", "Web_y_Enlaces")
            shortPrefix = "Web"
        } else {
            folderCategory = "General"
            shortPrefix = L10n.tr("Capture", "Captura")
        }

        // 2. Check known brand / entity names first for extra clarity (e.g. "Oxxo", "BBVA", "GitHub")
        let knownEntities = [
            "Oxxo", "BBVA", "Banamex", "Santander", "Banorte", "MercadoPago", "Amazon",
            "Stripe", "PayPal", "SAT", "CFE", "Telmex", "Uber", "Didi", "Rappi",
            "GitHub", "YouTube", "Xcode", "Slack", "WhatsApp", "Telegram", "Notion", "Figma"
        ]
        var chosenWords: [String] = []
        for entity in knownEntities {
            if fullTextLower.contains(entity.lowercased()) {
                chosenWords.append(entity)
                break
            }
        }

        // 3. Extract 2-3 meaningful words from the first non-UI lines
        let stopWords: Set<String> = [
            "de", "la", "el", "los", "las", "en", "y", "a", "con", "por", "para", "del", "al",
            "un", "una", "es", "son", "se", "su", "sus", "que", "como", "mas", "pero", "este",
            "esta", "the", "and", "for", "with", "from", "that", "this", "are", "was", "were",
            "file", "edit", "view", "window", "help", "archivo", "edicion", "ver", "ventana", "ayuda",
            "captura", "pantalla", "screenshot", "recibo", "codigo", "chat", "web"
        ]

        for line in lines.prefix(8) {
            let rawTokens = line
                .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es_ES"))
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 3 && $0.count <= 18 }

            for token in rawTokens {
                let lower = token.lowercased()
                guard !stopWords.contains(lower) else { continue }
                // Avoid pure numbers unless it's a 4-digit year
                if Int(token) != nil && token.count != 4 { continue }
                let capitalized = token.prefix(1).uppercased() + token.dropFirst().lowercased()
                if !chosenWords.contains(where: { $0.lowercased() == lower }) {
                    chosenWords.append(capitalized)
                }
                if chosenWords.count >= 3 { break }
            }
            if chosenWords.count >= 3 { break }
        }

        let slug = chosenWords.joined(separator: "_")
        return ScreenshotClassification(
            folderCategory: folderCategory,
            shortPrefix: shortPrefix,
            keywordsSlug: slug
        )
    }
}
