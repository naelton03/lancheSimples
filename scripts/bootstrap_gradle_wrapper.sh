#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WRAPPER_JAR="$ROOT_DIR/android/gradle/wrapper/gradle-wrapper.jar"

if [[ -f "$WRAPPER_JAR" ]]; then
  echo "Gradle wrapper jar already exists."
  exit 0
fi

if ! command -v gradle >/dev/null 2>&1; then
  echo "Gradle não encontrado no PATH. Instale o Gradle para gerar o wrapper localmente." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_DIR/build.gradle" <<'GRADLE'
tasks.register('noop')
GRADLE

gradle -p "$TMP_DIR" wrapper >/dev/null
mkdir -p "$(dirname "$WRAPPER_JAR")"
cp "$TMP_DIR/gradle/wrapper/gradle-wrapper.jar" "$WRAPPER_JAR"

echo "Gradle wrapper jar gerado em $WRAPPER_JAR"
