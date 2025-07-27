# Eden Updater

A cross-platform GUI updater for the Eden emulator. Keep your Eden installation up to date with automatic downloads and installations.

<img width="1251" height="699" alt="image" src="https://github.com/user-attachments/assets/aaa162d0-7d98-41f8-9cbb-5768aa943940" />


## Features

- Automatic update checking from GitHub releases
- Cross-platform support (Windows, Linux, Android)
- Support for both stable and nightly channels
- Direct Eden launching
- Modern dark theme interface

## Download

You can get the latest release from here: [Release](https://github.com/AtakanSevimli1/Eden-Updater/releases/latest)

## Building

### Prerequisites
- Flutter SDK
- Platform tools (Visual Studio for Windows, build-essential for Linux, Android SDK)

### Package for Distribution
```bash
.\package_windows.ps1   # Windows ZIP
.\package_linux.sh     # Linux tar.gz  
.\package_android.ps1   # Android APK
```

### Development Build
```bash
flutter build windows --release
flutter build linux --release
flutter build apk --release
```

## Usage

1. Extract and run the updater
2. Select stable or nightly channel
3. Click "Install Eden" or "Update Eden"
4. Launch Eden directly from the updater

### Command Line
```bash
eden_updater.exe --auto-launch --channel nightly
```

Eden installs to `Documents/Eden/` with separate folders for stable and nightly versions.

## Release Sources

- **Stable**: [eden-emulator/Releases](https://github.com/eden-emulator/Releases/releases)
- **Nightly**: [pflyly/eden-nightly](https://github.com/pflyly/eden-nightly/releases)

## Development

```bash
flutter run -d windows    # Run on Windows
flutter run -d linux      # Run on Linux
flutter run -d android    # Run on Android
flutter analyze           # Check code
```

## License

This project is open source. See LICENSE file for details.
