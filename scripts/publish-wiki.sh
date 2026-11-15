#!/bin/sh
# Publica las páginas de docs/wiki/ en la wiki de GitHub (repositorio StaiN.wiki.git).
#
# Uso: ./scripts/publish-wiki.sh
#
# GitHub crea el repositorio de la wiki cuando se guarda la primera página desde la web
# (pestaña Wiki › "Create the first page"). Hay que hacerlo una vez antes de usar este script.
# Las páginas de la wiki que no estén en docs/wiki/ se borran: docs/wiki/ es la fuente.
set -eu
cd "$(dirname "$0")/.."

remote=$(git remote get-url origin | sed 's/\.git$//').wiki.git
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if ! git clone -q "$remote" "$work" 2>/dev/null; then
    echo "No existe la wiki ($remote)." >&2
    echo "Créala una vez desde GitHub: pestaña Wiki › Create the first page › Save page." >&2
    exit 1
fi

find "$work" -maxdepth 1 -name '*.md' -delete
cp docs/wiki/*.md "$work/"
cd "$work"
git add -A
if git diff --cached --quiet; then
    echo "La wiki ya está al día."
    exit 0
fi
git commit -q -m "Wiki: actualizar desde docs/wiki ($(cd - >/dev/null && git rev-parse --short HEAD))"
git push -q origin HEAD
echo "Wiki publicada: ${remote%.wiki.git}/wiki"
