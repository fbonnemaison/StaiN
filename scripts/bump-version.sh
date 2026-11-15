#!/bin/sh
# Sube la versión de StaiN, la anota en CHANGELOG.md, hace commit y crea la etiqueta vX.Y.Z.
#
# Uso: ./scripts/bump-version.sh major|minor|patch|X.Y.Z
#
# - MARKETING_VERSION (la que ve el usuario) sigue Versionado Semántico.
# - CURRENT_PROJECT_VERSION (número de compilación) es el número de commits + 1, siempre creciente.
# - Lo que haya en "## [Sin publicar]" del CHANGELOG pasa a la nueva versión con la fecha de hoy.
set -eu
cd "$(dirname "$0")/.."

if [ $# -ne 1 ]; then
    echo "Uso: $0 major|minor|patch|X.Y.Z" >&2
    exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
    echo "Hay cambios sin confirmar: haz commit antes de subir la versión." >&2
    exit 1
fi

current=$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)
IFS=. read -r major minor patch <<EOV
$current
EOV
case "$1" in
    major) new="$((major + 1)).0.0" ;;
    minor) new="$major.$((minor + 1)).0" ;;
    patch) new="$major.$minor.$((patch + 1))" ;;
    *.*.*) new="$1" ;;
    *) echo "Versión no válida: $1" >&2; exit 1 ;;
esac
if git rev-parse -q --verify "refs/tags/v$new" >/dev/null; then
    echo "La etiqueta v$new ya existe." >&2
    exit 1
fi
build=$(( $(git rev-list --count HEAD) + 1 ))
today=$(date +%Y-%m-%d)

sed -i '' "s/^\( *MARKETING_VERSION: \)\".*\"/\1\"$new\"/" project.yml
sed -i '' "s/^\( *CURRENT_PROJECT_VERSION: \)\".*\"/\1\"$build\"/" project.yml

# CHANGELOG: nueva sección con la fecha y enlaces de comparación.
python3 - "$new" "$current" "$today" <<'PY'
import re, sys
new, previous, today = sys.argv[1:]
path = "CHANGELOG.md"
text = open(path, encoding="utf-8").read()
text = text.replace("## [Sin publicar]\n", f"## [Sin publicar]\n\n## [{new}] - {today}\n", 1)
text = re.sub(r"\[Sin publicar\]: (.*)/compare/v[^.]+\.[^.]+\.[^.]+\.\.\.HEAD",
              rf"[Sin publicar]: \1/compare/v{new}...HEAD\n[{new}]: \1/compare/v{previous}...v{new}", text, count=1)
open(path, "w", encoding="utf-8").write(text)
PY

xcodegen generate --quiet
git add project.yml StaiN.xcodeproj CHANGELOG.md
git commit -q -m "Versión $new (compilación $build)"
git tag -a "v$new" -m "StaiN $new"
echo "StaiN $new (compilación $build): commit y etiqueta v$new creados. No se ha subido nada."
