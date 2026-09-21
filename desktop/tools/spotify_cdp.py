#!/usr/bin/python3
"""Tiny Chrome DevTools client for the running Spotify (127.0.0.1:9222).
   cdp.py shot OUT.png            screenshot of Spotify's own page (nothing else on the screen)
   cdp.py eval 'JS'               evaluate, print the JSON result
   cdp.py css FILE                (re)inject FILE as a <style id=glass-dev> for live iteration"""
import base64, json, sys, urllib.request, websocket
import os
_all = [x for x in json.load(urllib.request.urlopen("http://127.0.0.1:9222/json")) if x["type"] == "page"]
_want = os.environ.get("CDP_TITLE")   # CDP_TITLE=MiniPlayer picks the miniplayer page
t = ([x for x in _all if _want and _want in x.get("title", "")] or [x for x in _all if "MiniPlayer" not in x.get("title", "")])[0]
ws = websocket.create_connection(t["webSocketDebuggerUrl"], origin="http://127.0.0.1:9222", timeout=20)
n = 0
def call(method, **params):
    global n; n += 1; ws.send(json.dumps({"id": n, "method": method, "params": params}))
    while True:
        m = json.loads(ws.recv())
        if m.get("id") == n: return m.get("result", m)
cmd = sys.argv[1]
if cmd == "shot":
    open(sys.argv[2], "wb").write(base64.b64decode(call("Page.captureScreenshot", format="png")["data"])); print("saved", sys.argv[2])
elif cmd == "eval":
    r = call("Runtime.evaluate", expression=sys.argv[2], returnByValue=True); print(json.dumps(r.get("result", {}).get("value", r), indent=1)[:6000])
elif cmd == "media":   # cdp.py media light|dark|off  (emulates the system colour-scheme preference)
    f = [] if sys.argv[2] == "off" else [{"name": "prefers-color-scheme", "value": sys.argv[2]}]
    print(call("Emulation.setEmulatedMedia", features=f)); ws.recv if False else None
    import time; time.sleep(1.0); open(sys.argv[3], "wb").write(base64.b64decode(call("Page.captureScreenshot", format="png")["data"])) if len(sys.argv) > 3 else None
elif cmd == "size":    # cdp.py size W H OUT.png | size off   (emulates the page size; the real window is not touched)
    if sys.argv[2] == "off": print(call("Emulation.clearDeviceMetricsOverride"))
    else:
        call("Emulation.setDeviceMetricsOverride", width=int(sys.argv[2]), height=int(sys.argv[3]), deviceScaleFactor=1, mobile=False)
        import time; time.sleep(1.2); open(sys.argv[4], "wb").write(base64.b64decode(call("Page.captureScreenshot", format="png")["data"])); print("saved")
elif cmd == "css":
    css = open(sys.argv[2]).read()
    js = "(()=>{let s=document.getElementById('glass-dev'); if(!s){s=document.createElement('style'); s.id='glass-dev'; document.head.appendChild(s)} s.textContent=%s; return s.textContent.length})()" % json.dumps(css)
    print(call("Runtime.evaluate", expression=js, returnByValue=True)["result"].get("value"))
