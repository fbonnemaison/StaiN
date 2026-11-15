#!/usr/bin/env python3
"""Regenera StaiN/Resources/Localizable.xcstrings a partir de las claves que extrae el compilador.

Uso: compila la app (xcodebuild ... build) y luego
    python3 scripts/update-strings.py <carpeta con los .stringsdata>
Las traducciones al inglés están en scripts/translations_en.json; las claves sin traducir se avisan.
"""
import glob, json, os, sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
keys = {}
for path in glob.glob(os.path.join(sys.argv[1], "*.stringsdata")):
    for entries in json.load(open(path)).get("tables", {}).values():
        for entry in entries:
            keys.setdefault(entry["key"], entry.get("comment"))

english = json.load(open(os.path.join(root, "scripts", "translations_en.json")))
strings = {}
missing = []
for key in sorted(keys):
    if key not in english:
        missing.append(key)
        continue
    strings[key] = {
        "localizations": {"en": {"stringUnit": {"state": "translated", "value": english[key]}}}
    }

catalog = {"sourceLanguage": "es", "strings": strings, "version": "1.0"}
out = os.path.join(root, "StaiN", "Resources", "Localizable.xcstrings")
with open(out, "w", encoding="utf-8") as f:
    json.dump(catalog, f, ensure_ascii=False, indent=2, sort_keys=True)
    f.write("\n")
print(f"{len(strings)} claves traducidas")
for key in missing:
    print("SIN TRADUCIR:", repr(key))
sys.exit(1 if missing else 0)
