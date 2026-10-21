# Security Policy

## Supported Versions

Currently supported versions of **SnipText** with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.1.x   | :white_check_mark: |
| 1.0.x   | :white_check_mark: |

## Privacy & Security Architecture

- **100% Offline**: SnipText does not make any network requests, does not include any third-party analytics/telemetry SDKs, and processes all OCR and barcode recognition locally on-device using Apple's native `Vision` framework.
- **Permissions**: SnipText only requests macOS **Screen Recording** permission (`CGRequestScreenCaptureAccess`) to capture user-selected screen regions for text/barcode extraction.

## Reporting a Vulnerability

If you discover a security vulnerability within SnipText, please report it by opening a [GitHub Issue](https://github.com/danielord/SnipText/issues) or via GitHub's private vulnerability reporting feature in the **Security** tab of this repository. All reports will be reviewed promptly.
