#!/bin/sh
# Compila StaiN en Release y lo empaqueta para distribuir en dist/:
#   - StaiN-X.Y.Z.dmg: la app, un acceso a Aplicaciones y las instrucciones del primer arranque.
#   - StaiN-X.Y.Z.zip: la app sola (útil para un cask de Homebrew).
#   - Un .sha256 de cada archivo.
# Usa solo herramientas de macOS (xcodebuild, hdiutil, ditto); no firma con Developer ID
# ni notariza (el proyecto no tiene costes).
#
# Uso: ./scripts/package-dmg.sh
set -eu
cd "$(dirname "$0")/.."

xcodebuild -project StaiN.xcodeproj -scheme StaiN -configuration Release -derivedDataPath build \
    -destination "generic/platform=macOS" ONLY_ACTIVE_ARCH=NO \
    -quiet build
app="build/Build/Products/Release/StaiN.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")
codesign --verify --deep --strict "$app"

mkdir -p dist
dmg="dist/StaiN-$version.dmg"
zip="dist/StaiN-$version.zip"
rm -f "$dmg" "$zip" "$dmg.sha256" "$zip.sha256"

# Contenido del disco: la app, un acceso directo a /Applications y las instrucciones.
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/StaiN.app"
ln -s /Applications "$staging/Aplicaciones"
cp docs/primer-arranque.txt "$staging/Cómo abrir StaiN.txt"

hdiutil create -quiet -volname "StaiN $version" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$dmg"
hdiutil verify -quiet "$dmg"
ditto -c -k --keepParent "$app" "$zip"

(cd dist && shasum -a 256 "$(basename "$dmg")" > "$(basename "$dmg").sha256" \
    && shasum -a 256 "$(basename "$zip")" > "$(basename "$zip").sha256")
echo "StaiN $version (compilación $build):"
ls -lh "$dmg" "$zip" | awk '{print "  " $5 "\t" $9}'
