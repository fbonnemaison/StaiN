# StaiN

Editor de imágenes raster sencillo para macOS, inspirado en Microsoft Paint (antes Paintbrush) y MacPaint.
Escrito en Swift, open source (MIT).

> Estado: en desarrollo temprano. Consulta el plan en [TODO.md](TODO.md).

## Requisitos

- macOS 26 o superior
- Xcode 27 o superior

## Estructura

```
StaiN/                 App macOS (SwiftUI + lienzo AppKit)
StaiNUITests/          Tests de interfaz (XCUITest)
Packages/StainKit/     Motor de dibujo, sin UI ni dependencias
project.yml            Definición del proyecto para XcodeGen
```

## Compilar

Abre `StaiN.xcodeproj` en Xcode y ejecuta el esquema **StaiN**, o desde la terminal:

```bash
xcodebuild -project StaiN.xcodeproj -scheme StaiN -destination 'platform=macOS' build
```

Tests del motor:

```bash
swift test --package-path Packages/StainKit
```

Si modificas `project.yml`, regenera el proyecto con [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
xcodegen generate
```

## Scripts

- `scripts/format.sh` — formatea el código (`--lint` solo comprueba).
- `scripts/icon-from-image.swift` — regenera el icono a partir del diseño `Design/AppIcon-source.png`:
  `swift scripts/icon-from-image.swift Design/AppIcon-source.png StaiN/Resources/Assets.xcassets/AppIcon.appiconset`
- `scripts/update-strings.py` — regenera las traducciones al inglés a partir de los textos que extrae el compilador
  (las traducciones están en `scripts/translations_en.json`).
- Pruebas de rendimiento con imágenes de 8000 × 8000:

```bash
STAIN_PERF=1 swift test -c release --package-path Packages/StainKit --filter Performance
```

## Referencias

- [SSheldon/Paintbrush](https://github.com/SSheldon/Paintbrush): referencia funcional (GPL-3.0, no se reutiliza su código).
- [joshlin2201/itspaint](https://github.com/joshlin2201/itspaint): referencia de arquitectura (MIT).

## Licencia

[MIT](LICENSE)
