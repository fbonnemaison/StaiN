# Colores y paletas

La barra inferior tiene, de izquierda a derecha: los colores **primario y secundario**, los **colores
personalizados** y la **paleta**.

## Primario y secundario

- El cuadro de delante es el **primario** (clic izquierdo) y el de detrás el **secundario** (clic derecho,
  fondo del borrador, relleno de formas).
- **Clic en uno de ellos:** panel con los valores **RGB** (0–255, con alfa) y **HEX** (`#RRGGBB` o `#RRGGBBAA`).
  Desde ahí se puede copiar y pegar el HEX o abrir el selector de color del sistema.
- **⇄** o la tecla **X**: intercambia primario y secundario.

## Paleta

- **Clic izquierdo** en una muestra: color primario. **Clic derecho:** secundario.
- La flecha **⌄** al final de la paleta abre su menú:
  - Elegir otra paleta predefinida: Clásica, Moderna, Neón, Pasteles, Escala de grises, Tierra, Retro 8 bits,
    Verde 4 tonos, Apta para daltonismo e Interfaz web.
  - **Cargar paleta…**: archivos `.json` de StaiN, `.gpl` (GIMP) o `.hex` (Lospec). La paleta se añade al
    selector con su nombre.
  - **Quitar esta paleta del selector** (solo las cargadas).
- Las paletas **no se editan**. Para tener colores propios, usa los colores personalizados.

## Colores personalizados

Dos filas de casillas, vacías al principio, que se recuerdan entre sesiones y no cambian al cambiar de paleta.

- **Clic en una casilla vacía:** guarda en ella el color primario.
- **Clic en una casilla llena:** usa ese color como primario.
- **Doble clic en una llena:** editarla.
- **Clic derecho:** usar como secundario, guardar el primario aquí, editar o vaciar.
- La flecha **⌄** de los personalizados abre su menú:
  - **Guardar como paleta…**: guarda los colores en un archivo `.json`. El panel pide también el **nombre de la
    paleta**, que se guarda dentro del archivo.
  - **Columnas:** de 1 a 14 (hasta 28 colores). También se cambia en [Ajustes](Ajustes).
  - **Vaciar todos.**

## Formato JSON de las paletas

```json
{
  "colors" : ["#FF0000", "#0080FF"],
  "format" : "stain-palette",
  "name" : "Mis colores",
  "version" : 1
}
```

Cada color es `#RRGGBB` (o `#RRGGBBAA` si tiene transparencia). Al cargar, solo `colors` es obligatorio. Un JSON guardado con **Guardar como paleta…** se puede volver a cargar
con **Cargar paleta…** para tenerlo como paleta en el selector.
