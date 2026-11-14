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

## Referencias

- [SSheldon/Paintbrush](https://github.com/SSheldon/Paintbrush): referencia funcional (GPL-3.0, no se reutiliza su código).
- [joshlin2201/itspaint](https://github.com/joshlin2201/itspaint): referencia de arquitectura (MIT).

## Licencia

[MIT](LICENSE)
