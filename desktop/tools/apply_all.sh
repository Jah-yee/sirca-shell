#!/bin/bash
# apply_all.sh apply|revert — every generated piece at once (user level). Plugins built from qt/ need tools/install_qt.sh (root) once.
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
case "${1:-}" in apply) "$D/apply_kde.sh" apply; "$D/apply_gtk.sh" apply ;; revert) "$D/apply_gtk.sh" revert || true; "$D/apply_kde.sh" revert || true ;; *) echo "usage: $0 apply|revert"; exit 2 ;; esac
