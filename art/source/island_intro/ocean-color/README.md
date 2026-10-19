# Editable reference ocean

**Superseded by the user's full-screenshot correction.** Current production uses
`frontend/island/live/assets/ocean-frame.png`, an untouched video frame. The ORA
and extraction instructions below describe the rejected processed-water attempt;
they do not update the current production image.

Open **ocean-color.ora** in Krita. The canvas is **960 x 720**. The default
visible layer is **Base water - EDIT THIS**. Other layers are hidden guides.
The separate PNG files can also be loaded as aligned layers in Photoshop.

## Paint and publish

1. Save your working document as a `.kra`, `.psd`, or a separate `.ora`.
2. Show the coastline guide while painting, then hide it before export.
   Keep canvas dimensions, orientation, and coastline position unchanged.
3. Export only the base-water layer, opaque RGB/sRGB, as `base-water.png`.
4. Copy that PNG to `frontend/island/live/assets/ocean-color.png`.
5. Optional: edit `deep-water-tile.png` at **256 x 256**; its opposite edges must
   remain seamless. Copy it to `frontend/island/live/assets/ocean-deep-color.png`.
6. `coastal-blend-mask.png` is a grayscale opacity guide: white keeps the local
   coastal image, black uses the world-anchored deep tile. Only change it if
   necessary; keep its image boundary black. Its runtime copy is
   `frontend/island/live/assets/ocean-color-mask.png`.
7. Run `python tools/validate_island_production.py` to import, validate and
   rebuild the Web export. Reload the phone page after it succeeds.

The sea is one opaque plane. The mask blends two color textures within that
material; it does not make the plane transparent. Shader recoloring and all
wave animation are disabled. Runtime import is lossless with mipmaps.

## Layers

- `reference.png`: untouched lossless active picture from original native frame 199.
- `coastline-guide.png`: traced 3D island boundary, not rendered artwork.
- `base-water.png`: cleaned sea plus nearest-water color extended under the land.
  The polygonal color regions inside the island are hidden under the 3D mesh.
- `wave-appearance.png`: source-color wave candidates with transparency.
- `wave-mask.png`: editable outer-band selection; retained for later animation.
- `coastal-blend-mask.png`: feather into the deep-water tile.
- `deep-water-tile.png`: source patch mirrored into a seamless repeat.

The extracted wave selection is approximate: one frame cannot uniquely separate
wave brightness from background water. Faint diffuse water variation remains
in the base. The near-shore cyan colors and source lighting are retained.
No AI-generated art is used. The original island mesh/atlas are unchanged.

## Reproduce the initial extraction

Requires Blender 4.2.2 with NumPy, and the project's existing OpenCV installation
in `build/island-authoring-deps` (setup is documented in `dev/island_scene/README.md`).

```powershell
& 'C:/Program Files/Blender Foundation/Blender 4.2/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/build_ocean_color_texture.py
```

This command **overwrites generated layers and runtime PNGs**. Back up manual
edits first; rebuilding the game never runs this extraction automatically.
Source/output hashes are in `docs/evidence/island_intro/ocean-color/assets.json`.
The entire authoring folder is excluded from Godot import/export by its parent
`.gdignore`. Do not move the ORA or source layers into runtime assets.
