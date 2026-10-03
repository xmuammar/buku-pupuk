#!/usr/bin/env bash
set -euo pipefail
# Native build uses official SDK tools and the already-installed shared web dependencies.
TASK_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
: "${ANDROID_SDK_ROOT:?Set ANDROID_SDK_ROOT to the Android SDK directory}"
: "${BUKU_KEYSTORE:?Set BUKU_KEYSTORE to the private release PKCS12 keystore}"
: "${BUKU_KEY_PASSWORD_FILE:?Set BUKU_KEY_PASSWORD_FILE to a private password file}"
TASK_TOOLS="$ANDROID_SDK_ROOT/build-tools/35.0.0"
TASK_ANDROID_JAR="$ANDROID_SDK_ROOT/platforms/android-35/android.jar"
TASK_BOOT="$TASK_ANDROID_JAR:$TASK_TOOLS/core-lambda-stubs.jar"
TASK_BUILD="$TASK_ROOT/android/build"
TASK_OUTPUT="${BUKU_APK_OUTPUT:-$TASK_BUILD/Buku-Pupuk-Android-v1.0.0.apk}"
mkdir -p "$TASK_BUILD/classes" "$TASK_BUILD/dex" "$(dirname "$TASK_OUTPUT")"
node "$TASK_ROOT/android/scripts/build-web.mjs"
"$TASK_TOOLS/aapt2" compile --dir "$TASK_ROOT/android/native/res" -o "$TASK_BUILD/resources.zip"
"$TASK_TOOLS/aapt2" link --auto-add-overlay -I "$TASK_ANDROID_JAR" --manifest "$TASK_ROOT/android/native/AndroidManifest.xml" -R "$TASK_BUILD/resources.zip" -A "$TASK_ROOT/android/native/assets" --java "$TASK_BUILD/generated" -o "$TASK_BUILD/resources.apk"
mapfile -t TASK_SOURCES < <(find "$TASK_ROOT/android/native/src" "$TASK_BUILD/generated" -name '*.java')
if command -v javac >/dev/null 2>&1; then
  javac -source 8 -target 8 -bootclasspath "$TASK_BOOT" -d "$TASK_BUILD/classes" "${TASK_SOURCES[@]}"
else
  : "${ECJ_JAR:?Install a JDK or set ECJ_JAR to Eclipse Java Compiler jar}"
  java -jar "$ECJ_JAR" -1.8 -bootclasspath "$TASK_BOOT" -d "$TASK_BUILD/classes" "${TASK_SOURCES[@]}"
fi
python3 - "$TASK_BUILD" <<'PY'
import sys,zipfile
from pathlib import Path
build=Path(sys.argv[1])
with zipfile.ZipFile(build/'classes.jar','w') as z:
 for f in (build/'classes').rglob('*.class'):z.write(f,f.relative_to(build/'classes'))
PY
"$TASK_TOOLS/d8" --lib "$TASK_ANDROID_JAR" --min-api 26 --output "$TASK_BUILD/dex" "$TASK_BUILD/classes.jar"
python3 - "$TASK_BUILD" <<'PY'
import sys,zipfile,shutil
from pathlib import Path
build=Path(sys.argv[1]);shutil.copyfile(build/'resources.apk',build/'unsigned.apk')
with zipfile.ZipFile(build/'unsigned.apk','a') as z:
 for dex in (build/'dex').glob('*.dex'):z.write(dex,dex.name)
PY
"$TASK_TOOLS/zipalign" -f 4 "$TASK_BUILD/unsigned.apk" "$TASK_BUILD/aligned.apk"
"$TASK_TOOLS/apksigner" sign --ks "$BUKU_KEYSTORE" --ks-key-alias buku-pupuk --ks-pass "file:$BUKU_KEY_PASSWORD_FILE" --out "$TASK_OUTPUT" "$TASK_BUILD/aligned.apk"
"$TASK_TOOLS/apksigner" verify --verbose --print-certs "$TASK_OUTPUT"
"$TASK_TOOLS/aapt" dump badging "$TASK_OUTPUT" | head -n 7
