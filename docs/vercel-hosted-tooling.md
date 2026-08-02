# Hosting the shared tooling on Vercel — evaluation

Question asked (2026-08-02): *we have Vercel — can't we host some of our
shared tools there, particularly the CI ones? Keep a container always
running the PrusaSlicer CLI or other tooling as Vercel functions.*

Evaluated against Vercel's actual compute primitives (docs checked live on
2026-08-02) and against measured timings from this repo's CI and toolchain.
**Verdict: yes to hosting, no to hosting CI on it — and the always-running
container isn't a product Vercel sells.** The two things genuinely worth
hosting are a design site with a browser-side parametric configurator, and
`printcheck` as an HTTP API. Neither is CI.

## Three claims, separated

**1. "A container always running the PrusaSlicer CLI."** Nothing on Vercel
stays up between requests. Functions are request-scoped and freeze when the
response is sent. Sandboxes are session-scoped microVMs with a plan-capped
timeout; `persistent: true` means *snapshot the filesystem on stop*, not
*keep running*. If you want a warm PrusaSlicer daemon, that's Fly/Render/a
VPS, not Vercel.

**2. "Host the CI ones."** Measured below: the whole CI run is 115 s wall
clock and the gate's real work is 53 s. Moving it to Vercel would add money
(Actions minutes are free on this public repo; Sandbox bills active CPU),
lose the GitHub-native check runs, artifacts, job summary and sticky
comments `ci.yml` is built on, and remove only ~85 s of cumulative install
overhead that a prebuilt container image removes for free.

**3. "Or anything else."** This is where the yes lives. See
[What is worth hosting](#what-is-actually-worth-hosting-ranked).

## The three Vercel primitives against this toolchain

| Primitive | What it can hold | Our tools |
|---|---|---|
| **Functions** (Node/Python, request-scoped, 500 MB uncompressed Python bundle, no apt, no X server) | Pure-language code and vendored wheels | ✅ `printcheck`, `stylelift` — pure Python, 171 MB of wheels, no display. ❌ `openscad`/`prusa-slicer` — apt packages pulling Qt5/CGAL/wxWidgets and needing `xvfb`; you cannot `apt-get install` into a function |
| **Sandbox** (microVM, arbitrary binaries, custom images via VCR, session-scoped + snapshot-on-stop, billed on active CPU) | Anything that runs on Linux | ✅ everything, including `prusa-slicer` and `openscad-nightly` — but each session is a cold VM, and it bills |
| **Static + Edge** (build-time output, CDN, no per-request compute) | Prebuilt pages, assets, WASM | ✅ the design gallery, product pages, committed previews, downloadable STLs — and `openscad-wasm`, which moves rendering to the *visitor's* browser at zero server cost |

## Measured baseline

CI, full-gate run on `main` ([run 30772851268](https://github.com/shaiss/Openscad/actions/runs/30772851268),
all four designs, `--slice`). **Whole run: 115 s wall.**

| Job | Total | Toolchain install | Actual work |
|---|---|---|---|
| Render designs, gate STLs, test-slice | 101 s | 19 s OBS + 10 s pip + 6 s apt | **53 s** |
| Style packs and conformance | 68 s | 37 s OBS + 10 s pip | 3 s |
| OpenSCAD check (nightly, manifold) | 44 s | 29 s OBS | 4 s |
| OpenSCAD check (stable 2021.01) | 25 s | 5 s apt (cached) | 13 s |
| stylelift unit tests | 44 s | 12 s pip | 22 s |
| printcheck unit tests | 18 s | 11 s pip | 2 s |
| Lint scripts and workflows | 18 s | — | 18 s |

Toolchain weight and per-run cost, measured in this container (OpenSCAD
2021.01/CGAL — CI's `openscad-nightly --backend=manifold` renders all four
designs in 53 s including printcheck and slicing, so treat the render
column as an upper bound):

| Tool | Weight | Time |
|---|---|---|
| `prusa-slicer` (apt) | 129 MB installed, 29 MB binary | 13 s per part to G-code |
| `openscad` (apt) | 9.6 MB binary + Qt5/CGAL/OpenCSG/GLEW, needs `xvfb` | 1 s / 27 s / 38 s / 143 s for calibration-cube / desiccant-capsule / nuggs / sushi-battleship |
| `printcheck` + `stylelift` deps | 171 MB of wheels (scipy 113, numpy 42, trimesh 4.7, shapely 6.7, manifold3d 3.9, rtree 0.5) | **1 s** per STL |
| `photoshot` | `bpy` ≈ Blender as a module, hundreds of MB | minutes of Cycles path-tracing |

## Why the CI gate stays on GitHub Actions

1. **Cost inversion.** This repo is public, so GitHub-hosted runners are
   free and unmetered. Vercel Sandbox bills active CPU and memory. Moving
   the gate converts a free 53 s of compute per PR into a billed one, for
   no capability we lack.
2. **It would lose the integration the workflow is built on.** `ci.yml`
   depends on per-job check runs that branch protection matches by name,
   `$GITHUB_STEP_SUMMARY`, `upload-artifact` for the STLs and f3d renders,
   and two sticky PR comments with stale-run guards. A Vercel-hosted gate
   would have to re-implement all of it against the GitHub API, from a
   place where a failure isn't visible as a failed check.
3. **The overhead it would fix is fixable for free.** The one real waste is
   installing `openscad-nightly` from the OBS repo in three separate jobs —
   19 + 29 + 37 = 85 s of cumulative machine time every run. The fix is a
   prebuilt toolchain image published to GHCR and referenced with
   `container:`, which keeps everything GitHub-native and costs nothing.
   That is the change worth making, and it has nothing to do with Vercel.
4. **A sandbox is not warmer than a runner.** Each session starts as a cold
   VM. Unless we keep a named sandbox alive — billing while idle — we pay a
   cold start *and* an image pull in place of the 85 s we removed.
5. **Reproducibility moves the wrong way.** `tools/photoshot` PNGs are
   committed and diffed, and are only byte-reproducible on the same
   machine. Rendering them on variable cloud hardware makes that guarantee
   weaker, not stronger.

## What is actually worth hosting (ranked)

The Vercel project `openscad` already exists under `shaiss-projects` — it
has three domains attached, `live: false`, and `openscad-tau.vercel.app`
currently returns 404. There is a slot waiting for exactly this.

**Tier 1 — the design site (static, zero compute).** Everything a product
page needs is already committed: `designs/*/README.md`, `previews/*.png`,
the product shots, the GIFs, and the gallery `scripts/gallery.sh` generates.
A static build over `designs/` gives every design a real page with a
Download STL button, built from files CI already gates. This is what the
Vercel account is for, and it costs nothing per visit.

**Tier 1 — the browser configurator (static, zero compute).** The actual
prize. Every design here is parametric with Customizer sections — `nuggs`
alone exposes `bore_d`, `wall`, `port_tol`, `n_lug`, `twist_deg`.
[`openscad/openscad-wasm`](https://github.com/openscad/openscad-wasm) is a
full headless WASM port with STL export and `--enable=manifold`. Ship it as
a static asset and the visitor's own browser renders their STL: sliders in,
mesh out, no server, no bill, no cold start. A hosted render endpoint would
be strictly worse — same output, but metered.

**Tier 2 — `printcheck` as an HTTP API (Python function).** The one tool
that fits Functions outright: pure Python, 171 MB of wheels against a
500 MB limit, no display, ~1 s per STL. `POST` an STL, get the printability
report. Worth building as a public service and as the backend for a "check
my STL" box on the site. Note it earns nothing for CI — CI just
`pip install -e tools/printcheck` in 11 s and calls it locally.

**Tier 3 — a Sandbox-backed slice/render service.** The only way to host
`prusa-slicer` or full `openscad-nightly` on Vercel: a custom image in the
Vercel Container Registry with the toolchain baked in, driven from a
function via the Sandbox SDK. Justified only if we want a user-facing
"slice this and tell me the print time" feature — 13 s of billed CPU per
slice. Never justified as a CI backend.

**Not worth hosting:** `photoshot` (needs `bpy`, minutes of path-tracing,
and a byte-reproducibility guarantee that cloud hardware weakens), and the
gate itself (reasons above).

## Recommendation

1. Build the static design site on the existing `openscad` project — it is
   pure upside over a 404, and the content is already committed and gated.
2. Add the `openscad-wasm` configurator to it. That is the "hosted shared
   tool" with real leverage, and it runs on the free tier forever because
   the compute is the visitor's.
3. Ship `printcheck` as a Python function if we want it usable outside this
   repo. Keep the CI gate calling the local CLI either way.
4. If CI install time is the actual itch, fix it with a GHCR toolchain
   image and `container:` — not by moving CI off GitHub.
