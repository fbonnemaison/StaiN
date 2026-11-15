#!/bin/sh
# Compila StaiN en Release y lo instala en /Applications (sustituye la versión anterior).
# Uso: ./scripts/install.sh
set -eu
cd "$(dirname "$0")/.."

xcodebuild -project StaiN.xcodeproj -scheme StaiN -configuration Release -derivedDataPath build \
    -quiet build
app="build/Build/Products/Release/StaiN.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")

# Cierra StaiN si está abierto (macOS pregunta por los cambios sin guardar).
osascript -e 'if application id "io.github.fbonnemaison.StaiN" is running then tell application id "io.github.fbonnemaison.StaiN" to quit' || true
sleep 1

rm -rf /Applications/StaiN.app
ditto "$app" /Applications/StaiN.app
# Que Launch Services y el Dock tomen el icono y los tipos de documento nuevos.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/StaiN.app
echo "StaiN $version (compilación $build) instalado en /Applications/StaiN.app"
