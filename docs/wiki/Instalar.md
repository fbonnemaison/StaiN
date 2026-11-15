# Instalar

## Requisitos

- macOS 26 o superior.
- Mac con Apple Silicon o Intel.

## Desde una versión publicada

1. Descarga `StaiN-X.Y.Z.dmg` de la página de [Releases](https://github.com/fbonnemaison/StaiN/releases).
2. Ábrelo y arrastra **StaiN** a la carpeta **Aplicaciones** que aparece en la misma ventana.
3. Expulsa el disco.

## Abrirla la primera vez

StaiN no está notarizado por Apple: la notarización exige el Apple Developer Program, que es de pago, y StaiN
no tiene costes ni para quien lo desarrolla ni para quien lo usa. Por eso macOS pide una confirmación
**solo la primera vez**:

1. Abre StaiN desde Aplicaciones. macOS dice que no puede verificar que la app no contenga software
   malicioso. Pulsa **Hecho** (no «Trasladar a la papelera»).
2. Abre **Ajustes del Sistema › Privacidad y seguridad** y baja hasta la sección **Seguridad**.
3. Junto a «Se ha bloqueado el uso de StaiN…», pulsa **Abrir igualmente**.
4. Confirma con tu contraseña o Touch ID y vuelve a pulsar **Abrir igualmente**.

A partir de ahí se abre con normalidad.

> En versiones recientes de macOS ya no basta con hacer clic derecho › Abrir: hay que pasar por
> Privacidad y seguridad.

### Alternativa desde el Terminal

Después de copiar la app a Aplicaciones:

```bash
xattr -dr com.apple.quarantine /Applications/StaiN.app
```

Quita la marca de «descargado de internet» y la app se abre sin el aviso.

### Comprobar la descarga (opcional)

Cada versión publica la suma SHA-256 del `.dmg`. Para comprobarla:

```bash
shasum -a 256 ~/Downloads/StaiN-X.Y.Z.dmg
```

## Desde el código

Con Xcode 27 o superior:

```bash
git clone https://github.com/fbonnemaison/StaiN.git
cd StaiN
./scripts/install.sh
```

Compila en Release e instala (o sustituye) `/Applications/StaiN.app`. Al compilarla en tu propio Mac no aparece
el aviso del primer arranque.

## Actualizar y desinstalar

- **Actualizar:** instala el `.dmg` nuevo encima; las preferencias y paletas se conservan.
- **Desinstalar:** arrastra `/Applications/StaiN.app` a la papelera. Para borrar también las preferencias:
  `defaults delete io.github.fbonnemaison.StaiN`.
