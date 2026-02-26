@echo off
echo Building Zarori Sawal with API keys...

:: Build Universal APK (default is single APK for all architectures)
echo [1/2] Building Universal APK...
flutter build apk --release --dart-define=GEMINI_API_KEY=AIzaSyCq5eW6NhmL-4w_rkI9aQTY-WedFUZpPc0 --dart-define=YOUTUBE_API_KEY=AIzaSyAbHbvlTW2ykEP0VZZzQDBEsj3Sl2xjVyk

:: Build App Bundle
echo [2/2] Building App Bundle...
flutter build appbundle --release --dart-define=GEMINI_API_KEY=AIzaSyCq5eW6NhmL-4w_rkI9aQTY-WedFUZpPc0 --dart-define=YOUTUBE_API_KEY=AIzaSyAbHbvlTW2ykEP0VZZzQDBEsj3Sl2xjVyk

echo.
echo Build complete!
echo APK: build\app\outputs\flutter-apk\app-release.apk
echo AAB: build\app\outputs\bundle\release\app-release.aab
pause
