#!/bin/bash

REPORT_DIR="audit_reports"
mkdir -p "$REPORT_DIR"

TOTAL=9
DONE=0

progress() {
  DONE=$((DONE + 1))
  PERCENT=$((DONE * 100 / TOTAL))
  FILLED=$((PERCENT / 2))
  EMPTY=$((50 - FILLED))
  BAR=$(printf "%${FILLED}s" | tr ' ' '=')
  SPACE=$(printf "%${EMPTY}s")
  echo "[$BAR$SPACE] $PERCENT% ($DONE/$TOTAL) $1"
}

run_task() {
  NAME="$1"
  CMD="$2"
  OUT="$REPORT_DIR/$3"

  echo "Running: $NAME"
  bash -c "$CMD" > "$OUT" 2>&1

  if [ $? -eq 0 ]; then
    progress "PASS: $NAME"
  else
    progress "WARN/FAIL: $NAME - check $OUT"
  fi
}

echo "======================================"
echo " Flutter Parallel Audit System"
echo "======================================"

echo "Preparing project..."
flutter pub get > "$REPORT_DIR/pub_get.txt" 2>&1

run_task "Dart Analyze" \
  "dart analyze --fatal-infos --fatal-warnings" \
  "dart_analyze.txt" &

run_task "Debug print check" \
  "grep -Rni 'print(' lib/ || true" \
  "debug_prints.txt" &

run_task "debugPrint check" \
  "grep -Rni 'debugPrint' lib/ || true" \
  "debug_print_func.txt" &

run_task "Secret scan" \
  "grep -RniE 'api_key|apikey|secret|token|password|bearer|private_key|client_secret' lib/ .env* pubspec.yaml 2>/dev/null || true" \
  "secrets.txt" &

run_task "TODO/FIXME check" \
  "grep -RniE 'TODO|FIXME|HACK' lib/ || true" \
  "todo_fixme.txt" &

run_task "Large Dart files" \
  "find lib -name '*.dart' -exec wc -l {} + | sort -nr | head -30" \
  "large_dart_files.txt" &

run_task "Large assets" \
  "find assets -type f -size +500k 2>/dev/null || true" \
  "large_assets.txt" &

run_task "Unused/outdated packages" \
  "flutter pub outdated" \
  "pub_outdated.txt" &

run_task "Flutter test" \
  "flutter test" \
  "flutter_test.txt" &

wait

echo ""
echo "Building release APK..."
flutter build apk --release --obfuscate --split-debug-info=debug-info/ \
  > "$REPORT_DIR/release_build.txt" 2>&1

if [ $? -eq 0 ]; then
  echo "Release build: PASS"
else
  echo "Release build: FAIL - check $REPORT_DIR/release_build.txt"
fi

echo ""
echo "======================================"
echo " Audit finished"
echo " Reports saved in: $REPORT_DIR"
echo "======================================"

ls -lh "$REPORT_DIR"
