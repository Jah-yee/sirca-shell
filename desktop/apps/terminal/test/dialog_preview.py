#!/usr/bin/python3
"""Render Ghostty's close confirmation (a libadwaita AlertDialog) with the Glass stylesheets, to a PNG, by itself.
   dialog_preview.py <out.png> [css ...]
The window renders its own node tree to a texture (no screen capture). A fake 62 % terminal background with some text
stands in for Ghostty's surface so the frosted sheet has something to blur."""
import sys, os, gi
gi.require_version("Gtk", "4.0"); gi.require_version("Adw", "1"); gi.require_version("Gdk", "4.0")
from gi.repository import Gtk, Adw, Gdk, GLib, Gsk, Graphene

out = sys.argv[1]; sheets = sys.argv[2:]
app = Adw.Application(application_id="onur.glass.dialogpreview")

def activate(app):
    disp = Gdk.Display.get_default()
    for path in sheets:
        p = Gtk.CssProvider(); p.load_from_path(path)
        Gtk.StyleContext.add_provider_for_display(disp, p, Gtk.STYLE_PROVIDER_PRIORITY_USER + 1)
    base = Gtk.CssProvider(); base.load_from_string("window.fake { background: rgba(24,25,27,0.62); } label.term { font-family: 'JetBrains Mono', monospace; font-size: 13px; color: #cfd3d6; }")
    Gtk.StyleContext.add_provider_for_display(disp, base, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    win = Adw.ApplicationWindow(application=app, title="glass-dialog-preview", default_width=900, default_height=560)
    win.add_css_class("fake")
    text = "\n".join("user@host ~/project  $ cargo build --release   # line %02d  ░▒▓ lorem ipsum dolor sit amet" % i for i in range(30))
    lab = Gtk.Label(label=text, xalign=0, yalign=0); lab.add_css_class("term"); lab.set_margin_start(14); lab.set_margin_top(10)
    win.set_content(lab)
    win.present()
    dlg = Adw.AlertDialog(heading="Close Window?", body="All terminal sessions in this window will be terminated.")
    dlg.add_response("cancel", "Cancel"); dlg.add_response("close", "Close")
    dlg.set_response_appearance("close", Adw.ResponseAppearance.DESTRUCTIVE)
    dlg.set_default_response("cancel"); dlg.set_close_response("cancel")
    GLib.timeout_add(500, lambda: (dlg.present(win), False)[1])
    def shoot():
        w, h = win.get_width(), win.get_height()
        snap = Gtk.Snapshot(); Gtk.WidgetPaintable(widget=win).snapshot(snap, w, h); node = snap.to_node()
        tex = win.get_renderer().render_texture(node, Graphene.Rect().init(0, 0, w, h))
        tex.save_to_png(out); print("saved", out, w, h); app.quit(); return False
    GLib.timeout_add(1900, shoot)
app.connect("activate", activate); app.run([])
