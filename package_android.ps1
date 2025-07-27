Write-Host "Packaging Eden Updater for Android..." -ForegroundColor Green

# Clean previous builds
Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
flutter clean
flutter pub get

# Build the release version
Write-Host "Building release version..." -ForegroundColor Yellow
Write-Host "  - Using Flutter's built-in optimizations" -ForegroundColor Cyan

flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}

# Create package directory
$packageDir = "eden_updater_android"
if (Test-Path $packageDir) {
    Remove-Item $packageDir -Recurse -Force
}
New-Item -ItemType Directory -Path $packageDir | Out-Null

# Copy the APK file
Write-Host "Copying APK file..." -ForegroundColor Yellow
$sourceApk = "build\app\outputs\flutter-apk\app-release.apk"
$targetApk = "$packageDir\EdenUpdater.apk"

if (Test-Path $sourceApk) {
    Copy-Item $sourceApk $targetApk
} else {
    Write-Host "APK file not found at $sourceApk" -ForegroundColor Red
    exit 1
}

# Create a simple README
Write-Host "Creating README..." -ForegroundColor Yellow
$readmeContent = @"
Eden Updater - Android Version

Installation:
1. Enable "Unknown sources" in Android settings
2. Install EdenUpdater.apk
3. Launch Eden Updater from your app drawer

Features:
- Download and install Eden emulator updates
- Support for both stable and nightly channels
- Automatic update checking
- Material Design 3 interface optimized for mobile

Command line options (when launched via intent):
  --auto-launch    : Automatically launch Eden after update
  --channel stable : Use stable channel (default)
  --channel nightly: Use nightly channel

Note: This APK is unsigned. For production distribution,
consider signing it with your own certificate.

System Requirements:
- Android 5.0 (API level 21) or higher
- ARM64 or x86_64 processor
- At least 100MB free storage space
"@

$readmeContent | Out-File "$packageDir\README.txt" -Encoding UTF8

# Create installation instructions
$installContent = @"
# Android Installation Instructions

## Method 1: Direct Installation
1. Transfer EdenUpdater.apk to your Android device
2. Open the file manager on your device
3. Navigate to the APK file and tap it
4. If prompted, enable "Install from unknown sources"
5. Follow the installation prompts

## Method 2: ADB Installation (for developers)
1. Enable Developer Options and USB Debugging on your device
2. Connect your device to your computer
3. Run: adb install EdenUpdater.apk

## Troubleshooting
- If installation is blocked, go to Settings > Security > Unknown Sources and enable it
- On newer Android versions, you may need to enable installation for your file manager app
- Make sure you have enough storage space (at least 100MB free)

## Uninstallation
- Go to Settings > Apps > Eden Updater > Uninstall
- Or long-press the app icon and select "Uninstall"
"@

$installContent | Out-File "$packageDir\INSTALL.md" -Encoding UTF8

Write-Host ""
Write-Host "Package created successfully in $packageDir\" -ForegroundColor Green
Write-Host ""

# Show files included
Write-Host "Files included:" -ForegroundColor Yellow
Get-ChildItem $packageDir | ForEach-Object { 
    Write-Host "  $($_.Name)"
}

# Calculate APK size
if (Test-Path $targetApk) {
    $apkSize = (Get-Item $targetApk).Length
    $sizeInMB = [math]::Round($apkSize / 1MB, 2)
    Write-Host ""
    Write-Host "APK size: $sizeInMB MB ($apkSize bytes)" -ForegroundColor Cyan
}

# Show APK info
Write-Host ""
Write-Host "APK Information:" -ForegroundColor Yellow
Write-Host "  File: EdenUpdater.apk" -ForegroundColor Cyan
Write-Host "  Type: Android Application Package" -ForegroundColor Cyan
Write-Host "  Target: Android 5.0+ (API 21+)" -ForegroundColor Cyan
Write-Host "  Architecture: Universal (ARM64, x86_64)" -ForegroundColor Cyan
Write-Host "  NDK Version: 27.0.12077973" -ForegroundColor Cyan
Write-Host "  Optimizations: Flutter built-in optimizations" -ForegroundColor Cyan

# Show build optimizations applied
Write-Host ""
Write-Host "Build Optimizations Applied:" -ForegroundColor Yellow
Write-Host "  ✓ Flutter release mode optimizations" -ForegroundColor Green
Write-Host "  ✓ Tree-shaking (removes unused code)" -ForegroundColor Green
Write-Host "  ✓ Asset optimization" -ForegroundColor Green
Write-Host "  ✓ Dart AOT compilation" -ForegroundColor Green

Write-Host ""
Write-Host "Distribution Notes:" -ForegroundColor Yellow
Write-Host "  • APK is unsigned - suitable for testing and personal use" -ForegroundColor White
Write-Host "  • For Play Store distribution, additional steps are required" -ForegroundColor White
Write-Host "  • Users will need to enable 'Unknown sources' to install" -ForegroundColor White
Write-Host "  • Flutter release mode provides good optimization" -ForegroundColor White

Write-Host ""
Write-Host "Packaging complete!" -ForegroundColor Green