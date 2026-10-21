# SnipText para macOS (Universal: Intel & Apple Silicon)

Aplicación nativa, ultraligera y Open Source para la barra de menú de macOS que extrae texto y códigos QR desde cualquier parte de la pantalla usando el motor **Vision** de Apple (100% offline), e incluye módulos opcionales para **limpiar texto/URLs en el portapapeles** y **organizar capturas de pantalla automáticamente mediante OCR**.

---

## Características Principales

### 1. Captura instantánea de Texto (OCR) y Códigos QR
- **Barra de menú nativa (`LSUIElement`)**: Corre silenciosamente en la barra superior sin ocupar espacio en el Dock.
- **Atajo de teclado global configurable**: Por defecto `⌘⇧2` (`Cmd + Shift + 2`), con opciones rápidas (`⌘⇧X`, `⌘⇧S`, `⌥⌘T`, `⌃⌥Espacio`) y grabador de atajos personalizados.
- **Motor OCR de alta precisión (Apple Vision)**: Reconocimiento automático de idioma (Español, Inglés, Portugués, Francés, Alemán, Italiano, etc.) 100% offline.
- **Lectura de códigos QR y de barras**: Detecta enlaces y códigos en pantalla automáticamente.
- **Historial reciente integrado**: Consulta y vuelve a copiar cualquiera de las últimas 15 capturas desde la barra de menú.

### 2. Módulo 1: Limpiador de Texto y URLs (*Paste Plain Text Pro*)
- **Modo Automático (activable/desactivable)**: Al copiar texto en cualquier aplicación (`⌘C`), elimina automáticamente formatos ocultos (RTF/HTML) y limpia parámetros de rastreo en enlaces (`utm_source`, `utm_medium`, `fbclid`, `gclid`, `si`, etc.).
- **Invocación Manual desde el Menú**:
  - Limpiar el portapapeles actual en un clic.
  - Eliminar espacios dobles y líneas vacías.
  - Transformar el texto copiado a `MAYÚSCULAS`, `minúsculas`, `Tipo Título` o `Tipo Oración`.

### 3. Módulo 2: Organizador Automatizado de Capturas de Pantalla con OCR
- **Modo Automático (activable/desactivable)**: Vigila tu carpeta de capturas (por defecto `~/Desktop`) y cuando tomas una captura de pantalla:
  1. Lee su contenido con Apple Vision OCR.
  2. La clasifica inteligentemente (`Recibos_y_Pagos`, `Codigo_y_Dev`, `Conversaciones`, `Web_y_Enlaces`, `General`).
  3. La renombra con palabras clave legibles y fecha (ej. `Recibo_Oxxo_Total_2026-10-21.png` o `Codigo_Swift_2026-10-21.png`).
  4. Opcionalmente la mueve a `~/Pictures/SnipText Capturas/` para mantener tu Escritorio limpio.
- **Invocación Manual desde el Menú**:
  - Botón **`⚡ Organizar capturas existentes ahora`** para ordenar bajo demanda todas las capturas acumuladas en tu Escritorio.

---

## Instalación

### Desde GitHub Releases (`.dmg` o `.zip`)
1. Descarga **`SnipText-Universal.dmg`** (o `SnipText-Universal.zip`) desde la sección **Releases**.
2. Abre el archivo `.dmg` y arrastra **`SnipText.app`** a la carpeta **`Applications`**.
3. Al ser una aplicación gratuita y Open Source sin certificado de pago de Apple, la primera vez que la abras en otra Mac ejecuta en Terminal:
   ```bash
   xattr -cr /Applications/SnipText.app
   ```
   *(O haz **Clic derecho sobre `SnipText.app` → Abrir**).*
4. Otorga el permiso de **Grabación de Pantalla** cuando el sistema lo solicite en `Configuración del Sistema > Privacidad y seguridad > Grabación de pantalla`.

### Compilar desde el código fuente
```bash
./build.sh
open SnipText.app
```

---

## Licencia
Distribuido bajo la licencia **MIT**. Consulta el archivo [`LICENSE`](LICENSE) para más detalles.
