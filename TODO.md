# StaiN — Plan de desarrollo

Editor de imágenes raster sencillo para macOS, inspirado en Microsoft Paint (antes Paintbrush) y MacPaint.
Escrito en Swift, open source (MIT) y pensado para uso personal.

---

## Decisiones tomadas

| Tema | Decisión |
|---|---|
| Lenguaje | Swift 6 (modo de concurrencia estricto) |
| Plataforma | Solo macOS, versión mínima **macOS 26** (Tahoe) |
| UI | La interfaz (ventanas, barras de herramientas, paneles e inspectores) se hace en SwiftUI. El lienzo es un `NSView` propio en AppKit, metido con `NSViewRepresentable`, porque así se controlan mejor el ratón, la tableta y el render. |
| Motor | Paquete Swift local **`StainKit`** sin UI ni dependencias: bitmap, herramientas, rellenos, deshacer. Sigue el enfoque de PaintKit (ItsPaint). |
| Render | Core Graphics sobre un buffer RGBA8 premultiplicado. Se pasa a Metal solo si el rendimiento lo exige. |
| Documentos | `DocumentGroup` + `ReferenceFileDocument`. Lectura y escritura con ImageIO. |
| Licencia | **MIT**. No se copia código de Paintbrush (GPL-3.0): solo se toman ideas y UX. |
| Tests | Swift Testing (`import Testing`) para `StainKit` y XCUITest para los flujos básicos. |

### Referencias

- **[SSheldon/Paintbrush](https://github.com/SSheldon/Paintbrush)**: Objective-C, GPL-3.0, sin cambios desde 2014. Sirve de referencia **funcional** (catálogo de herramientas, UX clásica y diálogos). Tiene una clase base `SWTool` con subclases por herramienta, `SWPaintView`, `SWDocument`, `SWScalingScrollView` (zoom) y una cuadrícula.
- **[joshlin2201/itspaint](https://github.com/joshlin2201/itspaint)**: Swift, MIT, activo en noviembre de 2026. Sirve de referencia de **arquitectura**: separa el motor (PaintKit) de la app y está orientado a anotar capturas.
- ⚠️ Como la licencia es MIT, **no se puede copiar código** de Paintbrush. Sí se puede reutilizar código de ItsPaint conservando su aviso de copyright MIT.

---

## Fase 0 — Preparación del proyecto
- [x] `git init`, `.gitignore` (Xcode/SwiftPM, `xcuserdata`, `DerivedData`, `.DS_Store`)
- [x] `LICENSE` (MIT), `README.md` (qué es, capturas, cómo compilar) y `CONTRIBUTING.md` breve
- [x] Proyecto Xcode `StaiN.xcodeproj` (generado con XcodeGen desde `project.yml`): app macOS (SwiftUI), deployment target 26.0, bundle id `io.github.fbonnemaison.StaiN`
- [x] Paquete local `Packages/StainKit` (biblioteca + target de tests) enlazado a la app
- [x] Configurar Swift 6 con strict concurrency y warnings tratados como errores en `StainKit`
- [x] Formateo y lint: `swift-format` con una configuración en el repo
- [ ] CI en GitHub Actions: build y tests de `StainKit` y de la app en un runner macOS (*workflow creado; falta verificarlo en GitHub*)
- [ ] Crear el repositorio público en GitHub, con plantillas de issues y PR

## Fase 1 — Motor de imagen (`StainKit`)
- [x] `Bitmap`: buffer RGBA8 premultiplicado (ancho, alto, stride) con acceso por píxel, recorte/reemplazo de regiones y conversión a y desde `CGImage`
- [x] `PaintColor` (RGBA) con conversión a `CGColor` (en StainKit) y `NSColor` (extensión en la app)
- [x] Contexto de dibujo sobre el bitmap (origen arriba a la izquierda, con recorte), con o sin antialiasing
- [x] Seguimiento de *dirty rects* para redibujar solo lo que cambia (`Canvas`)
- [x] Protocolo `Tool` con eventos `begin`/`drag`/`end`/`cancel`, modificadores (Shift, Opción) y botón primario o secundario, más `ToolSession` (un trazo = un paso de deshacer)
- [x] Sistema de deshacer y rehacer basado en parches (región antes/después), con límite de pasos y de memoria (`UndoHistory`)
- [x] Algoritmo de relleno *flood fill* por scanlines con tolerancia
- [x] Tests: operaciones de píxel, flood fill, deshacer/rehacer e ida y vuelta con `CGImage` (38 tests)

## Fase 2 — Documento, lienzo y archivos
- [x] `DocumentGroup` con lienzo nuevo en blanco (tamaño por defecto configurable en Ajustes)
- [x] Abrir y guardar **PNG, JPEG, BMP, GIF, TIFF y HEIC** con ImageIO (respeta la orientación EXIF; JPEG/BMP se aplanan sobre blanco); calidad JPEG/HEIC en Ajustes
- [x] `CanvasView` (NSView) que pinta el bitmap con una capa de fondo a cuadros para la transparencia (solo redibuja la región sucia)
- [x] Scroll y zoom (de 12,5 % a 3200 %), con el lienzo centrado cuando es más pequeño que la ventana (como `SWCenteringClipView`)
- [x] Zoom con pellizco del trackpad, con ⌘+/⌘−/⌘0 y con la herramienta lupa
- [x] Barra de estado: posición del cursor, tamaño de la imagen y zoom (el tamaño de la selección llega con la Fase 5)
- [x] Arrastrar y soltar imágenes sobre la ventana o el icono del Dock (se abren como documentos)
- [x] Imprimir (⌘P) con escalado a la página
- [x] Aviso de cambios sin guardar, autosave y versiones nativas de macOS
- [x] Deshacer/rehacer con el `UndoManager` del documento (menú Edición, ⌘Z/⇧⌘Z), un paso por trazo con `UndoPatch`

## Fase 3 — Herramientas básicas y color
- [ ] Panel de herramientas (cuadrícula de iconos de SF Symbols con tooltips y atajos de una tecla)
- [x] **Lápiz**: 1 px sin antialiasing (adelantado en la Fase 2)
- [ ] **Pincel**: tamaños y formas (redondo, cuadrado, caligráfico /, \)
- [ ] **Borrador**: pinta con el color secundario, o transparente, y tiene tamaños
- [ ] **Relleno (cubo)**: con tolerancia ajustable
- [ ] **Cuentagotas**: clic izquierdo para el color primario y clic derecho para el secundario
- [ ] **Línea**: grosor, y con Shift se fija a 0°, 45° o 90°
- [ ] Paleta: color primario y secundario (clic izquierdo o derecho), paleta de 28 colores editable y colores recientes
- [ ] Selector de color del sistema (`NSColorPanel`) con soporte de transparencia (alfa)
- [ ] Atajo X para intercambiar el color primario y el secundario

## Fase 4 — Formas, texto y aerógrafo
- [ ] **Rectángulo**, **rectángulo redondeado** y **elipse**; con Shift salen proporciones 1:1
- [ ] **Polígono** (clic por vértice y doble clic para cerrar)
- [ ] **Curva** al estilo clásico: se traza una línea y luego se doblan 2 puntos de control
- [ ] Modos de relleno: solo contorno, contorno y relleno, solo relleno
- [ ] Las formas siguen editables (mover y redimensionar) hasta que se confirman
- [ ] **Texto**: cuadro editable con fuente, tamaño, negrita, cursiva y subrayado, fondo opaco o transparente; se rasteriza al confirmar
- [ ] **Aerógrafo**: spray aleatorio con densidad y radio, que sigue pintando mientras se mantiene el clic
- [ ] Herramienta **"Bomba"** de Paintbrush: borra todo el lienzo con el color secundario (con confirmación y deshacer)

## Fase 5 — Selección y operaciones de imagen
- [ ] **Selección rectangular** y **selección libre (lazo)**, con hormigas marchantes
- [ ] Mover la selección (y duplicarla con ⌥ al arrastrar) y moverla con las flechas
- [ ] Selección transparente: ignora el color secundario al pegar o mover
- [ ] Cortar, copiar, pegar, eliminar y seleccionar todo, usando el portapapeles del sistema (`NSPasteboard`, PNG/TIFF)
- [ ] Pegar como documento nuevo
- [ ] **Recortar** a la selección
- [ ] **Cambiar tamaño** (porcentaje o píxeles, mantener proporción, interpolación suave o vecino más cercano) e **inclinar**
- [ ] **Tamaño del lienzo** con anclaje (sin reescalar el contenido)
- [ ] **Rotar** 90°, 180° y 270°, y **voltear** horizontal y vertical (de la imagen o de la selección)
- [ ] **Invertir colores** y **borrar imagen**
- [ ] Cuadrícula superpuesta configurable (como el `SWGridPanel` de Paintbrush)

## Fase 6 — Extras

### 6a. Filtros de imagen (Core Image)
- [ ] Infraestructura de filtros: se aplican a la imagen o a la selección, con vista previa en vivo en una hoja y deshacer
- [ ] Escala de grises, sepia e invertir
- [ ] Brillo, contraste y saturación
- [ ] Desenfoque gaussiano y enfoque (*sharpen*)
- [ ] Pixelar y posterizar
- [ ] Umbral (blanco y negro)

### 6b. Anotar capturas
- [ ] Nuevo documento desde el portapapeles (⌘⇧N) y desde una captura de pantalla con ScreenCaptureKit (región, ventana o pantalla completa)
- [ ] **Flecha** con grosor y estilo de punta
- [ ] **Resaltador** semitransparente que no se acumula dentro del mismo trazo
- [ ] **Redacción**: pixelar, desenfocar o tapar con un bloque sólido una región
- [ ] **Marcadores numerados** (1, 2, 3…) autoincrementales
- [ ] Copiar el resultado al portapapeles en un clic (⌘⇧C) y compartir con `ShareLink`

### 6c. Modo pixel art
- [ ] Cuadrícula de píxeles visible a partir de cierto zoom (por ejemplo ≥ 800 %)
- [ ] Lápiz, línea, formas y relleno sin antialiasing (ajuste global "modo pixel")
- [ ] Plantillas de lienzo pequeñas (16×16, 32×32, 64×64)
- [ ] Exportar escalado ×2, ×4 u ×8 con vecino más cercano
- [ ] Dibujo con simetría horizontal y vertical (opcional)
- [ ] Paletas limitadas (cargar y guardar `.gpl` o `.hex`)

## Fase 7 — Pulido para macOS 26
- [ ] Barra de herramientas e inspectores con el estilo Liquid Glass del sistema
- [ ] Menús completos con atajos al estilo de Paint y de Mac (⌘Z/⇧⌘Z, ⌘A, ⌘E (atributos de imagen), ⌘R (cambiar tamaño), etc.)
- [ ] Ventana de preferencias (`Settings`): tamaño por defecto, antialiasing, formato de guardado y cuadrícula
- [ ] Cursores personalizados por herramienta, con vista previa del tamaño del pincel
- [ ] Soporte de presión de tableta Wacom o Sidecar para el pincel (opcional)
- [ ] Accesibilidad: VoiceOver en paneles, Aumentar contraste y navegación con teclado
- [ ] Localización en **español** e **inglés** (String Catalog)
- [ ] Modo oscuro y claro
- [ ] Rendimiento: la copia del bitmap al empezar cada trazo copia la imagen entera; cambiar a copia por tiles si va lento
- [ ] Deshacer: `UndoManager` limita pasos pero no memoria; aplicar el límite de bytes de `UndoHistory` si hace falta
- [ ] El menú muestra "Deshacer" sin el nombre de la acción ("Deshacer Lápiz"); revisar con los comandos de SwiftUI
- [ ] Rendimiento: probar con imágenes de 8000×8000, perfilar con Instruments y valorar Metal o tiles si hace falta
- [ ] Icono de la app y de los tipos de documento

## Fase 8 — Publicación
- [ ] Firma ad-hoc o con Apple ID personal (para uso propio; notarizar es opcional)
- [ ] Script de empaquetado `.dmg` / `.zip`
- [ ] GitHub Releases con changelog (`CHANGELOG.md`, versionado SemVer)
- [ ] (Opcional) Cask de Homebrew
- [ ] Documentación de usuario: atajos y herramientas en el README o en una wiki

---

## Preguntas abiertas
- [ ] ¿El nombre definitivo es **StaiN**? (bundle id provisional: `io.github.fbonnemaison.StaiN`)
- [ ] ¿El repo de GitHub se crea público desde el principio o se publica cuando la Fase 3 esté lista?
- [ ] ¿Formato de proyecto propio con datos de edición (formas editables, anotaciones no destructivas), o siempre se rasteriza a PNG?
