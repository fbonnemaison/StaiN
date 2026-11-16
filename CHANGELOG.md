# Registro de cambios

Todos los cambios importantes de StaiN se anotan aquí.
El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y las versiones siguen
[Versionado Semántico](https://semver.org/lang/es/): `MAYOR.MENOR.PARCHE`.

Mientras la app no se publique (versión 1.0.0), cada fase del [plan](TODO.md) es una versión menor.
Las versiones 0.0.1 a 0.6.0 se asignaron después, sobre el commit que cerró cada fase.

## [Sin publicar]
### Añadido
- Herramienta **Nube de revisión** (D), junto a la Bomba: rodea una zona con una nube de arcos dibujada con un
  clic por vértice, solo contorno, con tamaño de arcos pequeño, mediano o grande y estilo a mano. Al cerrarla
  sigue editable: se mueve arrastrando y se redimensiona con los 8 tiradores.

### Corregido
- La app se cerraba al pulsar ⌘Z después de escribir con la herramienta Texto: el cuadro de texto dejaba
  sus pasos de deshacer en el historial de la ventana al cerrarse.

## [0.9.2] - 2026-11-16
### Añadido
- Título del documento en la barra de la ventana: al pulsarlo se abre un popover para darle nombre, elegir
  el formato del archivo (PNG, JPEG, BMP, GIF, TIFF o HEIC) y la carpeta, y guardarlo ahí. Cambiar el
  formato de un archivo existente guarda uno nuevo sin tocar el original.
- Botón junto al título para ocultar o mostrar el panel de herramientas (también en Visualización, ⌃⌘S).
- Permiso para guardar en Imágenes y Descargas sin pasar por un panel; en otras carpetas se pide
  confirmación con el panel de guardar la primera vez en cada sesión.

### Cambiado
- La ayuda de la herramienta activa se muestra en una línea en la barra de estado, junto al tamaño del
  lienzo, en vez de debajo de las herramientas.
- Los botones de la barra superior quedan siempre alineados a la derecha.

## [0.9.1] - 2026-11-15
### Añadido
- `scripts/package-dmg.sh`: crea `StaiN-X.Y.Z.dmg` (app universal, acceso a Aplicaciones e instrucciones
  del primer arranque) y un `.zip`, con sus sumas SHA-256.
- Instrucciones para abrir la app sin notarizar la primera vez, en el README y dentro del `.dmg`.
- Guía de usuario para la wiki en `docs/wiki/` y `scripts/publish-wiki.sh` para publicarla.
- Menú Ayuda: "Ayuda de StaiN" (⌘?) abre la wiki; también "Atajos de teclado" e "Informar de un problema…".

### Cambiado
- La curva se dibuja con tres clics (inicio, final y punto de control) en vez de arrastrando, y muestra sus
  puntos de control mientras se crea; al terminar desaparecen.
- La línea y el polígono libre también muestran sus puntos de control (extremos y vértices) mientras se crean.
- La flecha se dibuja como la línea: clic en la cola y clic en la punta, sin mantener pulsado, y muestra
  sus puntos de control mientras se crea.
- Los colores personalizados se editan en el panel de valores RGB/HEX (doble clic o "Editar…").
- Los colores primario y secundario ya no se editan directamente: se eligen desde las paletas y los
  colores personalizados.

### Corregido
- "Ayuda de StaiN" decía que la ayuda no estaba disponible; ahora abre la wiki.
- La vista previa del menú Compartir mostraba un recuadro vacío; ahora muestra el icono de la app.
- El menú Compartir se abría en la parte inferior de la ventana; ahora sale del botón de la barra superior.
- Al cerrar un archivo existente con cambios, se guardaban sin preguntar. Ahora se pregunta si guardar
  los cambios (Guardar / No guardar / Cancelar), también al salir de la app.

## [0.9.0] - 2026-11-15
### Añadido
- Puntos de control en las esquinas y lados del lienzo para cambiar su tamaño con el ratón; se muestran
  u ocultan con el botón "Redimensionar lienzo" o en Visualización (⌥⌘E).
- Puntos de control en la selección para estirarla (⇧ en una esquina mantiene la proporción).
- Botones Cortar, Copiar y Pegar en la barra superior.
- Tooltips con el nombre y el atajo de cada herramienta.
- Captura de la app en el README.
- Capas, como fase futura del plan.
- Galería de formas en la herramienta Polígono: polígono libre, triángulo rectángulo, triángulo isósceles,
  rombo, pentágono, hexágono y flechas en las cuatro direcciones.
- Columnas de colores personalizados configurables (1 a 14, en 2 filas; hasta 28 colores), en Ajustes
  y en su menú desplegable.
- Guardar los colores personalizados como paleta JSON con nombre, y cargar paletas JSON (además de
  `.gpl` y `.hex`).
### Cambiado
- Barra de colores reordenada: primario/secundario, personalizados y paleta, con el menú de paletas
  al final.
- Barra superior en tres grupos: deshacer/rehacer, portapapeles y lienzo/vista/compartir.
- Cursores: cruceta en las herramientas de selección e icono de la herramienta en lápiz, pincel,
  aerógrafo, borrador, relleno y cuentagotas.
- Línea y polígono libre se dibujan con clics, sin mantener pulsado el ratón; la vista previa sigue
  al ratón. El polígono se cierra con un clic en el origen, doble clic o Escape.
- Las paletas predefinidas y cargadas ya no se editan.
- Proyecto sin costes: sin Developer ID ni notarización.
### Eliminado
- Colores recientes.
- "Guardar paleta…" y "Restaurar paleta original" del menú de paletas.
### Corregido
- El cursor sobre el lienzo alternaba entre la flecha y el de la herramienta.

## [0.8.0] - 2026-11-14
### Añadido
- 10 paletas preconfiguradas en un selector: clásica, moderna, neón, pasteles, escala de grises, tierra,
  retro 8 bits, verde 4 tonos, apta para daltonismo e interfaz web. Las paletas cargadas desde archivo
  también aparecen en el selector.
- 8 casillas de colores personalizados, que se recuerdan entre sesiones.
- Panel con valores RGB, alfa y HEX al hacer clic en el color primario o el secundario.
- Código publicado en GitHub con integración continua.
- `.gitignore` ampliado para secretos, certificados y productos de compilación.
### Cambiado
- Las casillas de color tienen los bordes ligeramente redondeados.

## [0.7.0] - 2026-11-14
### Añadido
- Nombre de la acción en el menú Deshacer ("Deshacer Lápiz") y botones de deshacer/rehacer en la barra.
- Ajustes de apariencia, formato de guardado por defecto y modo pixel para documentos nuevos.
- Cursores con el tamaño real de la punta; presión de tableta en el pincel.
- Localización en español e inglés.
- Icono de la app: pluma sobre mancha de tinta.
- Licencia y créditos dentro de la app (Acerca de StaiN), `AUTHORS.md` y `THIRD-PARTY-NOTICES.md`.
- Gestión de versiones: este registro, `scripts/bump-version.sh` y `scripts/install.sh`.
### Cambiado
- Las formas y selecciones aún editables cuentan como cambio y se guardan tal como se ven.
- El historial de deshacer se limita a 512 MB.
- Dibujo mucho más rápido con zoom alejado en imágenes grandes.
### Corregido
- Cierre al deshacer en algunos casos.

## [0.6.0] - 2026-11-14
### Añadido
- Menú Filtros con vista previa: escala de grises, sepia, invertir, brillo/contraste/saturación,
  desenfoque, enfoque, pixelar, posterizar y umbral.
- Anotar capturas: flecha, resaltador, ocultar (pixelar, desenfocar o bloque) y marcadores numerados;
  nuevo desde el portapapeles o desde una captura de pantalla; copiar y compartir.
- Pixel art: cuadrícula de píxeles, modo pixel, plantillas, exportar a escala, simetría y paletas `.gpl`/`.hex`.

## [0.5.0] - 2026-11-14
### Añadido
- Selección rectangular y libre, mover, duplicar, selección transparente; cortar, copiar, pegar.
- Menú Imagen: voltear, girar, cambiar tamaño e inclinar, tamaño del lienzo, recortar, invertir, borrar.
- Cuadrícula configurable.

## [0.4.0] - 2026-11-14
### Añadido
- Rectángulo, rectángulo redondeado, elipse y polígono con modos de relleno; formas editables.
- Curva, texto con barra de fuentes, aerógrafo y bomba.

## [0.3.0] - 2026-11-14
### Añadido
- Pincel, borrador, relleno, cuentagotas y línea; panel de herramientas con atajos.
- Paleta clásica de 28 colores, colores recientes y selector de color del sistema.

## [0.2.0] - 2026-11-14
### Añadido
- Documentos: abrir y guardar PNG, JPEG, BMP, GIF, TIFF y HEIC.
- Lienzo con zoom, deshacer, barra de estado, arrastrar y soltar, imprimir y lápiz.

## [0.1.0] - 2026-11-14
### Añadido
- Motor de imagen StainKit: bitmap, dibujo, deshacer por parches y relleno.

## [0.0.1] - 2026-11-14
### Añadido
- Estructura inicial del proyecto, licencia MIT y CI.

[Sin publicar]: https://github.com/fbonnemaison/StaiN/compare/v0.9.2...HEAD
[0.9.2]: https://github.com/fbonnemaison/StaiN/compare/v0.9.1...v0.9.2
[0.9.1]: https://github.com/fbonnemaison/StaiN/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/fbonnemaison/StaiN/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/fbonnemaison/StaiN/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/fbonnemaison/StaiN/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/fbonnemaison/StaiN/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/fbonnemaison/StaiN/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/fbonnemaison/StaiN/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/fbonnemaison/StaiN/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/fbonnemaison/StaiN/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/fbonnemaison/StaiN/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/fbonnemaison/StaiN/releases/tag/v0.0.1
