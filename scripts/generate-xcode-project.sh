#!/usr/bin/env bash
set -euo pipefail

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen is required. Install with: brew install xcodegen"
  exit 1
fi

xcodegen generate
open MealRecap.xcodeproj
