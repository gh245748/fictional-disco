#!/usr/bin/env bash
# Fetches the bundled OFL fonts from Google Fonts into assets/fonts/.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets/fonts

fetch() {
  local family="$1" axis="$2" out="$3"
  local css url
  css=$(curl -fsSL -A "Mozilla/4.0" "https://fonts.googleapis.com/css2?family=${family}:${axis}")
  url=$(printf '%s' "$css" | grep -o 'https://fonts.gstatic.com/[^)]*\.ttf' | head -n1)
  [ -n "$url" ] || { echo "no ttf url for $out" >&2; exit 1; }
  curl -fsSL "$url" -o "assets/fonts/$out"
}

fetch "Cormorant+Garamond" "wght@500" CormorantGaramond-Medium.ttf
fetch "Cormorant+Garamond" "wght@600" CormorantGaramond-SemiBold.ttf
fetch "Cormorant+Garamond" "ital,wght@1,500" CormorantGaramond-MediumItalic.ttf
fetch "Manrope" "wght@400" Manrope-Regular.ttf
fetch "Manrope" "wght@500" Manrope-Medium.ttf
fetch "Manrope" "wght@600" Manrope-SemiBold.ttf
fetch "Manrope" "wght@700" Manrope-Bold.ttf
