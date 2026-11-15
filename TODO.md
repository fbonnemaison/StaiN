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
| Costes | **Ninguno**, ni para el desarrollador ni para los usuarios: sin Apple Developer Program (Developer ID, notarización, App Store), sin servicios ni dependencias de pago. La app se distribuye con firma ad-hoc. |
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
- [x] CI en GitHub Actions: formato, tests de `StainKit` y compilación de la app en un runner macOS (verificado en GitHub)
- [x] Crear el repositorio público en GitHub, con plantillas de issues y PR (https://github.com/fbonnemaison/StaiN)

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
- [x] Barra de estado: posición del cursor, tamaño de la selección, tamaño de la imagen y zoom
- [x] Arrastrar y soltar imágenes sobre la ventana o el icono del Dock (se abren como documentos)
- [x] Imprimir (⌘P) con escalado a la página
- [x] Aviso de cambios sin guardar, autosave y versiones nativas de macOS
- [x] Deshacer/rehacer con el `UndoManager` del documento (menú Edición, ⌘Z/⇧⌘Z), un paso por trazo con `UndoPatch`

## Fase 3 — Herramientas básicas y color
- [x] Panel de herramientas (cuadrícula de iconos de SF Symbols con tooltips y atajos de una tecla: P, B, E, F, I, L, Z) con recuadro de opciones
- [x] **Lápiz**: 1 px sin antialiasing (adelantado en la Fase 2)
- [x] **Pincel**: tamaños y formas (redondo, cuadrado, caligráfico /, \)
- [x] **Borrador**: pinta con el color secundario, o transparente, y tiene tamaños
- [x] **Relleno (cubo)**: con tolerancia ajustable
- [x] **Cuentagotas**: clic izquierdo para el color primario y clic derecho para el secundario; vuelve a la herramienta anterior
- [x] **Línea**: grosor, vista previa al arrastrar, y con Shift se fija a 0°, 45° o 90°
- [x] Paleta: color primario y secundario (clic izquierdo o derecho), paleta de 28 colores editable (doble clic) y colores recientes
- [x] Selector de color del sistema (`NSColorPanel`) con soporte de transparencia (alfa)
- [x] Atajo X para intercambiar el color primario y el secundario

## Fase 4 — Formas, texto y aerógrafo
- [x] **Rectángulo**, **rectángulo redondeado** y **elipse**; con Shift salen proporciones 1:1
- [x] **Polígono** (clic por vértice y doble clic, o clic en el primer vértice, para cerrar)
- [x] **Curva** al estilo clásico: se traza una línea y luego se doblan 2 puntos de control
- [x] Modos de relleno: solo contorno, contorno y relleno, solo relleno (y grosor del borde)
- [x] Las formas siguen editables (mover y redimensionar con 8 tiradores) hasta que se confirman con Intro, clic fuera o cambio de herramienta; Escape las descarta
- [x] **Texto**: cuadro editable con fuente, tamaño, negrita, cursiva y subrayado, fondo opaco o transparente; se rasteriza al confirmar
- [x] **Aerógrafo**: spray aleatorio con densidad y radio, que sigue pintando mientras se mantiene el clic
- [x] Herramienta **"Bomba"** de Paintbrush: borra todo el lienzo con el color secundario (con confirmación y deshacer)
- [x] Tests de interfaz de la Fase 4 (`ShapeAndTextUITests`) ejecutados y captura revisada

## Fase 5 — Selección y operaciones de imagen
- [x] **Selección rectangular** (S) y **selección libre (lazo)** (Q), con hormigas marchantes y tamaño en la barra de estado
- [x] Mover la selección (y duplicarla con ⌥ al arrastrar) y moverla con las flechas (⇧ = 10 px)
- [x] Selección transparente: ignora el color secundario al pegar o mover
- [x] Cortar, copiar, pegar, eliminar y seleccionar todo, usando el portapapeles del sistema (`NSPasteboard`, PNG/TIFF); al pegar algo más grande, ofrece agrandar el lienzo
- [x] Pegar como documento nuevo (⇧⌘V)
- [x] **Recortar** a la selección (⌘K)
- [x] **Cambiar tamaño** (porcentaje o píxeles, mantener proporción, interpolación suave o vecino más cercano) e **inclinar** (⌘R)
- [x] **Tamaño del lienzo** con anclaje (sin reescalar el contenido) (⌘E)
- [x] **Rotar** 90°, 180° y 270°, y **voltear** horizontal y vertical (de la imagen o de la selección)
- [x] **Invertir colores** (⌘I) y **borrar imagen** (⇧⌘⌫)
- [x] Cuadrícula superpuesta configurable (como el `SWGridPanel` de Paintbrush) (⌘G, separación en Ajustes)

## Fase 6 — Extras

### 6a. Filtros de imagen (Core Image)
- [x] Infraestructura de filtros: se aplican a la imagen o a la selección, con vista previa en vivo en una hoja y deshacer (menú Filtros)
- [x] Escala de grises, sepia e invertir
- [x] Brillo, contraste y saturación
- [x] Desenfoque gaussiano y enfoque (*sharpen*)
- [x] Pixelar y posterizar
- [x] Umbral (blanco y negro)

### 6b. Anotar capturas
- [x] Nuevo documento desde el portapapeles (⇧⌘N) y desde una captura de pantalla con ScreenCaptureKit (ventana o pantalla completa, ⌥⌘5; la región se obtiene recortando con ⌘K)
- [ ] Probar la captura de pantalla a mano: necesita el permiso de Grabación de pantalla y no se puede automatizar
- [x] **Flecha** (W) con grosor; Shift ajusta a 45°
- [x] **Resaltador** (H) semitransparente que no se acumula dentro del mismo trazo
- [x] **Redacción** (herramienta Ocultar, K): pixelar, desenfocar o tapar con un bloque sólido una región
- [x] **Marcadores numerados** (N) (1, 2, 3…) autoincrementales, con botón para reiniciar
- [x] Copiar el resultado al portapapeles en un clic (⇧⌘C y botón de la barra) y compartir (botón Compartir con el menú del sistema)

### 6c. Modo pixel art
- [x] Cuadrícula de píxeles visible a partir de 800 % (se puede ocultar en Visualización)
- [x] Lápiz, línea, formas y relleno sin antialiasing; el "modo pixel" quita también el suavizado de texto, flechas, resaltador y marcadores
- [x] Plantillas de lienzo pequeñas (16×16, 32×32, 64×64), transparentes; las imágenes pequeñas se abren ampliadas y en modo pixel
- [x] Exportar escalado ×2, ×4 u ×8 con vecino más cercano (Archivo › Exportar a escala)
- [x] Dibujo con simetría horizontal y vertical para lápiz, pincel, borrador y aerógrafo
- [x] Paletas limitadas (cargar y guardar `.gpl` o `.hex`, clic derecho en la paleta; hasta 256 colores)
- [ ] Probar a mano los paneles de Compartir, Exportar a escala y Cargar/Guardar paleta (los tests de interfaz no los recorren)

## Fase 7 — Pulido para macOS 26
- [x] Barra de herramientas del sistema (Liquid Glass en macOS 26) con deshacer/rehacer, ajustar a la ventana, copiar y compartir
- [x] Menús completos con atajos al estilo de Paint y de Mac (⌘Z/⇧⌘Z, ⌘A, ⌘E (atributos de imagen), ⌘R (cambiar tamaño), ⌘G cuadrícula, ⌘9 ajustar, etc.)
- [x] Ventana de preferencias (`Settings`): apariencia, tamaño por defecto, modo pixel (sin suavizado), formato de guardado, calidad JPEG y cuadrícula
- [x] Cursores personalizados por herramienta, con vista previa del tamaño del pincel (pendiente de revisar a mano: los cursores no salen en las capturas de los tests)
- [x] Soporte de presión de tableta Wacom o Sidecar para el pincel (probado en el motor; sin tableta para probarlo en la app)
- [x] Accesibilidad: auditoría automática de XCUITest sin problemas, etiquetas de VoiceOver en herramientas, paleta y lienzo, atajos de teclado para todo
- [x] Localización en **español** e **inglés** (String Catalog, 201 textos; `scripts/update-strings.py`)
- [x] Modo oscuro y claro (y elección en Ajustes)
- [x] Rendimiento: la copia del bitmap al empezar cada trazo cuesta 40–90 ms en 8000×8000 (aceptable); los tiles quedan como mejora futura si hiciera falta
- [x] Deshacer: límite de 512 MB y 200 pasos ajustando `levelsOfUndo`
- [x] El menú muestra "Deshacer Lápiz" / "Undo Pencil"
- [x] Las formas, polígonos y selecciones flotantes aún editables cuentan como cambio y se guardan tal como se ven
- [x] Rendimiento: medido con 8000×8000 (`STAIN_PERF=1`); el dibujo con zoom alejado pasó de 82–145 ms a 13 ms con muestreo. No se usó Instruments
- [x] Icono de la app: pluma sobre mancha de tinta con degradado (`Design/AppIcon-source.png`, `scripts/icon-from-image.swift`); macOS genera los iconos de documento a partir de él
- [x] Resolución del icono: se mantiene el recorte de ~440 px (algo blando en los tamaños grandes); si aparece una versión de 1024 px, basta con volver a ejecutar el script

## Fase 8 — Publicación
- [x] Firma ad-hoc ("Sign to Run Locally"). Sin Developer ID ni notarización, porque exigen el Apple Developer Program de pago
- [x] Instalación local: `scripts/install.sh` compila en Release e instala en `/Applications`
- [x] Gestión de versiones: SemVer, `CHANGELOG.md`, `scripts/bump-version.sh` y etiquetas `vX.Y.Z` (una por fase)
- [x] Cumplimiento MIT: `LICENSE`, `AUTHORS.md`, `THIRD-PARTY-NOTICES.md`, licencia y créditos dentro de la app; autor App-Zilla
- [x] Script de empaquetado `.dmg` / `.zip` (`scripts/package-dmg.sh`): app universal, acceso a Aplicaciones, instrucciones del primer arranque y SHA-256
- [x] Código y etiquetas `v0.0.1`–`v0.7.0` publicados en GitHub
- [ ] GitHub Releases a partir de las etiquetas y del `CHANGELOG.md`
- [ ] (Opcional) Cask de Homebrew en un tap propio (`fbonnemaison/homebrew-tap`); el repositorio oficial exige apps notarizadas
- [x] Instrucciones para abrir la app sin notarizar la primera vez (Ajustes del Sistema › Privacidad y seguridad › Abrir igualmente, o `xattr`): en el README, en la wiki y dentro del `.dmg`
- [x] Documentación de usuario en la wiki: páginas en `docs/wiki/` y `scripts/publish-wiki.sh` para publicarlas
- [x] Wiki publicada en https://github.com/fbonnemaison/StaiN/wiki (se actualiza con `scripts/publish-wiki.sh`)

## Mejoras — Colores

### Paletas preconfiguradas
- [x] Selector de paleta en la barra de colores (menú junto a las muestras), recordando la última elegida; "•" indica que tiene muestras editadas y "Restaurar paleta original" la devuelve a su estado
- [x] **Clásica**: los 28 colores de Paint (ya existe; será una opción más del selector)
- [x] **Moderna**: tonos actuales y equilibrados, tipo colores del sistema de macOS
- [x] **Neón**: colores saturados y brillantes (magenta, cian, lima, naranja eléctrico…)
- [x] **Pasteles**: tonos suaves y claros
- [x] Otras a evaluar:
  - [x] **Escala de grises**: del negro al blanco en pasos iguales
  - [x] **Tierra / naturales**: marrones, ocres, verdes oliva y arena
  - [x] **Retro 8 bits**: 16 colores propios al estilo de las consolas antiguas, para pixel art
  - [x] **Monocromo verde (4 tonos)**: estilo pantallas portátiles antiguas, para pixel art
  - [x] **Apta para daltonismo**: colores distinguibles con cualquier tipo de daltonismo (p. ej. Okabe–Ito)
  - [x] **Material / web**: los colores más usados en diseño de interfaces
- [x] Las paletas cargadas desde archivo (`.gpl` / `.hex`) aparecen también en el selector

### Colores personalizados
- [x] **8 casillas de colores personalizados** a la derecha de la paleta, vacías al principio
- [x] Guardar en una casilla el color primario (clic en una casilla vacía o "Guardar el color primario aquí" en su menú), editarla con doble clic y vaciarla desde el menú contextual
- [x] Las casillas personalizadas se recuerdan entre sesiones y no cambian al cambiar de paleta

### Aspecto de las muestras
- [x] Bordes ligeramente redondeados en todas las casillas de color (paleta, recientes, personalizados, primario y secundario), manteniendo el fondo a cuadros para la transparencia

### Elegir colores por valor
- [x] Campos **RGB** (0–255 por canal, y alfa) y **HEX** (`#RRGGBB` / `#RRGGBBAA`) para el color primario y el secundario, dentro de la propia app en un panel que se abre al hacer clic en el color primario o el secundario; el selector del sistema sigue disponible desde ahí
- [x] Validar lo escrito (valores fuera de rango, HEX incompleto) y actualizar el color al momento
- [x] Copiar y pegar el HEX del color actual

## Mejoras — Interfaz
- [x] Barra de colores en este orden: primario/secundario, personalizados y paleta, con el menú de paletas al final
- [x] Colores recientes eliminados
- [x] Barra superior en tres grupos: Deshacer/Rehacer, Cortar/Copiar/Pegar y Redimensionar lienzo/Ajustar/Compartir
- [x] Tooltips con nombre y atajo en las herramientas del panel izquierdo
- [x] Puntos de control en las esquinas y lados del lienzo para cambiar su tamaño con el ratón; se muestran u ocultan con el botón "Redimensionar lienzo" (⌥⌘E)
- [x] Puntos de control en la selección para estirarla (⇧ en una esquina mantiene la proporción)
- [x] Cursores: cruceta en las herramientas de selección; icono de la herramienta en lápiz, pincel, aerógrafo, borrador, relleno y cuentagotas
- [ ] Revisar a mano los cursores nuevos (los tests no los capturan)

## Fase 9 — Capas (futuro)
- [ ] Modelo de documento con varias capas en `StainKit`: lista ordenada de bitmaps del mismo tamaño, con nombre, visibilidad, opacidad y bloqueo
- [ ] Composición de las capas para mostrar el lienzo (solo la región sucia) y para exportar
- [ ] Las herramientas pintan en la capa activa; el cuentagotas y el relleno pueden leer la capa activa o la imagen combinada
- [ ] Panel de capas: añadir, duplicar, eliminar, renombrar, reordenar arrastrando, mostrar/ocultar, opacidad y miniatura
- [ ] Fusionar hacia abajo y acoplar la imagen
- [ ] Deshacer y rehacer por capa (parches con el índice de capa) y para las operaciones del panel
- [ ] Selección, filtros, rotar/voltear y cambiar tamaño sobre la capa activa o sobre todas
- [ ] Formato de archivo propio que conserve las capas (p. ej. paquete con un PNG por capa y un JSON), y aviso al guardar en PNG/JPEG de que se acoplan
- [ ] Abrir y guardar TIFF/PSD con capas (opcional)
- [ ] Modos de fusión (multiplicar, pantalla, superponer…) (opcional)

---

## Preguntas abiertas
- [ ] ¿El nombre definitivo es **StaiN**? (bundle id provisional: `io.github.fbonnemaison.StaiN`)
- [x] Repositorio de GitHub: público, publicado tras la Fase 7
- [ ] ¿Formato de proyecto propio con datos de edición (formas editables, anotaciones no destructivas), o siempre se rasteriza a PNG?
