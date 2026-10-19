# Full screenshot ocean — replacement for the processed-water attempt

2026-10-18; HEAD `64a0912c0eba0f2bfabb89059a1e30d7e3b40f71` plus working changes.
The user rejected the extracted/cleaned water and requested a proportional flat
screenshot beneath the 3D island. This implementation follows that correction.

## Current implementation

`frontend/island/live/assets/ocean-frame.png` is a **byte-identical copy** of
`docs/evidence/island_intro/v0/reference/original_0199.png`, the lossless 960x720
active picture used to build the island. Land, beach, cyan shallows and waves
all remain in the screenshot. No coastline selection, land removal, inpainting,
wave separation or recoloring is applied.

The image is mapped to **32 x 24.536174277 world units**, centered at zero, using
the island's existing reference calibration. This compensates for the reference
camera elevation and aligns the photographed beach with the mesh. The screenshot
rotates with the island. Only its outer rectangular margin fades into the existing
source-derived deep-water tile to cover the large ocean plane. There is no beach
mask, and waves remain frozen in the image until a later shader request.

Edit the single `ocean-frame.png` in Krita/Photoshop, retaining 960x720 dimensions
and coastline placement. Adjust `map_size`/`map_center` in runtime `ocean.tres`
only if deliberately changing its placement. The previous ORA/cleaning scripts
are superseded; do not use them to update the current screenshot. Their processed
runtime color/mask images are excluded from the Web package.

## Review and checks

- Review: **http://127.0.0.1:8070/index.html**.
- Android: **https://192.168.100.126:8068/index.html**, reload after export.
- Baseline Task 23/24 checks, Godot import, native reveal/close beach/full-turn
  captures and final thirteen production/package checks pass. The resource pack
  audit requires the screenshot and excludes the rejected processed textures.
- `checks.json` verifies source identity, static rendering, full-turn alignment,
  actual browser capture, unchanged island geometry/atlas/camera/handoff/controller.
- Browser screenshots and recording are actual exported-game presentation.
  Native/desktop captures are functional evidence, not phone performance results.

```powershell
python tools/validate_island_production.py
godot --path . --rendering-method gl_compatibility --resolution 960x720 tests/cli/OceanColorCapture.tscn -- --output=res://build/ocean-frame/captures
$env:ISLAND_REVIEW_FOLDER='ocean-frame'
node tools/capture_ocean_color_web.mjs
& 'C:/Program Files/Blender Foundation/Blender 4.2/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/finalize_ocean_frame_review.py
node tools/serve_ocean_color_review.mjs --frame
```

To restore the initial screenshot, copy the authoritative PNG directly to
`frontend/island/live/assets/ocean-frame.png`; this overwrites any manual edits.
Tools remain Godot 4.7.2, Blender 4.2.2/NumPy 1.24.3/OpenCV 4.11.0, FFmpeg 8,
Node 24.19.0 and Edge 155 on Radeon RX 7600.

Visual approval is pending. The photographed land stays beneath the mesh by
design. Its alignment is authored for the current camera/rotation; a future
camera or geometry change must recheck it. Shader animation and V6 device
performance/iPhone validation remain separate unfinished work.
