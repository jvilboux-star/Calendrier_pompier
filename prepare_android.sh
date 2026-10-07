#!/usr/bin/env bash
set -euo pipefail

TMP_DIR="/tmp/pompier_calendriers_android"
rm -rf "$TMP_DIR"

# Le depot reste leger : Codemagic genere le squelette Android avec la version
# de Flutter disponible sur sa machine de build.
flutter create \
  --platforms=android \
  --org=fr.sapeurpompier \
  --project-name=pompier_calendriers \
  "$TMP_DIR"

rm -rf android
cp -R "$TMP_DIR/android" ./android

MANIFEST="android/app/src/main/AndroidManifest.xml"
python3 - <<'PY'
from pathlib import Path
p = Path("android/app/src/main/AndroidManifest.xml")
s = p.read_text(encoding="utf-8")
perms = '''    <uses-permission android:name="android.permission.INTERNET" />\n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />\n    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />\n'''
if 'android.permission.ACCESS_FINE_LOCATION' not in s:
    s = s.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n',
                  '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n' + perms,
                  1)
s = s.replace('android:label="pompier_calendriers"', 'android:label="Tournee Calendriers"')
p.write_text(s, encoding="utf-8")
PY

echo "Projet Android cree et permissions GPS/Internet ajoutees."
