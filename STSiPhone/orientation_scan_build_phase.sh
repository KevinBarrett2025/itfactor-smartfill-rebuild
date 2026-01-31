#!/bin/bash
# STS Orientation Forensics - Xcode Build Phase
# Auto-scans for orientation patterns and logs to brain

set -e

BRAIN_PATH="/Users/kevinbarrett/SelfTapeStudio/Development/BRAIN/STS_MasterBrain.sqlite3"
SCANNER_PATH="$SRCROOT/Tools/sts_orientation_scan.py"
REPO_ROOT="$SRCROOT"

echo "🔍 STS Orientation Forensics: Starting build-time scan..."

# Check prerequisites
if [ ! -f "$BRAIN_PATH" ]; then
  echo "⚠️ Brain DB not found at $BRAIN_PATH"
  echo "   Run the SQL migration once to create tables"
  exit 0  # Don't fail build, just warn
fi

if [ ! -f "$SCANNER_PATH" ]; then
  echo "⚠️ Scanner script not found at $SCANNER_PATH"
  exit 0  # Don't fail build
fi

# Only run scanner in Debug builds or when explicitly requested
if [ "${CONFIGURATION}" = "Debug" ] || [ "${STS_FORCE_ORIENTATION_SCAN}" = "1" ]; then
  echo "🔍 Running orientation pattern scan..."
  python3 "$SCANNER_PATH" --repo-root "$REPO_ROOT" --brain "$BRAIN_PATH" || {
    echo "❌ Orientation scan failed"
    exit 1
  }
  echo "✅ Orientation scan completed"
else
  echo "⚪ Skipping orientation scan (Release build)"
fi

echo "🔍 STS Orientation Forensics: Build phase complete"