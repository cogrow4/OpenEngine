#!/usr/bin/env bash
# Build a debug .app bundle from the SwiftPM output.
# Usage: ./make_app.sh  (produces build/OpenEngine.app)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
swift build -c release
APP="$ROOT/build/OpenEngine.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$ROOT/.build/release/OpenEngine" "$APP/Contents/MacOS/OpenEngine"
cp "$ROOT/Settings.app/Info.plist" "$APP/Contents/Info.plist"
# Bundle a copy of the curated manifest so it works offline immediately.
cp "$ROOT/library/manifest.json" "$APP/Contents/Resources/manifest.json"
# Mark as the env var so the app points at the bundled copy.
cat > "$APP/Contents/MacOS/launch.sh" <<'EOS'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")/../.." && pwd)"
export OPENENGINE_MANIFEST="file://$DIR/Contents/Resources/manifest.json"
exec "$DIR/Contents/MacOS/OpenEngine"
EOS
chmod +x "$APP/Contents/MacOS/launch.sh"
echo "Built $APP"
echo "Run with:  open \"$APP\""
echo "Or direct: \"$APP/Contents/MacOS/launch.sh\""
