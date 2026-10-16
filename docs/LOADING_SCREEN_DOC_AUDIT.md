# Loading-screen documentation audit

Audit date: **2026-10-16**. The user accepts the existing loading screen as complete. The [current loading contract](LOADING_SCREEN.md) records that result without implementing additional visuals, optimizations, APIs, or asset changes. This audit covers only boot `LOADING`; references to scenario/resource loading and later frontend transitions are outside scope.

## Inventory and document roles

| Document | Loading-related material found | Audit action |
| --- | --- | --- |
| [00_README.md](00_README.md) | General graybox/art policy and document index; no dedicated loading entry | Add a narrow completed-loading exception and links to the contract/audit; preserve the wider MVP policy |
| [01_ARCHITECTURE.md](01_ARCHITECTURE.md) | Boot state edge and loading mounted in the shared frontend | Add actual clock/presentation ownership and a contract link; preserve other frontend ownership text |
| [04_UI_RESPONSIVE.md](04_UI_RESPONSIVE.md) | Full composition and revision narrative | Replace only the boot-loading subsection with a current UI summary and contract link |
| [05_ASSETS.md](05_ASSETS.md) | Replacement contract mixed with font/image/SVG history, measurements, and old comparison commands | Keep a concise current asset contract; move current detail to the authoritative document and historical detail to its existing reports |
| [06_IMPLEMENTATION_TASKS.md](06_IMPLEMENTATION_TASKS.md) | Task 23 loading criteria mixed with supersession instructions and video-specific thresholds | Mark its loading portion complete; retain behavior/asset acceptance, link the current contract, and remove obsolete renderer/exact-match gates from live loading criteria |
| [07_IMPLEMENTATION_PLAN.md](07_IMPLEMENTATION_PLAN.md) | Task 23 step 1 and a later font/glow paragraph repeat multiple generations of instructions | Replace loading-only instructions with current maintenance guidance; preserve island-intro/attract steps and their validation |
| [TASK_STATUS.md](TASK_STATUS.md) | Current completion checkbox and chronological loading revision notes, including an older incomplete exact-match statement | Add an explicit accepted loading baseline and identify loading revision notes as history; leave other task statuses and island behavior unchanged |
| [REHABILITATION.md](REHABILITATION.md) | Dated broad-project validation history mentions production boot | Add only a loading-status clarification; do not reassess its wider experience/device acceptance |
| [Effects report](TASK23_LOADING_EFFECTS_REPORT.md) | Removed GLB/mesh renderer, old controls, and incomplete exact-match result | Update the historical notice to point at the current contract; retain the original dated body/results |
| [SVG report](TASK23_LOADING_SVG_REPORT.md) | SVG replacement evidence predating later image/font/glow revisions | Add a historical revision notice; retain its measurements/results |
| [Image report](TASK23_LOADING_IMAGES_REPORT.md) | Lossless optimization and image-fill evidence predating layered text/glows | Add a historical revision notice; retain its measurements/results |
| [UI glow report](TASK23_LOADING_UI_GLOW_REPORT.md) | Implemented layered-font/glow revision and native/Web evidence | Label it as a dated implementation report, with the live contract authoritative for maintenance; preserve its original body/results |

The architecture's later “no loading cut” language concerns the island/logo handoff and remains unchanged. Generic resource loading, gameplay, scenarios, later screens, global task-progress statements, and unrelated rehabilitation findings are not rewritten. `AGENTS.md` and the gameplay/scenario/Web-checklist documents are unchanged.

## Planned claims compared with the accepted result

Classification: **Current** means implemented and supported by source/checks; **Superseded** means a historical requirement replaced by an accepted revision; **Proposed but unimplemented** means an optional future change, not completion debt; **Unverified** means no evidence supports claiming it.

| Documented claim or earlier expectation | Source / evidence | Classification and current result | Documentation correction |
| --- | --- | --- | --- |
| Two-second loading and automatic island-intro handoff | [IslandFrontendController](../frontend/island/IslandFrontendController.gd), [GameFlow](../autoload/GameFlow.gd), rerun Task 23 | **Current**: controller advances 2.0 active seconds and requests the legal state edge; presentation does not own the clock | State the actual ownership and focus-pause behavior |
| A loading bar could imply real resource/download progress | [LoadingPresentation](../frontend/loading/LoadingPresentation.gd), controller stepping | **Current**: measured deterministic animation, independent of resource/download progress | Explicitly distinguish presentation progress from engine/browser startup |
| “Stepped fill” and eight sequential reveals | `FILL_FRAMES`, `FILL_RIGHTS`, `IMAGE_REVEAL_FRAMES`, Task 23 | **Current**: interpolation between measured samples, three plateaus, full at 1.95 seconds, 0.05-second final hold | Describe interpolation/plateaus accurately rather than a generic loading algorithm |
| Centered, uniformly fitted 960x720 canvas | Composition math in LoadingPresentation; Task 23 and prior responsive captures | **Current**: complete canvas fits the available control rectangle; unused space is black | Keep the layout invariant and distinguish cap bounds from total text/glow ink |
| 3D loading California mesh, mesh materials, MSAA, procedural fallback | Historical effects report versus [LoadingSvgBackground](../frontend/loading/LoadingSvgBackground.gd) and its [scene](../frontend/loading/LoadingSvgBackground.tscn) | **Superseded**: loading map is 2D SVG with cached silhouette effects; island remains 3D | Remove the retired renderer from live requirements; preserve it in history |
| Solid background or an exported backdrop color as the visible gradient control | [Radial shader](../frontend/loading/loading_radial_background.gdshader), scene material, `refresh_background()` | **Superseded** for solid presentation; **Current** shader uniforms determine radial colors despite the ColorRect base color | Document effective shader colors and the existing base property's limited role |
| Placeholder image/font contents still await replacement | Current [scene assignments](../frontend/loading/LoadingPresentation.tscn), `art/loading/` assets/imports | **Superseded**: supplied SVG, eight PNGs, and two corrected OTFs are the accepted replaceable assets | Replace placeholder wording only for loading |
| Padding inside revealed frames | [LoadingForeground](../frontend/loading/LoadingForeground.gd), rerun 107 image checks | **Superseded**: rounded center-cropped images extend beneath the existing border | Keep current cropping/border contracts; do not revive old padding |
| Outline-only text or Solid merely an alternate font | Scene font slots, foreground draw order, rerun 101 font/glow checks | **Superseded**: Solid is the 50%-white fill beneath Outline, with shared alignment | Define both current font roles and missing-font behavior |
| Opaque pure-white outline | Foreground draw color `(0.90, 0.92, 1.0, 0.94)` | **Proposed but unimplemented**: accepted outline remains lavender at 94%; Solid fill is `(1, 1, 1, 0.5)` | Record actual RGBA values; do not introduce a pending color change |
| Earlier two-band foreground glow or preservation of all previous glow styling | Foreground 16-pass helpers, root Inspector defaults, rerun rendered falloff checks | **Superseded**: current text/bar/frame/connector radii are 8/12/8/6, shared strength 1 | Document accepted appearance and current implementation separately |
| All loading rendering is cached | Map viewport lifecycle versus foreground `queue_redraw()` and style/pass caches | **Current**: map pixels are cached; foreground weights/styles/measurements are cached data, while drawing repeats during animation | State exactly what is cached; avoid implying a baked text texture |
| Cache finished text/glow into one texture | Previous performance discussion versus current source/scene | **Proposed but unimplemented**: no finished-text texture cache exists | Keep outside completion requirements; require a future scoped request/profiling |
| Small font files or a successful browser smoke prove low-end performance | Existing native/Web logs contain correctness evidence, not device benchmarks | **Unverified**: no measured low-end mobile-browser impact or universal FPS guarantee | Do not manufacture performance percentages or device acceptance |
| Exact video identity is still required before loading can be complete | Older mesh/glint statements versus later revisions and the user's acceptance | **Superseded** as a completion gate: current appearance is accepted without an exact pixel-match claim | Mark loading complete; retain historical comparison limitations in their dated context |
| Historical comparison tools are general clean-checkout validation | [LoadingEffectsCompare](../dev/LoadingEffectsCompare.gd), [LoadingImagesCompare](../dev/LoadingImagesCompare.gd) hard-coded roots and masks | **Current** limitation: these require revision-specific ignored reference/baseline artifacts and cannot compare arbitrary later UI revisions | Separate regular bundled-asset tests from historical comparisons and document prerequisites |

## Validation and evidence

The audit started from commit `362eb16` with a clean tracked worktree. Pre-edit byte snapshots and SHA-256 hashes cover all **586** tracked files under `build/rehabilitation/loading-doc-audit/`. No runtime implementation or asset change is part of this audit.

### Rerun during this documentation audit

| Check | Result and current log |
| --- | --- |
| `godot --headless --path . tests/cli/Task23Test.tscn` | `TASK23_PASS`; `build/rehabilitation/loading-doc-audit/task23.log` |
| `godot --path . --rendering-method gl_compatibility --script res://tests/cli/LoadingUiGlowTest.gd` | `LOADING_UI_GLOW_PASS checks=101`; 1,002 fill samples, maximum RGB error 0.001961; `ui-glow.log` in the same audit directory |
| `godot --path . --rendering-method gl_compatibility --script res://tests/cli/LoadingImagesTest.gd` | `LOADING_IMAGES_PASS checks=107`; `images.log` in the same audit directory |
| Temporary controlled-background rendering check in the ignored audit directory | `LOADING_BACKGROUND_DOC_PASS`; changing the backdrop base color leaves the active radial-shader output byte-identical; `background-doc.log` in the same audit directory |

These runs load the relevant project scripts/resources without parser or missing-resource errors. They use bundled assets rather than `.ref/` or old baselines. No unrelated suite, fresh Web export, native boot capture, or device performance benchmark is claimed for this documentation-only change.

### Reused prior implementation evidence

The existing `build/rehabilitation/loading-ui-glow/` artifacts were inspected, not regenerated as new audit results:

| Existing evidence | What it establishes for that implementation revision |
| --- | --- |
| `preservation.json` and `before/` / `after/` captures | 35 captures; 17,826,699 compared pixels outside authorized regions unchanged; seven background captures identical; 575 protected source files unchanged during that earlier UI revision |
| `boot.log` | `LOADING_NATIVE_BOOT_PASS active_seconds=2.0000`, with the full-bar hold |
| `pack.log` / `fill-glow-export.log` | 385 packed resources without reference/development leakage; both fonts, 0.5 fill alpha, and configured radii verified in the prior export |
| `browser.log` / `browser/console.json` | `WEB_RUNTIME_NO_ERRORS`, with an empty runtime-error array; correctness smoke evidence, not low-end performance measurements |

The original SVG/image/effects reports retain their own earlier evidence, byte counts, thresholds, and limitations. Ignored evidence directories and `.ref/` are local artifacts, not guaranteed clean-checkout dependencies. Browser logs written by Windows PowerShell may be UTF-16; the console JSON and Godot log files are separate artifacts.

### Documentation and scope checks

Validated **70 local Markdown links/anchors**, referenced command-source paths, documented geometry/defaults, asset import settings, and existing public method names against the checkout. The final scope check confirms 12 bounded existing-document updates and two new documents. All **570 tracked non-documentation files** and four untouched Markdown files are byte-identical; the four historical report bodies are unchanged after their notices. Reversing the 28 bounded edits reproduces every original shared document byte-for-byte, and explicit checks preserve the island requirements, other numbered-task sections, and all task-status checkboxes. `git diff --check` passes. Results are recorded in `build/rehabilitation/loading-doc-audit/scope-link-check.json`; no runtime file, asset, or unrelated documentation passage was changed.

## Outcome and future maintenance

The loading screen is complete. The current contract is the maintenance entry point; live summaries link to it rather than duplicating successive renderer histories. Dated evidence remains available without creating new implementation obligations. Stable behavior, accepted appearance, alignment, responsive fitting, replaceability, and export boundaries must survive future requested changes; present rendering techniques can evolve with appropriate regression evidence.

The wider project's rehabilitation/device status is not reassessed here. Pure-white outlining, finished-text caching, and low-end performance claims remain outside the accepted loading baseline. No later implementation task is started, and no documentation discrepancy is resolved by silently changing production behavior.
