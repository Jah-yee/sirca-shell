// Glass Desktop: live theme for Spotify (a Spicetify extension).
// Spotify reads the theme's colours once, at start, and its embedded browser does not follow the desktop's light/dark
// preference. glass-mode rewrites colors.css / user.css inside the app folder on every mode or colour-theme switch
// (spicetify refresh); this watches those two files and re-links them when they change: no restart, the music keeps playing.
(function glassLive() {
    const files = ["colors.css", "user.css"], seen = {};
    async function check() {
        for (const f of files) {
            try {
                const text = await (await fetch(f + "?glass=" + Date.now(), { cache: "no-store" })).text();
                if (seen[f] === undefined) { seen[f] = text; continue }
                if (seen[f] === text) continue;
                seen[f] = text;
                const link = [...document.querySelectorAll('link[rel="stylesheet"]')].find(l => (l.getAttribute("href") || "").split("?")[0].replace(/^\//, "") === f);
                if (!link) continue;
                const next = link.cloneNode(); next.href = f + "?glass=" + Date.now();
                next.onload = () => link.remove();                     // swap after the new one is ready: no unstyled flash
                link.after(next);
                themePip();
            } catch (e) { /* the file is being rewritten: next round */ }
        }
    }
    // Spotify's Miniplayer is a separate document (Document Picture-in-Picture): the theme does not reach it. Copy the
    // colours and the stylesheet into it and mark its root, user.css carries the "html.glass-pip" rules.
    let pipDoc = null;
    function themePip() {
        if (!pipDoc || !pipDoc.documentElement) return;
        let st = pipDoc.getElementById("glass-pip-style");
        if (!st) { st = pipDoc.createElement("style"); st.id = "glass-pip-style"; pipDoc.head.appendChild(st) }
        st.textContent = (seen["colors.css"] || "") + "\n" + (seen["user.css"] || "");
        pipDoc.documentElement.classList.add("glass-pip");
        fixCovers();
    }
    // The mini player's cover comes as <img src="spotify:image:<id>">, an internal address that Spotify resolves itself. Seen
    // 2026-09-21: it stayed at data-image-status="loading" for good (an empty square), while the same picture loads fine from
    // the public address the main window uses. Give a picture 1.5 s, then point it there.
    function fixCovers() {
        if (!pipDoc) return;
        for (const img of pipDoc.querySelectorAll('img[src^="spotify:image:"]')) {
            if (img.dataset.glassRetry) continue;
            img.dataset.glassRetry = "1";
            const src = img.getAttribute("src");
            setTimeout(() => { if (img.isConnected && img.getAttribute("src") === src && !img.naturalWidth) img.src = "https://i.scdn.co/image/" + src.split(":").pop(); delete img.dataset.glassRetry; }, 1500);
        }
    }
    try {
        if (window.documentPictureInPicture) documentPictureInPicture.addEventListener("enter", ev => {
            pipDoc = ev.window.document; themePip();
            [300, 1200].forEach(ms => setTimeout(themePip, ms));                       // Spotify fills the document after the event
            new ev.window.MutationObserver(fixCovers).observe(pipDoc.documentElement, { subtree: true, childList: true, attributes: true, attributeFilter: ["src"] });   // song changes
            ev.window.addEventListener("pagehide", () => { pipDoc = null });
        });
    } catch (e) {}
    // (kept for a future in-window mini layout) the current song's high-resolution cover as --glass-cover
    function cover() {
        try {
            const m = Spicetify.Player.data && Spicetify.Player.data.item && Spicetify.Player.data.item.metadata || {};
            const id = (m.image_xlarge_url || m.image_large_url || m.image_url || "").split(":").pop();
            document.documentElement.style.setProperty("--glass-cover", id ? 'url("https://i.scdn.co/image/' + id + '")' : "none");
        } catch (e) {}
    }
    (function waitPlayer() { if (!(window.Spicetify && Spicetify.Player && Spicetify.Player.addEventListener)) { setTimeout(waitPlayer, 500); return }
        Spicetify.Player.addEventListener("songchange", cover); cover(); })();
    setInterval(check, 1200);
    check();
})();
