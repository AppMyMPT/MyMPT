@echo off
echo ========================================================
echo   Building Release AppBundle with R8 and Dart Obfuscation
echo ========================================================
flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols %*

