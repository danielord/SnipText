import Cocoa
import Vision

struct OCRResult {
    let text: String
    let isBarcode: Bool
}

final class OCRService {
    static let shared = OCRService()

    private var isCapturing = false

    private init() {}

    /// Launches interactive screen selection and processes the captured image with Vision OCR / Barcode detection.
    func captureAndRecognize(completion: @escaping (OCRResult?) -> Void) {
        guard !isCapturing else { return }
        isCapturing = true

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sniptext_capture_\(UUID().uuidString).png")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer {
                try? FileManager.default.removeItem(at: tempURL)
                DispatchQueue.main.async {
                    self?.isCapturing = false
                }
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            // -i: interactive selection (crosshair / spacebar for window)
            // -x: do not play default camera shutter sound
            process.arguments = ["-i", "-x", tempURL.path]

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                DispatchQueue.main.async {
                    HUDToast.shared.show(
                        title: L10n.tr("Capture Failed", "Error al iniciar captura"),
                        subtitle: error.localizedDescription,
                        isWarning: true
                    )
                    completion(nil)
                }
                return
            }

            // If user pressed Esc, file won't exist
            guard process.terminationStatus == 0,
                  FileManager.default.fileExists(atPath: tempURL.path),
                  let nsImage = NSImage(contentsOf: tempURL),
                  let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            let result = self?.performVisionRecognition(on: cgImage)

            DispatchQueue.main.async {
                guard let result = result, !result.text.isEmpty else {
                    HUDToast.shared.show(
                        title: L10n.tr("No Text Detected", "No se detectó texto"),
                        subtitle: L10n.tr("Try selecting a clearer area or check Screen Recording permissions", "Intenta seleccionar un área más clara o verifica permisos de pantalla"),
                        isWarning: true
                    )
                    completion(nil)
                    return
                }

                let finalText = AppSettings.shared.stripURLTrackers
                    ? TextCleanerService.shared.removeURLTrackers(in: result.text)
                    : result.text

                self?.copyToClipboard(text: finalText)
                AppSettings.shared.addHistoryItem(text: finalText, isBarcode: result.isBarcode)

                let title = result.isBarcode
                    ? L10n.tr("QR / Barcode Copied", "Código QR / Barras copiado")
                    : L10n.tr("Text Copied to Clipboard", "Texto copiado al portapapeles")
                HUDToast.shared.show(title: title, subtitle: finalText)
                completion(OCRResult(text: finalText, isBarcode: result.isBarcode))
            }
        }
    }

    func copyToClipboard(text: String, additive: Bool = AppSettings.shared.additiveClipboard) {
        let pasteboard = NSPasteboard.general
        let finalString: String
        if additive, let existing = pasteboard.string(forType: .string), !existing.isEmpty {
            let separator = AppSettings.shared.keepLineBreaks ? "\n" : " "
            finalString = existing + separator + text
        } else {
            finalString = text
        }
        pasteboard.clearContents()
        pasteboard.setString(finalString, forType: .string)
        TextCleanerService.shared.markPasteboardUpdatedByApp()
    }

    private func performVisionRecognition(on cgImage: CGImage) -> OCRResult? {
        var detectedBarcodes: [String] = []
        var recognizedLines: [String] = []

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        var requests: [VNRequest] = []

        // 1. Optional Barcode / QR request
        if AppSettings.shared.detectBarcodes {
            let barcodeRequest = VNDetectBarcodesRequest { request, _ in
                guard let observations = request.results as? [VNBarcodeObservation] else { return }
                for obs in observations {
                    if let payload = obs.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !payload.isEmpty {
                        detectedBarcodes.append(payload)
                    }
                }
            }
            requests.append(barcodeRequest)
        }

        // 2. Text Recognition request (Vision OCR)
        let textRequest = VNRecognizeTextRequest { request, _ in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            for observation in observations {
                if let topCandidate = observation.topCandidates(1).first {
                    let line = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !line.isEmpty {
                        recognizedLines.append(line)
                    }
                }
            }
        }
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        if #available(macOS 13.0, *) {
            textRequest.automaticallyDetectsLanguage = true
        }
        textRequest.recognitionLanguages = ["es-ES", "en-US", "pt-BR", "fr-FR", "de-DE", "it-IT"]
        requests.append(textRequest)

        do {
            try handler.perform(requests)
        } catch {
            return nil
        }

        // Prefer barcode/QR payload if one was clearly found and no regular text or alongside it
        if !detectedBarcodes.isEmpty {
            let uniqueBarcodes = Array(NSOrderedSet(array: detectedBarcodes)) as? [String] ?? detectedBarcodes
            let barcodeString = uniqueBarcodes.joined(separator: "\n")
            if recognizedLines.isEmpty {
                return OCRResult(text: barcodeString, isBarcode: true)
            }
            // If barcode was found and user specifically scanned a QR that also has small label text,
            // return barcode first if it's a URL or structured QR payload
            if uniqueBarcodes.first?.hasPrefix("http") == true || recognizedLines.count <= 2 {
                return OCRResult(text: barcodeString, isBarcode: true)
            }
        }

        guard !recognizedLines.isEmpty else { return nil }

        let separator = AppSettings.shared.keepLineBreaks ? "\n" : " "
        let joinedText = recognizedLines.joined(separator: separator)
        return OCRResult(text: joinedText, isBarcode: false)
    }
}
