# Replica: pintar una imagen con las herramientas de StaiN

Ejemplo de uso de `StainKit` desde código. El script toma una imagen de referencia y la vuelve a pintar
**solo con herramientas de StaiN**, como lo haría una persona: elige un color, pulsa, arrastra y suelta.
No copia píxeles de la referencia; la usa para decidir dónde y de qué color dar cada trazo.

```bash
cd Examples/Replica
swift run -c release Replica                      # usa referencia.webp y escribe en out/
swift run -c release Replica foto.png carpeta/    # otra imagen y otra carpeta
```

## Cómo pinta

1. **Cubo de pintura**: rellena el fondo con el color del borde de la referencia.
2. **Pincel**, por capas de 48, 24, 12, 6, 3 y 2 px. En cada capa recorre la imagen en una cuadrícula,
   busca las zonas que aún se parecen poco a la referencia y da allí una pincelada del color de la referencia
   que sigue la dirección de los bordes (pintura por trazos de Hertzmann, 1998).
3. **Lápiz** (1 px): repasa las líneas de tinta, los bigotes y las letras.

Tras cada capa guarda una imagen en `out/pasos/` y muestra cuánto se parece ya a la referencia:

| Paso | Parecido |
|---|---|
| Fondo (cubo) | 75,7 % |
| Pincel 48 px | 83,2 % |
| Pincel 24 px | 88,7 % |
| Pincel 12 px | 91,2 % |
| Pincel 6 px | 93,4 % |
| Pincel 3 px | 94,6 % |
| Pincel 2 px | 95,7 % |
| Lápiz | 97,7 % |

## Salida

- `out/replica.png`: el resultado.
- `out/comparacion.png`: referencia y réplica una al lado de la otra.
- `out/proceso.gif`: animación del proceso, capa a capa.
- `out/pasos/`: la imagen después de cada capa.

El resultado es siempre el mismo (el orden aleatorio de los trazos usa una semilla fija).
Los parámetros (tamaños de pincel, umbral, longitud de los trazos) están al principio de la sección
**Parámetros** de `Sources/Replica/main.swift`.
