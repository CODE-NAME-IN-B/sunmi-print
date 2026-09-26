# SunmiPrint - Professional Thermal Printer App

A professional thermal printer companion app for Sunmi devices, built as a RawBT alternative using Flutter.

## Features

- **Multi-format printing**: Print images (JPG, PNG) and PDF files
- **Receipt editor**: Create custom receipts with text, images, QR codes, barcodes, and separators
- **Bluetooth discovery**: Scan and connect to Bluetooth thermal printers
- **Print queue**: Manage multiple print jobs with retry and cancellation
- **Settings**: Configure paper width (58mm/80mm), DPI, dithering, auto-cut, and more
- **Arabic RTL UI**: Full Arabic language support with right-to-left layout
- **Print history**: View completed, failed, and cancelled print jobs

## Requirements

- Android SDK 24+ (Android 7.0+)
- Sunmi device recommended (for built-in printer support)
- Flutter 3.0+

## Getting Started

```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Build release APK
flutter build apk --release
```

## Configuration

### Keystore (for release builds)

Set environment variables or create a `keystore.jks` file in the `android/app/` directory:

```bash
export KEYSTORE_PATH=/path/to/keystore.jks
export KEYSTORE_PASSWORD=your_password
export KEY_ALIAS=your_alias
export KEY_PASSWORD=your_key_password
```

### Printer Settings

- **58mm paper**: 384px width
- **80mm paper**: 576px width
- **PDF DPI**: Default 203 DPI (adjustable)
- **Dithering**: Floyd-Steinberg error diffusion for better print quality

## Project Structure

```
lib/
├── main.dart                    # Entry point
├── app.dart                     # MaterialApp with routes and theme
├── l10n/                        # Localization files
├── core/
│   ├── constants/               # App constants
│   └── utils/                   # Image processing, PDF rendering
├── models/                      # Data models (PrintJob, PrinterSettings)
├── providers/                   # Riverpod state providers
├── screens/                     # UI screens
│   ├── home_screen.dart
│   ├── preview_screen.dart
│   ├── receipt_editor_screen.dart
│   ├── bluetooth_discovery_screen.dart
│   ├── print_queue_screen.dart
│   ├── print_history_screen.dart
│   ├── settings_screen.dart
│   └── about_screen.dart
└── services/                    # Business logic
    ├── printer_service.dart     # Printer wrapper
    ├── print_queue_service.dart # Queue management
    └── update_service.dart      # Update checker
```

## License

Private project - All rights reserved.
