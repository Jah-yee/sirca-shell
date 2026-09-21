// Glass: translucent apps. Spotify shows its window BEFORE it sets the window class, so a KWin window rule for class
// "spotify" never matches it. This follows every window and applies the opacity whenever its class (or title) settles.
// Apps: "class=active/inactive" in percent, from the script's config key "apps" (kwinrc [Script-glasstranslucent]).
function table() {
    const out = {};
    for (const part of String(readConfig("apps", "spotify=80/78")).split(/[,;\s]+/)) {
        const m = /^([^=]+)=(\d+)(?:\/(\d+))?$/.exec(part);
        if (m) out[m[1].toLowerCase()] = [Number(m[2]) / 100, Number(m[3] || m[2]) / 100];
    }
    return out;
}
const apps = table();
function apply(w) {
    if (!w || !w.normalWindow) return;
    const o = apps[String(w.resourceClass).toLowerCase()] || apps[String(w.resourceName).toLowerCase()];
    if (!o) return;
    // the glass effect decides about blur when a window appears (class still empty then) and again when its geometry
    // changes: nudge the width by a pixel and back, once, so the late class gets its blur (effect builds after glass16
    // listen to the class themselves; the nudge is then a no-op)
    if (!w.glassNudged && !w.fullScreen) { w.glassNudged = true
        const g = w.frameGeometry; w.frameGeometry = { x: g.x, y: g.y, width: g.width + 1, height: g.height }; w.frameGeometry = { x: g.x, y: g.y, width: g.width, height: g.height } }
    const want = w.active ? o[0] : o[1];
    if (Math.abs(w.opacity - want) > 0.004) w.opacity = want;
}
function follow(w) {
    apply(w);
    w.windowClassChanged.connect(() => apply(w));
    w.captionChanged.connect(() => apply(w));
    w.activeChanged.connect(() => apply(w));
}
workspace.windowList().forEach(follow);
workspace.windowAdded.connect(follow);
