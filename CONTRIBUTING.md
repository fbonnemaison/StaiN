# Contribuir

1. Abre un issue describiendo el cambio antes de trabajar en algo grande.
2. Crea una rama desde `main`.
3. Formatea el código: `./scripts/format.sh`
4. Asegúrate de que pasan los tests: `swift test --package-path Packages/StainKit`
5. Abre un pull request.

## Reglas

- **No copies código de Paintbrush** (GPL-3.0): el proyecto es MIT. Solo se toman ideas y UX.
- El código de `StainKit` no puede importar AppKit ni SwiftUI.
- Todo cambio en `StainKit` debe venir con tests (Swift Testing).
