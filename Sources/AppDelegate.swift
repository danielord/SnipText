import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let statusMenu = NSMenu()
    private var recorderWindow: ShortcutRecorderWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }

        setupStatusItem()
        setupHotKey()
        TextCleanerService.shared.syncMonitoringState()
        ScreenshotOrganizerService.shared.syncMonitoringState()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "SnipText") {
                let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
                let configured = image.withSymbolConfiguration(config) ?? image
                configured.isTemplate = true
                button.image = configured
            } else {
                button.title = "SnipText"
            }
        }

        statusMenu.delegate = self
        statusItem.menu = statusMenu
        rebuildMenu()
    }

    private func setupHotKey() {
        HotKeyManager.shared.onHotKeyPressed = { [weak self] in
            self?.startCapture()
        }
        HotKeyManager.shared.register(combo: AppSettings.shared.hotKey)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        statusMenu.removeAllItems()

        let currentHotKey = AppSettings.shared.hotKey
        statusItem.button?.toolTip = L10n.tr(
            "SnipText — Capture Screen Text (\(currentHotKey.displayString))",
            "SnipText — Capturar texto (\(currentHotKey.displayString))"
        )

        // 1. Primary Capture Action
        let captureItem = NSMenuItem(
            title: L10n.tr("Capture Screen Text", "Capturar Texto en Pantalla"),
            action: #selector(startCaptureAction),
            keyEquivalent: currentHotKey.keyEquivalentCharacter
        )
        captureItem.keyEquivalentModifierMask = currentHotKey.nsEventModifierFlags
        captureItem.target = self
        if let icon = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: nil) {
            captureItem.image = icon
        }
        statusMenu.addItem(captureItem)

        statusMenu.addItem(.separator())

        // 2. Latest Copied Text Preview & History
        let history = AppSettings.shared.history
        if let latest = history.first {
            let headerItem = NSMenuItem(
                title: L10n.tr("Latest capture (click to copy):", "Última captura (clic para copiar):"),
                action: nil,
                keyEquivalent: ""
            )
            headerItem.isEnabled = false
            statusMenu.addItem(headerItem)

            let previewItem = NSMenuItem(
                title: "  " + latest.previewTitle,
                action: #selector(copyHistoryItem(_:)),
                keyEquivalent: ""
            )
            previewItem.target = self
            previewItem.representedObject = latest.text
            previewItem.toolTip = latest.text
            if let docIcon = NSImage(
                systemSymbolName: latest.isBarcode ? "qrcode" : "doc.on.clipboard",
                accessibilityDescription: nil
            ) {
                previewItem.image = docIcon
            }
            statusMenu.addItem(previewItem)

            // History Submenu
            let historySubmenu = NSMenu(title: L10n.tr("Recent History", "Historial Reciente"))
            for (index, item) in history.enumerated() {
                let menuTitle = "\(index + 1). \(item.previewTitle)  (\(item.relativeTimeString))"
                let hItem = NSMenuItem(title: menuTitle, action: #selector(copyHistoryItem(_:)), keyEquivalent: "")
                hItem.target = self
                hItem.representedObject = item.text
                hItem.toolTip = item.text
                if let icon = NSImage(
                    systemSymbolName: item.isBarcode ? "qrcode" : "text.alignleft",
                    accessibilityDescription: nil
                ) {
                    hItem.image = icon
                }
                historySubmenu.addItem(hItem)
            }
            historySubmenu.addItem(.separator())
            let clearItem = NSMenuItem(
                title: L10n.tr("Clear History", "Borrar Historial"),
                action: #selector(clearHistoryAction),
                keyEquivalent: ""
            )
            clearItem.target = self
            historySubmenu.addItem(clearItem)

            let historyRoot = NSMenuItem(
                title: L10n.tr("Recent History (\(history.count))", "Historial Reciente (\(history.count))"),
                action: nil,
                keyEquivalent: ""
            )
            if let clockIcon = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil) {
                historyRoot.image = clockIcon
            }
            historyRoot.submenu = historySubmenu
            statusMenu.addItem(historyRoot)
        } else {
            let emptyItem = NSMenuItem(
                title: L10n.tr("No recent captures", "Sin capturas recientes"),
                action: nil,
                keyEquivalent: ""
            )
            emptyItem.isEnabled = false
            statusMenu.addItem(emptyItem)
        }

        statusMenu.addItem(.separator())

        // 3. MODULE 1: Limpiador de Texto y URLs (Paste Plain Text Pro)
        let cleanerSubmenu = NSMenu(title: L10n.tr("Text & URL Cleaner", "Limpiador de Texto y URLs"))

        let autoCleanItem = NSMenuItem(
            title: L10n.tr("Active Module: Auto-clean on copy (⌘C)", "Módulo activo: Limpiar automáticamente al copiar (⌘C)"),
            action: #selector(toggleAutoCleanClipboard),
            keyEquivalent: ""
        )
        autoCleanItem.target = self
        autoCleanItem.state = AppSettings.shared.autoCleanClipboard ? .on : .off
        cleanerSubmenu.addItem(autoCleanItem)

        let stripTrackersItem = NSMenuItem(
            title: L10n.tr("Remove URL trackers (utm_, fbclid, gclid, si…)", "Quitar rastreadores de URLs (utm_, fbclid, gclid, si…)"),
            action: #selector(toggleStripURLTrackers),
            keyEquivalent: ""
        )
        stripTrackersItem.target = self
        stripTrackersItem.state = AppSettings.shared.stripURLTrackers ? .on : .off
        cleanerSubmenu.addItem(stripTrackersItem)

        cleanerSubmenu.addItem(.separator())

        let cleanNowItem = NSMenuItem(
            title: L10n.tr("⚡ Clean current clipboard now (Plain Text + URL)", "⚡ Limpiar portapapeles actual ahora (Texto plano + URL)"),
            action: #selector(cleanClipboardNowAction),
            keyEquivalent: ""
        )
        cleanNowItem.target = self
        cleanerSubmenu.addItem(cleanNowItem)

        let collapseSpacesItem = NSMenuItem(
            title: L10n.tr("⚡ Remove extra spaces & empty lines", "⚡ Quitar espacios dobles y líneas vacías"),
            action: #selector(collapseSpacesNowAction),
            keyEquivalent: ""
        )
        collapseSpacesItem.target = self
        cleanerSubmenu.addItem(collapseSpacesItem)

        cleanerSubmenu.addItem(.separator())

        let upperItem = NSMenuItem(
            title: L10n.tr("Transform to UPPERCASE", "Transformar a MAYÚSCULAS"),
            action: #selector(transformUpperAction),
            keyEquivalent: ""
        )
        upperItem.target = self
        cleanerSubmenu.addItem(upperItem)

        let lowerItem = NSMenuItem(
            title: L10n.tr("Transform to lowercase", "Transformar a minúsculas"),
            action: #selector(transformLowerAction),
            keyEquivalent: ""
        )
        lowerItem.target = self
        cleanerSubmenu.addItem(lowerItem)

        let titleCaseItem = NSMenuItem(
            title: L10n.tr("Transform to Title Case", "Transformar a Tipo Título"),
            action: #selector(transformTitleAction),
            keyEquivalent: ""
        )
        titleCaseItem.target = self
        cleanerSubmenu.addItem(titleCaseItem)

        let sentenceCaseItem = NSMenuItem(
            title: L10n.tr("Transform to Sentence case", "Transformar a Tipo Oración"),
            action: #selector(transformSentenceAction),
            keyEquivalent: ""
        )
        sentenceCaseItem.target = self
        cleanerSubmenu.addItem(sentenceCaseItem)

        let cleanerStatus = AppSettings.shared.autoCleanClipboard
            ? L10n.tr("Active", "Activo")
            : L10n.tr("Manual", "Manual")
        let cleanerRoot = NSMenuItem(
            title: L10n.tr("Text & URL Cleaner (\(cleanerStatus))", "Limpiador de Texto y URLs (\(cleanerStatus))"),
            action: nil,
            keyEquivalent: ""
        )
        if let wandIcon = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: nil) {
            cleanerRoot.image = wandIcon
        }
        cleanerRoot.submenu = cleanerSubmenu
        statusMenu.addItem(cleanerRoot)

        // 4. MODULE 2: Organizador Automatizado de Capturas de Pantalla
        let organizerSubmenu = NSMenu(title: L10n.tr("Screenshot Organizer", "Organizador de Capturas"))

        let autoOrgItem = NSMenuItem(
            title: L10n.tr("Active Module: Auto-rename & organize new screenshots", "Módulo activo: Auto-renombrar y organizar nuevas capturas"),
            action: #selector(toggleAutoOrganizeScreenshots),
            keyEquivalent: ""
        )
        autoOrgItem.target = self
        autoOrgItem.state = AppSettings.shared.autoOrganizeScreenshots ? .on : .off
        organizerSubmenu.addItem(autoOrgItem)

        let organizeNowItem = NSMenuItem(
            title: L10n.tr("⚡ Organize existing screenshots now", "⚡ Organizar capturas existentes ahora"),
            action: #selector(organizeExistingScreenshotsNowAction),
            keyEquivalent: ""
        )
        organizeNowItem.target = self
        organizerSubmenu.addItem(organizeNowItem)

        organizerSubmenu.addItem(.separator())

        let moveFolderItem = NSMenuItem(
            title: L10n.tr("Move to ~/Pictures/SnipText Screenshots", "Mover a carpeta ~/Pictures/SnipText Capturas"),
            action: #selector(toggleMoveScreenshotsToFolder),
            keyEquivalent: ""
        )
        moveFolderItem.target = self
        moveFolderItem.state = AppSettings.shared.moveScreenshotsToFolder ? .on : .off
        organizerSubmenu.addItem(moveFolderItem)

        let categorySubfolderItem = NSMenuItem(
            title: L10n.tr("Group into subfolders (Receipts, Code, Web…)", "Clasificar en subcarpetas (Recibos, Código, Web…)"),
            action: #selector(toggleOrganizeByCategorySubfolders),
            keyEquivalent: ""
        )
        categorySubfolderItem.target = self
        categorySubfolderItem.state = AppSettings.shared.organizeByCategorySubfolders ? .on : .off
        categorySubfolderItem.isEnabled = AppSettings.shared.moveScreenshotsToFolder
        organizerSubmenu.addItem(categorySubfolderItem)

        organizerSubmenu.addItem(.separator())

        let watchedFolderName = (AppSettings.shared.watchedScreenshotsPath as NSString).lastPathComponent
        let chooseWatchedItem = NSMenuItem(
            title: L10n.tr("Watched folder: \(watchedFolderName) (Change…)", "Carpeta vigilada: \(watchedFolderName) (Cambiar…)"),
            action: #selector(chooseWatchedScreenshotsFolder),
            keyEquivalent: ""
        )
        chooseWatchedItem.target = self
        organizerSubmenu.addItem(chooseWatchedItem)

        let openOrganizedItem = NSMenuItem(
            title: L10n.tr("Open organized screenshots folder", "Abrir carpeta de capturas organizadas"),
            action: #selector(openOrganizedScreenshotsFolder),
            keyEquivalent: ""
        )
        openOrganizedItem.target = self
        organizerSubmenu.addItem(openOrganizedItem)

        let organizerStatus = AppSettings.shared.autoOrganizeScreenshots
            ? L10n.tr("Active", "Activo")
            : L10n.tr("Manual", "Manual")
        let organizerRoot = NSMenuItem(
            title: L10n.tr("Screenshot Organizer (\(organizerStatus))", "Organizador de Capturas (\(organizerStatus))"),
            action: nil,
            keyEquivalent: ""
        )
        if let folderIcon = NSImage(systemSymbolName: "folder.badge.gearshape", accessibilityDescription: nil) {
            organizerRoot.image = folderIcon
        }
        organizerRoot.submenu = organizerSubmenu
        statusMenu.addItem(organizerRoot)

        statusMenu.addItem(.separator())

        // 5. OCR & Clipboard Toggles
        let lineBreaksItem = NSMenuItem(
            title: L10n.tr("Keep line breaks in OCR", "Mantener saltos de línea en OCR"),
            action: #selector(toggleKeepLineBreaks),
            keyEquivalent: ""
        )
        lineBreaksItem.target = self
        lineBreaksItem.state = AppSettings.shared.keepLineBreaks ? .on : .off
        statusMenu.addItem(lineBreaksItem)

        let barcodeItem = NSMenuItem(
            title: L10n.tr("Read QR & Barcodes", "Leer códigos QR y de barras"),
            action: #selector(toggleDetectBarcodes),
            keyEquivalent: ""
        )
        barcodeItem.target = self
        barcodeItem.state = AppSettings.shared.detectBarcodes ? .on : .off
        statusMenu.addItem(barcodeItem)

        let additiveItem = NSMenuItem(
            title: L10n.tr("Append captures to clipboard", "Acumular texto en portapapeles"),
            action: #selector(toggleAdditiveClipboard),
            keyEquivalent: ""
        )
        additiveItem.target = self
        additiveItem.state = AppSettings.shared.additiveClipboard ? .on : .off
        statusMenu.addItem(additiveItem)

        statusMenu.addItem(.separator())

        // 6. Feedback, Language & Shortcut Configuration Submenu
        let prefsSubmenu = NSMenu(title: L10n.tr("Preferences & Shortcut", "Preferencias y Atajo"))

        let soundItem = NSMenuItem(
            title: L10n.tr("Subtle sound on copy", "Sonido sutil al copiar"),
            action: #selector(togglePlaySound),
            keyEquivalent: ""
        )
        soundItem.target = self
        soundItem.state = AppSettings.shared.playSound ? .on : .off
        prefsSubmenu.addItem(soundItem)

        let hudItem = NSMenuItem(
            title: L10n.tr("Show floating HUD banner", "Mostrar aviso flotante (HUD)"),
            action: #selector(toggleShowHUD),
            keyEquivalent: ""
        )
        hudItem.target = self
        hudItem.state = AppSettings.shared.showHUD ? .on : .off
        prefsSubmenu.addItem(hudItem)

        prefsSubmenu.addItem(.separator())
        let shortcutHeader = NSMenuItem(
            title: L10n.tr("Global Keyboard Shortcut:", "Atajo de Teclado Global:"),
            action: nil,
            keyEquivalent: ""
        )
        shortcutHeader.isEnabled = false
        prefsSubmenu.addItem(shortcutHeader)

        for preset in HotKeyCombo.presets {
            let presetItem = NSMenuItem(
                title: "  " + preset.displayString,
                action: #selector(selectPresetHotKey(_:)),
                keyEquivalent: ""
            )
            presetItem.target = self
            presetItem.representedObject = preset
            presetItem.state = (preset == currentHotKey) ? .on : .off
            prefsSubmenu.addItem(presetItem)
        }
        if !HotKeyCombo.presets.contains(currentHotKey) {
            let customCurrent = NSMenuItem(
                title: L10n.tr("  Custom (\(currentHotKey.displayString))", "  Personalizado (\(currentHotKey.displayString))"),
                action: nil,
                keyEquivalent: ""
            )
            customCurrent.state = .on
            prefsSubmenu.addItem(customCurrent)
        }
        let customRecorderItem = NSMenuItem(
            title: L10n.tr("Record custom shortcut…", "Grabar atajo personalizado…"),
            action: #selector(openShortcutRecorder),
            keyEquivalent: ""
        )
        customRecorderItem.target = self
        prefsSubmenu.addItem(customRecorderItem)

        prefsSubmenu.addItem(.separator())
        let langHeader = NSMenuItem(
            title: L10n.tr("Language / Idioma:", "Idioma / Language:"),
            action: nil,
            keyEquivalent: ""
        )
        langHeader.isEnabled = false
        prefsSubmenu.addItem(langHeader)

        let currentLang = AppSettings.shared.appLanguage
        let langOptions: [(AppLanguage, String)] = [
            (.system, L10n.tr("  System Default (Auto)", "  Automático (Sistema)")),
            (.english, "  English"),
            (.spanish, "  Español")
        ]
        for (lang, title) in langOptions {
            let item = NSMenuItem(title: title, action: #selector(selectAppLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang.rawValue
            item.state = (currentLang == lang) ? .on : .off
            prefsSubmenu.addItem(item)
        }

        let prefsRoot = NSMenuItem(
            title: L10n.tr("Shortcut (\(currentHotKey.displayString)) & Settings", "Atajo (\(currentHotKey.displayString)) y Ajustes"),
            action: nil,
            keyEquivalent: ""
        )
        if let kbIcon = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil) {
            prefsRoot.image = kbIcon
        }
        prefsRoot.submenu = prefsSubmenu
        statusMenu.addItem(prefsRoot)

        if !CGPreflightScreenCaptureAccess() {
            statusMenu.addItem(.separator())
            let permItem = NSMenuItem(
                title: L10n.tr("⚠️ Grant Screen Recording Permission…", "⚠️ Otorgar Permiso de Pantalla…"),
                action: #selector(openScreenCaptureSettings),
                keyEquivalent: ""
            )
            permItem.target = self
            statusMenu.addItem(permItem)
        }

        statusMenu.addItem(.separator())

        let aboutItem = NSMenuItem(
            title: L10n.tr("About SnipText…", "Acerca de SnipText…"),
            action: #selector(openAboutPanel),
            keyEquivalent: ""
        )
        aboutItem.target = self
        if let infoIcon = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil) {
            aboutItem.image = infoIcon
        }
        statusMenu.addItem(aboutItem)

        let quitItem = NSMenuItem(
            title: L10n.tr("Quit SnipText", "Salir de SnipText"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        statusMenu.addItem(quitItem)
    }

    // MARK: - OCR & History Actions

    @objc private func startCaptureAction() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.startCapture()
        }
    }

    private func startCapture() {
        OCRService.shared.captureAndRecognize { [weak self] _ in
            self?.rebuildMenu()
        }
    }

    @objc private func copyHistoryItem(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        OCRService.shared.copyToClipboard(text: text, additive: false)
        HUDToast.shared.show(
            title: L10n.tr("Copied from History", "Copiado del historial"),
            subtitle: text
        )
    }

    @objc private func clearHistoryAction() {
        AppSettings.shared.clearHistory()
        rebuildMenu()
    }

    @objc private func toggleKeepLineBreaks() {
        AppSettings.shared.keepLineBreaks.toggle()
        rebuildMenu()
    }

    @objc private func toggleDetectBarcodes() {
        AppSettings.shared.detectBarcodes.toggle()
        rebuildMenu()
    }

    @objc private func toggleAdditiveClipboard() {
        AppSettings.shared.additiveClipboard.toggle()
        rebuildMenu()
    }

    // MARK: - Module 1 Actions (Text & URL Cleaner)

    @objc private func toggleAutoCleanClipboard() {
        AppSettings.shared.autoCleanClipboard.toggle()
        TextCleanerService.shared.syncMonitoringState()
        let active = AppSettings.shared.autoCleanClipboard
        HUDToast.shared.show(
            title: active
                ? L10n.tr("Auto-Cleaner Enabled", "Limpiador automático activado")
                : L10n.tr("Auto-Cleaner Disabled", "Limpiador automático desactivado"),
            subtitle: active
                ? L10n.tr("Copied text & URLs (⌘C) will be cleaned automatically", "Todo texto o URL copiada (⌘C) se limpiará al instante")
                : L10n.tr("Manual cleaning remains available in the menu", "Modo manual disponible desde el menú")
        )
        rebuildMenu()
    }

    @objc private func toggleStripURLTrackers() {
        AppSettings.shared.stripURLTrackers.toggle()
        rebuildMenu()
    }

    @objc private func cleanClipboardNowAction() {
        TextCleanerService.shared.cleanClipboardNow(collapseSpaces: false)
        rebuildMenu()
    }

    @objc private func collapseSpacesNowAction() {
        TextCleanerService.shared.cleanClipboardNow(collapseSpaces: true)
        rebuildMenu()
    }

    @objc private func transformUpperAction() {
        TextCleanerService.shared.transformClipboardCase(.uppercase)
        rebuildMenu()
    }

    @objc private func transformLowerAction() {
        TextCleanerService.shared.transformClipboardCase(.lowercase)
        rebuildMenu()
    }

    @objc private func transformTitleAction() {
        TextCleanerService.shared.transformClipboardCase(.titleCase)
        rebuildMenu()
    }

    @objc private func transformSentenceAction() {
        TextCleanerService.shared.transformClipboardCase(.sentenceCase)
        rebuildMenu()
    }

    // MARK: - Module 2 Actions (Screenshot Organizer)

    @objc private func toggleAutoOrganizeScreenshots() {
        AppSettings.shared.autoOrganizeScreenshots.toggle()
        ScreenshotOrganizerService.shared.syncMonitoringState()
        let active = AppSettings.shared.autoOrganizeScreenshots
        let watchedName = (AppSettings.shared.watchedScreenshotsPath as NSString).lastPathComponent
        HUDToast.shared.show(
            title: active
                ? L10n.tr("Screenshot Organizer Enabled", "Organizador de capturas activado")
                : L10n.tr("Screenshot Organizer Disabled", "Organizador de capturas desactivado"),
            subtitle: active
                ? L10n.tr("Watching new screenshots in \(watchedName)", "Vigilando nuevas capturas en \(watchedName)")
                : L10n.tr("Manual mode remains available in the menu", "Modo manual disponible desde el menú")
        )
        rebuildMenu()
    }

    @objc private func organizeExistingScreenshotsNowAction() {
        ScreenshotOrganizerService.shared.organizeExistingScreenshotsNow()
    }

    @objc private func toggleMoveScreenshotsToFolder() {
        AppSettings.shared.moveScreenshotsToFolder.toggle()
        rebuildMenu()
    }

    @objc private func toggleOrganizeByCategorySubfolders() {
        AppSettings.shared.organizeByCategorySubfolders.toggle()
        rebuildMenu()
    }

    @objc private func chooseWatchedScreenshotsFolder() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = L10n.tr("Select your screenshots folder", "Seleccionar carpeta donde se guardan tus capturas de pantalla")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: AppSettings.shared.watchedScreenshotsPath)

        if panel.runModal() == .OK, let url = panel.url {
            AppSettings.shared.watchedScreenshotsPath = url.path
            ScreenshotOrganizerService.shared.syncMonitoringState()
            HUDToast.shared.show(
                title: L10n.tr("Watched Folder Updated", "Carpeta vigilada actualizada"),
                subtitle: url.path
            )
            rebuildMenu()
        }
    }

    @objc private func openOrganizedScreenshotsFolder() {
        let path = AppSettings.shared.organizedScreenshotsPath
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    // MARK: - Feedback, Language & Shortcut Actions

    @objc private func togglePlaySound() {
        AppSettings.shared.playSound.toggle()
        rebuildMenu()
    }

    @objc private func toggleShowHUD() {
        AppSettings.shared.showHUD.toggle()
        rebuildMenu()
    }

    @objc private func selectAppLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let lang = AppLanguage(rawValue: raw) else { return }
        AppSettings.shared.appLanguage = lang
        rebuildMenu()
        HUDToast.shared.show(
            title: L10n.tr("Language Updated", "Idioma actualizado"),
            subtitle: L10n.tr("Interface set to English", "Interfaz configurada en Español")
        )
    }

    @objc private func selectPresetHotKey(_ sender: NSMenuItem) {
        guard let combo = sender.representedObject as? HotKeyCombo else { return }
        AppSettings.shared.hotKey = combo
        HotKeyManager.shared.register(combo: combo)
        rebuildMenu()
        HUDToast.shared.show(
            title: L10n.tr("Shortcut Updated", "Atajo actualizado"),
            subtitle: L10n.tr("New shortcut: \(combo.displayString)", "Nuevo atajo: \(combo.displayString)")
        )
    }

    @objc private func openShortcutRecorder() {
        NSApp.activate(ignoringOtherApps: true)
        let window = ShortcutRecorderWindow(currentCombo: AppSettings.shared.hotKey)
        window.onShortcutRecorded = { [weak self] newCombo in
            AppSettings.shared.hotKey = newCombo
            HotKeyManager.shared.register(combo: newCombo)
            self?.rebuildMenu()
            HUDToast.shared.show(
                title: L10n.tr("Shortcut Updated", "Atajo actualizado"),
                subtitle: L10n.tr("New shortcut: \(newCombo.displayString)", "Nuevo atajo: \(newCombo.displayString)")
            )
        }
        window.makeKeyAndOrderFront(nil)
        self.recorderWindow = window
    }

    @objc private func openScreenCaptureSettings() {
        _ = CGRequestScreenCaptureAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openAboutPanel() {
        NSApp.activate(ignoringOtherApps: true)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 3

        let creditsText = L10n.tr(
            """
            Native Screen OCR, QR Scanner, Plain Text/URL Cleaner & Smart Screenshot Organizer for macOS.
            100% Offline • Powered by Apple Vision

            Architecture: Universal Binary (Intel x86_64 & Apple Silicon arm64)
            License: MIT License (Open Source)
            Author: Daniel Ordoñez
            GitHub: https://github.com/danielord/SnipText
            """,
            """
            Herramienta nativa de OCR, lector QR, limpiador de portapapeles y organizador inteligente de capturas para macOS.
            100% Offline • Impulsado por Apple Vision

            Arquitectura: Universal Binary (Intel x86_64 & Apple Silicon arm64)
            Licencia: MIT License (Open Source)
            Autor: Daniel Ordoñez
            GitHub: https://github.com/danielord/SnipText
            """
        )

        let attributedCredits = NSAttributedString(
            string: creditsText,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11.5),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraph
            ]
        )

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "SnipText",
            .applicationVersion: "1.1.0 (Universal)",
            .version: "Build 3",
            .credits: attributedCredits,
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "Copyright © 2026 Daniel Ordoñez • MIT License (Open Source)"
        ])
    }
}
