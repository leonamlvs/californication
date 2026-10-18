# V6 device validation - in progress

2026-10-18. Last completed milestone: V5. No V6 visual approval or performance
acceptance has been recorded. Android is available; iPhone is unavailable.

## Start the phone preview

### HTTPS correction

The Android user reached the HTTP page but Godot rejected it with
`Secure Context - Check web server configuration (use HTTPS)`. Using HTTPS on
the HTTP port produced `ERR_SSL_PROTOCOL_ERROR`. This confirms network access,
not a rendering/device failure. Use the HTTPS listener instead:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/prepare_island_https.ps1 -Address 192.168.100.126
node tools/serve_production_web.mjs --https
```

Open **https://192.168.100.126:8068/index.html**. A self-signed certificate
warning is expected; use Chrome's Advanced/Proceed option for this local
preview if available. No root certificate installation or browser security
flags are required by this procedure. Report if proceeding is unavailable.
The seven-day certificate/private key stay in ignored `build/` outside the
served directory. Regenerate for a changed IP or expiration and restart the
server. `https-checks.json` records host-side TLS hostname/certificate checks,
HTML and MP4 range responses; Android HTTPS playback remains pending.

The earlier HTTP setup below is retained for diagnostics only; use HTTPS for
Android game testing.

Run `node tools/serve_production_web.mjs --lan` on the computer. This serves the
existing production export on TCP 8067; it does not expose repository sources.
Connect Android Chrome to the same LAN and open
http://192.168.100.126:8067/index.html. Keep the computer awake.
The default command without `--lan` remains localhost-only on 8066.
If the computer address changes, use its current Ethernet/Wi-Fi IPv4 address.

`lan-checks.json` verifies HTML and MP4 ranges from the host computer only.
The Windows Ethernet network is Public; no firewall settings were changed.
If the phone cannot connect, first check the address/network and then diagnose
firewall or Wi-Fi client isolation. Do not turn off the firewall.

## Android observation checklist

Record phone model, Android version, Chrome version, orientation, battery-saving
mode, and any error text. Initial download is approximately 48 MB uncompressed.

1. Reload in portrait. Confirm loading, video, continuous live pullback, then
   rotating island. If a Start action appears, tap it once.
2. Confirm the full 4:3 picture is visible with black unused space.
3. Leave attract running for at least 75 seconds (one full island rotation).
   Look for beach gaps, rectangular water edges, stutter or flashing.
4. Rotate to landscape and back. Confirm picture alignment and no restart.
5. Reload and briefly switch apps during playback; return and check continuation.
6. At attract, tap a black border once. Confirm one logo sequence and Player Select,
   with no skipped screen or stray confirmation.
7. Provide a short recording of loading through attract and any visible issue.

These observations establish functional/visual evidence, not a measured 30 fps
result. Recording may affect performance. Separate unrecorded browser/GPU frame
measurements are still required for performance acceptance (60 fps desktop,
30 fps phone); JavaScript animation callback cadence alone is insufficient.

## Evidence and open gates

- Fresh thirteen-check V5 baseline: `baseline-before/results.json`.
- LAN server check: `lan-checks.json` (host only).
- Android connection/model/results: awaiting user feedback.
- Desktop and Android measured overlap/steady-attract performance: pending.
- iPhone Safari: unavailable, pending.
- Visual review 3: pending; do not mark V6 complete without explicit approval
  and the required actual-device evidence.
