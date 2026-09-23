# itch.io Web release checklist

The production export is the single-threaded Compatibility Web preset named `Web`.

Run `tools/package_web.ps1` from PowerShell. It exports `build/web/index.html`, rejects development/reference leakage and itch.io file/path limits, then creates `build/itch/californication-web.zip` with Web files at the archive root.

Configure the itch.io project as an HTML Game with a 960×720 desktop embed, click-to-play enabled, scrollbars disabled, and fullscreen overlay disabled by default so it does not cover the pause control. Enable Mobile Friendly only after testing dynamic fullscreen on a real or emulated mobile browser.

Before upload, serve the unpacked `build/web/` directory over HTTP and check browser console, keyboard, touch/swipe cancellation, safe-area resize/orientation, tab focus suspend/resume, post-gesture audio unlock, frontend-to-Run-Intro flow, pause/failure/retry, all nine scenarios, and cinematic fallback. Repeat the same matrix on an itch.io draft/restricted page in incognito desktop and mobile browsers.
