# Registro de cambios

Todos los cambios importantes de StaiN se anotan aquí.
El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y las versiones siguen
[Versionado Semántico](https://semver.org/lang/es/): `MAYOR.MENOR.PARCHE`.

Mientras la app no se publique (versión 1.0.0), cada fase del [plan](TODO.md) es una versión menor.
Las versiones 0.0.1 a 0.6.0 se asignaron después, sobre el commit que cerró cada fase.

## [Sin publicar]
### Añadido
- Código publicado en GitHub con integración continua.
- `.gitignore` ampliado para secretos, certificados y productos de compilación.

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

[Sin publicar]: https://github.com/fbonnemaison/StaiN/compare/v0.7.0...HEAD
[0.7.0]: https://github.com/fbonnemaison/StaiN/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/fbonnemaison/StaiN/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/fbonnemaison/StaiN/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/fbonnemaison/StaiN/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/fbonnemaison/StaiN/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/fbonnemaison/StaiN/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/fbonnemaison/StaiN/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/fbonnemaison/StaiN/releases/tag/v0.0.1
