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
            button.toolTip = "SnipText — Capturar texto en pantalla (\(AppSettings.shared.hotKey.displayString))"
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
        statusItem.button?.toolTip = "SnipText — Capturar texto (\(currentHotKey.displayString))"

        // 1. Primary Capture Action
        let captureItem = NSMenuItem(
            title: "Capturar Texto en Pantalla",
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
            let headerItem = NSMenuItem(title: "Última captura (clic para copiar):", action: nil, keyEquivalent: "")
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
            let historySubmenu = NSMenu(title: "Historial Reciente")
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
            let clearItem = NSMenuItem(title: "Borrar Historial", action: #selector(clearHistoryAction), keyEquivalent: "")
            clearItem.target = self
            historySubmenu.addItem(clearItem)

            let historyRoot = NSMenuItem(title: "Historial Reciente (\(history.count))", action: nil, keyEquivalent: "")
            if let clockIcon = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil) {
                historyRoot.image = clockIcon
            }
            historyRoot.submenu = historySubmenu
            statusMenu.addItem(historyRoot)
        } else {
            let emptyItem = NSMenuItem(title: "Sin capturas recientes", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            statusMenu.addItem(emptyItem)
        }

        statusMenu.addItem(.separator())

        // 3. MODULE 1: Limpiador de Texto y URLs (Paste Plain Text Pro)
        let cleanerSubmenu = NSMenu(title: "Limpiador de Texto y URLs")

        let autoCleanItem = NSMenuItem(
            title: "Módulo activo: Limpiar automáticamente al copiar (⌘C)",
            action: #selector(toggleAutoCleanClipboard),
            keyEquivalent: ""
        )
        autoCleanItem.target = self
        autoCleanItem.state = AppSettings.shared.autoCleanClipboard ? .on : .off
        cleanerSubmenu.addItem(autoCleanItem)

        let stripTrackersItem = NSMenuItem(
            title: "Quitar rastreadores de URLs (utm_, fbclid, gclid, si…)",
            action: #selector(toggleStripURLTrackers),
            keyEquivalent: ""
        )
        stripTrackersItem.target = self
        stripTrackersItem.state = AppSettings.shared.stripURLTrackers ? .on : .off
        cleanerSubmenu.addItem(stripTrackersItem)

        cleanerSubmenu.addItem(.separator())

        let cleanNowItem = NSMenuItem(
            title: "⚡ Limpiar portapapeles actual ahora (Texto plano + URL)",
            action: #selector(cleanClipboardNowAction),
            keyEquivalent: ""
        )
        cleanNowItem.target = self
        cleanerSubmenu.addItem(cleanNowItem)

        let collapseSpacesItem = NSMenuItem(
            title: "⚡ Quitar espacios dobles y líneas vacías",
            action: #selector(collapseSpacesNowAction),
            keyEquivalent: ""
        )
        collapseSpacesItem.target = self
        cleanerSubmenu.addItem(collapseSpacesItem)

        cleanerSubmenu.addItem(.separator())

        let upperItem = NSMenuItem(title: "Transformar a MAYÚSCULAS", action: #selector(transformUpperAction), keyEquivalent: "")
        upperItem.target = self
        cleanerSubmenu.addItem(upperItem)

        let lowerItem = NSMenuItem(title: "Transformar a minúsculas", action: #selector(transformLowerAction), keyEquivalent: "")
        lowerItem.target = self
        cleanerSubmenu.addItem(lowerItem)

        let titleCaseItem = NSMenuItem(title: "Transformar a Tipo Título", action: #selector(transformTitleAction), keyEquivalent: "")
        titleCaseItem.target = self
        cleanerSubmenu.addItem(titleCaseItem)

        let sentenceCaseItem = NSMenuItem(title: "Transformar a Tipo Oración", action: #selector(transformSentenceAction), keyEquivalent: "")
        sentenceCaseItem.target = self
        cleanerSubmenu.addItem(sentenceCaseItem)

        let cleanerStatus = AppSettings.shared.autoCleanClipboard ? "Activo" : "Manual"
        let cleanerRoot = NSMenuItem(title: "Limpiador de Texto y URLs (\(cleanerStatus))", action: nil, keyEquivalent: "")
        if let wandIcon = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: nil) {
            cleanerRoot.image = wandIcon
        }
        cleanerRoot.submenu = cleanerSubmenu
        statusMenu.addItem(cleanerRoot)

        // 4. MODULE 2: Organizador Automatizado de Capturas de Pantalla
        let organizerSubmenu = NSMenu(title: "Organizador de Capturas")

        let autoOrgItem = NSMenuItem(
            title: "Módulo activo: Auto-renombrar y organizar nuevas capturas",
            action: #selector(toggleAutoOrganizeScreenshots),
            keyEquivalent: ""
        )
        autoOrgItem.target = self
        autoOrgItem.state = AppSettings.shared.autoOrganizeScreenshots ? .on : .off
        organizerSubmenu.addItem(autoOrgItem)

        let organizeNowItem = NSMenuItem(
            title: "⚡ Organizar capturas existentes ahora",
            action: #selector(organizeExistingScreenshotsNowAction),
            keyEquivalent: ""
        )
        organizeNowItem.target = self
        organizerSubmenu.addItem(organizeNowItem)

        organizerSubmenu.addItem(.separator())

        let moveFolderItem = NSMenuItem(
            title: "Mover a carpeta ~/Pictures/SnipText Capturas",
            action: #selector(toggleMoveScreenshotsToFolder),
            keyEquivalent: ""
        )
        moveFolderItem.target = self
        moveFolderItem.state = AppSettings.shared.moveScreenshotsToFolder ? .on : .off
        organizerSubmenu.addItem(moveFolderItem)

        let categorySubfolderItem = NSMenuItem(
            title: "Clasificar en subcarpetas (Recibos, Código, Web…)",
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
            title: "Carpeta vigilada: \(watchedFolderName) (Cambiar…)",
            action: #selector(chooseWatchedScreenshotsFolder),
            keyEquivalent: ""
        )
        chooseWatchedItem.target = self
        organizerSubmenu.addItem(chooseWatchedItem)

        let openOrganizedItem = NSMenuItem(
            title: "Abrir carpeta de capturas organizadas",
            action: #selector(openOrganizedScreenshotsFolder),
            keyEquivalent: ""
        )
        openOrganizedItem.target = self
        organizerSubmenu.addItem(openOrganizedItem)

        let organizerStatus = AppSettings.shared.autoOrganizeScreenshots ? "Activo" : "Manual"
        let organizerRoot = NSMenuItem(title: "Organizador de Capturas (\(organizerStatus))", action: nil, keyEquivalent: "")
        if let folderIcon = NSImage(systemSymbolName: "folder.badge.gearshape", accessibilityDescription: nil) {
            organizerRoot.image = folderIcon
        }
        organizerRoot.submenu = organizerSubmenu
        statusMenu.addItem(organizerRoot)

        statusMenu.addItem(.separator())

        // 5. OCR & Clipboard Toggles
        let lineBreaksItem = NSMenuItem(
            title: "Mantener saltos de línea en OCR",
            action: #selector(toggleKeepLineBreaks),
            keyEquivalent: ""
        )
        lineBreaksItem.target = self
        lineBreaksItem.state = AppSettings.shared.keepLineBreaks ? .on : .off
        statusMenu.addItem(lineBreaksItem)

        let barcodeItem = NSMenuItem(
            title: "Leer códigos QR y de barras",
            action: #selector(toggleDetectBarcodes),
            keyEquivalent: ""
        )
        barcodeItem.target = self
        barcodeItem.state = AppSettings.shared.detectBarcodes ? .on : .off
        statusMenu.addItem(barcodeItem)

        let additiveItem = NSMenuItem(
            title: "Acumular texto en portapapeles",
            action: #selector(toggleAdditiveClipboard),
            keyEquivalent: ""
        )
        additiveItem.target = self
        additiveItem.state = AppSettings.shared.additiveClipboard ? .on : .off
        statusMenu.addItem(additiveItem)

        statusMenu.addItem(.separator())

        // 6. Feedback & Shortcut Configuration Submenu
        let prefsSubmenu = NSMenu(title: "Preferencias y Atajo")

        let soundItem = NSMenuItem(
            title: "Sonido sutil al copiar",
            action: #selector(togglePlaySound),
            keyEquivalent: ""
        )
        soundItem.target = self
        soundItem.state = AppSettings.shared.playSound ? .on : .off
        prefsSubmenu.addItem(soundItem)

        let hudItem = NSMenuItem(
            title: "Mostrar aviso flotante (HUD)",
            action: #selector(toggleShowHUD),
            keyEquivalent: ""
        )
        hudItem.target = self
        hudItem.state = AppSettings.shared.showHUD ? .on : .off
        prefsSubmenu.addItem(hudItem)

        prefsSubmenu.addItem(.separator())
        let shortcutHeader = NSMenuItem(title: "Atajo de Teclado Global:", action: nil, keyEquivalent: "")
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
            let customCurrent = NSMenuItem(title: "  Personalizado (\(currentHotKey.displayString))", action: nil, keyEquivalent: "")
            customCurrent.state = .on
            prefsSubmenu.addItem(customCurrent)
        }
        prefsSubmenu.addItem(.separator())
        let customRecorderItem = NSMenuItem(
            title: "Grabar atajo personalizado…",
            action: #selector(openShortcutRecorder),
            keyEquivalent: ""
        )
        customRecorderItem.target = self
        prefsSubmenu.addItem(customRecorderItem)

        let prefsRoot = NSMenuItem(
            title: "Atajo (\(currentHotKey.displayString)) y Avisos",
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
                title: "⚠️ Otorgar Permiso de Pantalla…",
                action: #selector(openScreenCaptureSettings),
                keyEquivalent: ""
            )
            permItem.target = self
            statusMenu.addItem(permItem)
        }

        statusMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Salir de SnipText",
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
        HUDToast.shared.show(title: "Copiado del historial", subtitle: text)
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
            title: active ? "Limpiador automático activado" : "Limpiador automático desactivado",
            subtitle: active ? "Todo texto o URL copiada (⌘C) se limpiará al instante" : "Modo manual disponible desde el menú"
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
            title: active ? "Organizador de capturas activado" : "Organizador de capturas desactivado",
            subtitle: active ? "Vigilando nuevas capturas en \(watchedName)" : "Modo manual disponible desde el menú"
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
        panel.title = "Seleccionar carpeta donde se guardan tus capturas de pantalla"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: AppSettings.shared.watchedScreenshotsPath)

        if panel.runModal() == .OK, let url = panel.url {
            AppSettings.shared.watchedScreenshotsPath = url.path
            ScreenshotOrganizerService.shared.syncMonitoringState()
            HUDToast.shared.show(
                title: "Carpeta vigilada actualizada",
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

    // MARK: - Feedback & Shortcut Actions

    @objc private func togglePlaySound() {
        AppSettings.shared.playSound.toggle()
        rebuildMenu()
    }

    @objc private func toggleShowHUD() {
        AppSettings.shared.showHUD.toggle()
        rebuildMenu()
    }

    @objc private func selectPresetHotKey(_ sender: NSMenuItem) {
        guard let combo = sender.representedObject as? HotKeyCombo else { return }
        AppSettings.shared.hotKey = combo
        HotKeyManager.shared.register(combo: combo)
        rebuildMenu()
        HUDToast.shared.show(title: "Atajo actualizado", subtitle: "Nuevo atajo: \(combo.displayString)")
    }

    @objc private func openShortcutRecorder() {
        NSApp.activate(ignoringOtherApps: true)
        let window = ShortcutRecorderWindow(currentCombo: AppSettings.shared.hotKey)
        window.onShortcutRecorded = { [weak self] newCombo in
            AppSettings.shared.hotKey = newCombo
            HotKeyManager.shared.register(combo: newCombo)
            self?.rebuildMenu()
            HUDToast.shared.show(title: "Atajo actualizado", subtitle: "Nuevo atajo: \(newCombo.displayString)")
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
}
