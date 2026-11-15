# StaiN

[![CI](https://github.com/fbonnemaison/StaiN/actions/workflows/ci.yml/badge.svg)](https://github.com/fbonnemaison/StaiN/actions/workflows/ci.yml)
[![Licencia: MIT](https://img.shields.io/badge/licencia-MIT-blue.svg)](LICENSE)

Editor de imágenes raster sencillo para macOS, inspirado en Microsoft Paint (antes Paintbrush) y MacPaint.
Escrito en Swift, open source (MIT). Autor: **App-Zilla**.

![Ventana de StaiN con un dibujo y una selección con sus puntos de control](docs/screenshot.png)

> Consulta la versión actual y los cambios en [CHANGELOG.md](CHANGELOG.md), y el plan en [TODO.md](TODO.md).

## Requisitos

- macOS 26 o superior
- Xcode 27 o superior

## Estructura

```
StaiN/                 App macOS (SwiftUI + lienzo AppKit)
StaiNUITests/          Tests de interfaz (XCUITest)
Packages/StainKit/     Motor de dibujo, sin UI ni dependencias
docs/                  Captura del README (la genera PolishUITests.testReadmeScreenshot)
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

## Instalar

```bash
./scripts/install.sh
```

Compila en Release e instala (o sustituye) `/Applications/StaiN.app`.

## Versiones

StaiN usa [Versionado Semántico](https://semver.org/lang/es/) y anota los cambios en [CHANGELOG.md](CHANGELOG.md).
Para publicar una versión, apunta los cambios en `## [Sin publicar]` y ejecuta:

```bash
./scripts/bump-version.sh minor
```

(`major`, `minor`, `patch` o un número concreto). El script actualiza la versión y el número de compilación,
fecha la sección del CHANGELOG, hace commit y crea la etiqueta `vX.Y.Z`. No sube nada a GitHub.

## Scripts

- `scripts/format.sh` — formatea el código (`--lint` solo comprueba).
- `scripts/install.sh` — compila e instala en `/Applications`.
- `scripts/bump-version.sh` — sube la versión, actualiza el CHANGELOG y crea la etiqueta.
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

[MIT](LICENSE) © 2026 App-Zilla. Consulta [AUTHORS.md](AUTHORS.md) y [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
