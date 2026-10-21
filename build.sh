#!/bin/zsh
set -e

APP_NAME="SnipText"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
MODULE_CACHE="/tmp/swift-module-cache"
BUILD_TMP="/tmp/sniptext_universal_build_$$"

mkdir -p "${MODULE_CACHE}" "${BUILD_TMP}"
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp Info.plist "${CONTENTS_DIR}/Info.plist"

SOURCES=(
    Sources/Models.swift
    Sources/HotKeyManager.swift
    Sources/HUDToast.swift
    Sources/TextCleanerService.swift
    Sources/ScreenshotOrganizerService.swift
    Sources/OCRService.swift
    Sources/AppDelegate.swift
    Sources/main.swift
)

echo "🔨 [1/5] Compilando ${APP_NAME} para Mac Intel (x86_64)..."
swiftc \
    -module-cache-path "${MODULE_CACHE}" \
    -O \
    -target x86_64-apple-macosx13.0 \
    -framework Cocoa \
    -framework Vision \
    -framework Carbon \
    "${SOURCES[@]}" \
    -o "${BUILD_TMP}/${APP_NAME}_x86_64"

echo "🔨 [2/5] Compilando ${APP_NAME} para Apple Silicon (arm64)..."
swiftc \
    -module-cache-path "${MODULE_CACHE}" \
    -O \
    -target arm64-apple-macosx13.0 \
    -framework Cocoa \
    -framework Vision \
    -framework Carbon \
    "${SOURCES[@]}" \
    -o "${BUILD_TMP}/${APP_NAME}_arm64"

echo "🧬 [3/5] Creando Universal Binary (x86_64 + arm64) con lipo..."
lipo -create \
    "${BUILD_TMP}/${APP_NAME}_x86_64" \
    "${BUILD_TMP}/${APP_NAME}_arm64" \
    -output "${MACOS_DIR}/${APP_NAME}"

echo "🎨 [4/5] Generando AppIcon.icns con gráficos vectoriales 100% propios..."
ICONSET_DIR="${BUILD_TMP}/AppIcon.iconset"
mkdir -p "${ICONSET_DIR}"

cat << 'EOF' > "${BUILD_TMP}/gen_icon.swift"
import Cocoa

let iconsetPath = CommandLine.arguments[1]
let sizes = [16, 32, 64, 128, 256, 512, 1024]

for size in sizes {
    let s = CGFloat(size)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus()
        continue
    }

    // 1. Rounded squircle background
    let inset = s * 0.06
    let bgRect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let cornerRadius = s * 0.225
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.07, green: 0.52, blue: 0.96, alpha: 1.0),
        NSColor(calibratedRed: 0.04, green: 0.20, blue: 0.52, alpha: 1.0)
    ])
    gradient?.draw(in: bgPath, angle: -50)

    NSColor(calibratedWhite: 1.0, alpha: 0.18).setStroke()
    bgPath.lineWidth = max(1.0, s * 0.012)
    bgPath.stroke()

    // 2. Custom vector viewfinder corner brackets (no SF Symbols)
    let vfInset = s * 0.21
    let vfMin = vfInset
    let vfMax = s - vfInset
    let arm = s * 0.14
    let r = s * 0.045
    let strokeWidth = max(1.5, s * 0.045)

    ctx.saveGState()
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.96))
    ctx.setLineWidth(strokeWidth)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // Top-Left bracket
    ctx.move(to: CGPoint(x: vfMin, y: vfMax - arm))
    ctx.addArc(tangent1End: CGPoint(x: vfMin, y: vfMax), tangent2End: CGPoint(x: vfMin + arm, y: vfMax), radius: r)
    ctx.addLine(to: CGPoint(x: vfMin + arm, y: vfMax))

    // Top-Right bracket
    ctx.move(to: CGPoint(x: vfMax - arm, y: vfMax))
    ctx.addArc(tangent1End: CGPoint(x: vfMax, y: vfMax), tangent2End: CGPoint(x: vfMax, y: vfMax - arm), radius: r)
    ctx.addLine(to: CGPoint(x: vfMax, y: vfMax - arm))

    // Bottom-Left bracket
    ctx.move(to: CGPoint(x: vfMin, y: vfMin + arm))
    ctx.addArc(tangent1End: CGPoint(x: vfMin, y: vfMin), tangent2End: CGPoint(x: vfMin + arm, y: vfMin), radius: r)
    ctx.addLine(to: CGPoint(x: vfMin + arm, y: vfMin))

    // Bottom-Right bracket
    ctx.move(to: CGPoint(x: vfMax - arm, y: vfMin))
    ctx.addArc(tangent1End: CGPoint(x: vfMax, y: vfMin), tangent2End: CGPoint(x: vfMax, y: vfMin + arm), radius: r)
    ctx.addLine(to: CGPoint(x: vfMax, y: vfMin + arm))

    ctx.strokePath()
    ctx.restoreGState()

    // 3. Custom vector text bars inside the viewfinder + cyan scan beam
    let barHeight = max(1.5, s * 0.048)
    let barRadius = barHeight / 2
    let leftX = s * 0.31

    let bar1 = NSBezierPath(
        roundedRect: NSRect(x: leftX, y: s * 0.58, width: s * 0.38, height: barHeight),
        xRadius: barRadius,
        yRadius: barRadius
    )
    NSColor(calibratedWhite: 1.0, alpha: 0.95).setFill()
    bar1.fill()

    let bar2 = NSBezierPath(
        roundedRect: NSRect(x: leftX, y: s * 0.475, width: s * 0.28, height: barHeight),
        xRadius: barRadius,
        yRadius: barRadius
    )
    NSColor(calibratedWhite: 1.0, alpha: 0.90).setFill()
    bar2.fill()

    let bar3 = NSBezierPath(
        roundedRect: NSRect(x: leftX, y: s * 0.37, width: s * 0.33, height: barHeight),
        xRadius: barRadius,
        yRadius: barRadius
    )
    NSColor(calibratedWhite: 1.0, alpha: 0.82).setFill()
    bar3.fill()

    let scanY = s * 0.525
    let scanHeight = max(1.5, s * 0.024)
    let scanRect = NSRect(x: s * 0.17, y: scanY, width: s * 0.66, height: scanHeight)
    let scanPath = NSBezierPath(roundedRect: scanRect, xRadius: scanHeight / 2, yRadius: scanHeight / 2)
    NSColor(calibratedRed: 0.25, green: 0.95, blue: 1.0, alpha: 0.95).setFill()
    scanPath.fill()

    img.unlockFocus()

    if let tiff = img.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        if size <= 512 {
            try? png.write(to: URL(fileURLWithPath: "\(iconsetPath)/icon_\(size)x\(size).png"))
        }
        if size >= 32 {
            let half = size / 2
            try? png.write(to: URL(fileURLWithPath: "\(iconsetPath)/icon_\(half)x\(half)@2x.png"))
        }
    }
}
EOF

swiftc -module-cache-path "${MODULE_CACHE}" -target x86_64-apple-macosx13.0 -framework Cocoa "${BUILD_TMP}/gen_icon.swift" -o "${BUILD_TMP}/gen_icon"
"${BUILD_TMP}/gen_icon" "${ICONSET_DIR}"
iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns"

echo "🔏 Firmando paquete de aplicación (ad-hoc)..."
codesign --force --deep --sign - "${BUNDLE_DIR}"

echo "📦 [5/5] Empaquetando instaladores (.zip y .dmg Universal)..."
rm -f "${APP_NAME}-Universal.zip" "${APP_NAME}-Universal.dmg"
ditto -c -k --keepParent "${BUNDLE_DIR}" "${APP_NAME}-Universal.zip"

DMG_STAGING="${BUILD_TMP}/dmg_staging"
mkdir -p "${DMG_STAGING}"
cp -R "${BUNDLE_DIR}" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_STAGING}" \
    -ov \
    -format UDZO \
    "${APP_NAME}-Universal.dmg" >/dev/null || true

rm -rf "${BUILD_TMP}"

echo "✅ ¡Listo! ${BUNDLE_DIR} compilado y empaquetado exitosamente:"
lipo -archs "${MACOS_DIR}/${APP_NAME}"
ls -lh "${APP_NAME}-Universal.zip" "${APP_NAME}-Universal.dmg" 2>/dev/null || true
