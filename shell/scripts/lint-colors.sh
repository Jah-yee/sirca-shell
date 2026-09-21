#!/usr/bin/env bash
# lint-colors.sh — light / dark safety net for the shell's QML. Anything drawn ON the glass must take its colour from Config
# (fg(), fgSolid, onFg, ink, inkDim, glassTint(), popSurface, accent …): a literal white or near-black looks right in one
# mode and is unreadable in the other. This flags literal colours; a line that is right in both modes (text on a red badge,
# a shadow, a mask, a colour swatch) says so with a trailing "// literal-ok" comment.
# Exit 1 when something is flagged. sirca-shell-reload prints the findings (it does not refuse the reload for them).
cd "$(dirname "$(readlink -f "$0")")/.." || exit 2
skip='qml/Config.qml|qml/Capture.qml|qml/EditScene.qml|qml/Glass/LobeShape.qml|qml/Wallpaper.qml|qml/control/'
hits="$(grep -rnE '"(white|black)"|"#[0-9a-fA-F]{3,8}"|Qt\.rgba\( *[0-9./]+ *, *[0-9./]+ *, *[0-9./]+ *, *[^)]*\)' qml --include=*.qml \
  | grep -vE "$skip" | grep -v 'literal-ok' \
  | grep -vE 'Qt\.rgba\(0, 0, 0, ' \
  | grep -vE 'fillColor: "black"|maskSource|GradientStop \{ position: [0-9.]+; color: "(white|black)"' \
  | grep -vE '229/255, 72/255, 77/255|"#e5484d"|1, 0\.30, 0\.32' )"
[ -z "$hits" ] && { echo "lint-colors: clean"; exit 0; }
echo "lint-colors: literal colours that may break light or dark mode (use Config.*, or mark the line // literal-ok):"
echo "$hits" | cut -c1-190 | sed 's/^/  /'
exit 1
