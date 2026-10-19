# Production island presentation (23.V5)

Current ocean correction: `assets/ocean-frame.png` is the untouched full video
frame, including land/beach/waves, aligned beneath the 3D mesh. Its placement is
controlled by `ocean.tres` map size/center. There is no coastline cutout or wave
animation. See `docs/evidence/island_intro/ocean-frame/README.md` for review and
rebuild commands; the earlier processed ocean/ORA is superseded.

Run the normal Godot project for native playback. For Web, run
`python tools/validate_island_production.py`, then
`node tools/serve_production_web.mjs` and open http://127.0.0.1:8066/index.html.
The normal game now plays loading, video, live island, then the existing logo flow.

`IslandProductionSequence` owns the shared 4:3 rectangle, readiness, presentation
clock, camera/water/blur sampling, and video lifetime. `GameFlow` owns states.
The accepted loading controller retains its two-second presentation. The video
adapter preloads invisibly; a poster covers any remaining preparation time.
The shared root touch surface includes black borders. Later layouts resume under
the blue cover, whose color comes from the logo's actual handoff material.

The assets are byte-identical copies of approved V2/V3 assets in
`dev/island_scene/assets`. The profiles and blur settings come from approved V4.
Runtime profile classes have distinct names so development previews can coexist.
Editable sources and generation commands remain in `art/source/island_intro/`,
`dev/island_scene/README.md`, and the island handoff document. Do not regenerate
approved art merely to rebuild the game.

`media/intro.ogv` is only for native development; Web excludes it. Regenerate
native media with `python tools/build_island_video_preview.py`, then copy the
generated preview media from `build/island-video-preview/project/dev/island_video/media/` after
checking its manifest. Web uses the unchanged H.264 companion
`index.island-intro.mp4`; packaging verifies its authoritative SHA-256.

Validation: `python tools/validate_island_production.py` and
`node tools/smoke_web.mjs`. Preserve successful evidence with
`python tools/finalize_island_production_evidence.py`.
Actual phone performance and visual review 3 remain milestone V6.
