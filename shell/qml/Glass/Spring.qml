// The one motion curve: an ease-out that lands with a very light bounce (about 3 % past the target, then settles),
// used for every shape and hover change. Surfaces add `Config.bounceRoom` to their blur/input outline so the glass
// covers the overshoot too.
import QtQuick
NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.85 }
