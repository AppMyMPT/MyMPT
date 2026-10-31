@echo off
echo ========================================================
echo   Building Release APK with R8 and Dart Obfuscation
echo ========================================================
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols %*

