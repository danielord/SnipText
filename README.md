# SnipText for macOS

![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B-blue)
![Architecture](https://img.shields.io/badge/Architecture-Universal%20(Intel%20%26%20Apple%20Silicon)-success)
![Swift](https://img.shields.io/badge/Swift-AppKit%20%2B%20Vision-orange)
![Privacy](https://img.shields.io/badge/Privacy-100%25%20Offline-brightgreen)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

**SnipText** is an ultra-lightweight, 100% offline, open-source macOS Menu Bar utility that extracts uncopyable text and QR/barcodes from anywhere on your screen using Apple's native **Vision** framework — plus two built-in productivity modules: a **Plain Text & URL Tracker Cleaner** and an **Automated OCR Screenshot Organizer**.

*[Leer en Español más abajo](#-español)*

---

## ✨ Why SnipText?

Unlike paid, closed-source alternatives (like TextSniper):
- 🔒 **100% Private & Auditable**: Zero network calls, zero telemetry, ~1,200 lines of clean native Swift.
- ⚡ **Ultra-Lightweight Universal Binary**: Runs natively on both **Intel (`x86_64`)** and **Apple Silicon (`arm64` — M1/M2/M3/M4)** with near-zero RAM/CPU footprint.
- 🧹 **3-in-1 Workflow**: Screen OCR + Clipboard URL/Format Cleaner + Smart Screenshot Organizer in a single menu bar icon.

---

## 🚀 Key Features

### 1. Instant Screen OCR & QR / Barcode Scanner
- **Global Keyboard Shortcut**: Default `⌘⇧2` (`Cmd + Shift + 2`), with quick presets (`⌘⇧X`, `⌘⇧S`, `⌥⌘T`, `⌃⌥Space`) and a custom shortcut recorder.
- **High-Accuracy Apple Vision OCR**: Automatic language detection (`English`, `Spanish`, `Portuguese`, `French`, `German`, `Italian`, etc.) with language correction completely offline.
- **QR & Barcode Reader**: Automatically decodes QR codes and barcodes on screen and copies their payload.
- **Recent History**: Access and re-copy any of your last **15 captures** directly from the menu bar.
- **Line Breaks & Additive Clipboard**: Toggle whether to preserve line breaks or join paragraphs, and optionally append consecutive captures into the clipboard.

### 2. Module 1: Paste Plain Text & URL Cleaner *(Toggleable & Manual)*
- **Automatic Mode (Optional)**: Watches your clipboard with zero CPU overhead (`NSPasteboard.changeCount`). Whenever you copy text (`⌘C`), it automatically strips rich formatting (RTF/HTML) and removes tracking parameters from URLs (`utm_source`, `utm_medium`, `fbclid`, `gclid`, `si`, `igshid`, etc.).
- **One-Click Manual Actions**:
  - Clean current clipboard now (Plain text + strip URL trackers).
  - Collapse multiple spaces and empty lines.
  - Transform clipboard text to `UPPERCASE`, `lowercase`, `Title Case`, or `Sentence case`.

### 3. Module 2: Automated OCR Screenshot Organizer *(Toggleable & Manual)*
- **Automatic Mode (Optional)**: Watches your screenshots folder (default `~/Desktop`). Whenever you take a macOS screenshot:
  1. Reads the text inside the image using Apple Vision OCR.
  2. Classifies it (`Recibos_y_Pagos`, `Codigo_y_Dev`, `Conversaciones`, `Web_y_Enlaces`, `General`).
  3. Renames it with meaningful keywords and date (e.g., `Recibo_Oxxo_Total_2026-10-21.png` or `Codigo_Swift_AppDelegate_2026-10-21.png`).
  4. Optionally moves it into `~/Pictures/SnipText Capturas/` to keep your Desktop clutter-free.
- **Manual One-Click Action**:
  - Click **`⚡ Organizar capturas existentes ahora`** to batch-organize all existing screenshots on your Desktop on demand.

---

## 📦 Installation

### Option A: Download Pre-built Release (`.zip` / `.dmg`)
1. Go to the **[Releases](../../releases)** section on the right side of this GitHub page.
2. Download **`SnipText-Universal.zip`** (or `SnipText-Universal.dmg`).
3. Move **`SnipText.app`** to your `/Applications` folder.
4. Since this is a free open-source app signed locally without a paid Apple Developer ID, run this command once in Terminal before opening (or **Right-Click `SnipText.app` → Open**):
   ```bash
   xattr -cr /Applications/SnipText.app
   open /Applications/SnipText.app
   ```
5. Grant **Screen Recording** permission when prompted in `System Settings > Privacy & Security > Screen Recording`.

### Option B: Build from Source
```bash
git clone https://github.com/danielord/SnipText.git
cd SnipText
./build.sh
open SnipText.app
```

---

## 🇪🇸 Español

**SnipText** es una aplicación nativa, ultraligera y Open Source para la barra de menú de macOS (Universal: **Mac Intel y Apple Silicon**) que extrae texto y códigos QR desde cualquier parte de la pantalla usando el motor **Vision** de Apple (100% offline).

### Funciones incluidas:
1. **Captura de Texto (OCR) y Códigos QR (`⌘⇧2`)**: Reconocimiento multilingüe offline, historial de las últimas 15 capturas, control de saltos de línea, aviso flotante (HUD) y ventana *"Acerca de SnipText"* con información de versión y licencia.
2. **Módulo 1 — Limpiador de Texto y URLs**: Modo automático o manual para eliminar formatos ocultos (RTF/HTML), borrar rastreadores de enlaces (`utm_`, `fbclid`, `gclid`, `si`) y transformar mayúsculas/minúsculas.
3. **Módulo 2 — Organizador de Capturas con OCR**: Modo automático o manual que lee el texto dentro de tus capturas de pantalla, las renombra inteligentemente (ej. `Recibo_Oxxo_2026-10-21.png`) y las organiza en carpetas.

---

## 📄 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for more information.
Created by **Daniel Ordoñez**.
