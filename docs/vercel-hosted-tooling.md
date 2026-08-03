# Hosting the shared tooling on Vercel — evaluation

Question asked (2026-08-02): *we have Vercel — can't we host some of our
shared tools there, particularly the CI ones? Keep a container always
running the PrusaSlicer CLI or other tooling as Vercel functions.*

Evaluated against Vercel's actual compute primitives (docs checked live on
2026-08-02) and against measured timings from this repo's CI and toolchain.
**Verdict: yes to hosting, no to hosting CI on it — and no Vercel primitive
guarantees an always-running daemon, though a container image gets closer
than this document originally allowed.** The two things genuinely worth
hosting are a design site with a browser-side parametric configurator, and
`printcheck` as an HTTP API. Neither is CI.

## Three claims, separated

**1. "A container always running the PrusaSlicer CLI."** No Vercel compute
primitive is *guaranteed* to stay up between requests, but the picture is
more nuanced than "functions freeze":

- **Source-based Functions** are request-scoped, with no way to install
  system packages — you get the managed language runtime and your
  dependencies, so `apt-get install prusa-slicer` is simply not available.
- **Container-image Functions/Services** *do* take arbitrary system
  dependencies: Vercel builds an OCI image (`"runtime": "container"` in
  `vercel.json`) and runs it as an HTTP service. This is a real route for
  PrusaSlicer, and the original version of this document was wrong to say
  otherwise.
- **Fluid compute** reuses warm instances across requests, so a hot path
  can skip cold starts — but reuse is an optimisation, not a residency
  guarantee, and it does not give you a daemon you can count on being alive.
- **Sandboxes** are session-scoped microVMs with a plan-capped timeout;
  `persistent: true` means *snapshot the filesystem on stop*, not *keep
  running*.

So the honest answer to the original question is: PrusaSlicer **can** be
hosted on Vercel via a container image or a Sandbox — what you cannot buy
is a guaranteed always-on daemon, and neither route is a good fit for CI
(below).

**2. "Host the CI ones."** Measured below: the whole CI run is 115 s wall
clock and the gate's real work is 53 s. Moving it to Vercel trades free
compute for metered compute — standard GitHub-hosted runners are free for
public repositories like this one and don't draw down any minutes quota,
while Vercel's compute products meter usage against plan allowances (Hobby
gets a monthly allotment and then stops; Pro bills past its credit). It
would also mean rebuilding the GitHub-native reporting `ci.yml` depends on,
to remove only ~85 s of cumulative install overhead that a prebuilt
container image removes for free.

**3. "Or anything else."** This is where the yes lives. See
[What is worth hosting](#what-is-actually-worth-hosting-ranked).

## The Vercel primitives against this toolchain

| Primitive | What it can hold | Our tools |
|---|---|---|
| **Source-based Functions** (Node/Python, request-scoped, 500 MB uncompressed Python bundle on the standard path — Large Functions under Fluid compute raise that considerably — managed runtime, no apt, no X server) | Pure-language code and vendored wheels | ✅ `printcheck`, `stylelift` — pure Python, 171 MB of wheels, no display. ❌ `openscad`/`prusa-slicer` — apt packages pulling Qt5/CGAL/wxWidgets and needing `xvfb` |
| **Container-image Functions/Services** (`"runtime": "container"`, an OCI image you build, run as an HTTP service) | Arbitrary system dependencies | ✅ `prusa-slicer`, `openscad-nightly` — you control the base image, so the apt packages are yours to install |
| **Sandbox** (microVM, arbitrary binaries, custom images via VCR, session-scoped + snapshot-on-stop, metered) | Anything that runs on Linux | ✅ everything, including `prusa-slicer` and `openscad-nightly` — but each session starts cold, and it meters |
| **Static + Edge** (build-time output, CDN, no per-request function compute) | Prebuilt pages, assets, WASM | ✅ the design gallery, product pages, committed previews — and `openscad-wasm`, which moves rendering to the *visitor's* browser |

Numbers that gate a design decision (bundle caps, request/response body
caps, per-plan allowances) move; check
[the limits pages](https://vercel.com/docs/limits) before committing to one
rather than trusting the figures quoted here.

## Measured baseline

CI, full-gate run on `main` ([run 30772851268](https://github.com/shaiss/print-bench/actions/runs/30772851268),
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

1. **Cost inversion.** This repo is public, and standard GitHub-hosted
   runners are free for public repositories — that usage isn't charged and
   doesn't draw down an included-minutes quota. Vercel's compute meters
   against plan allowances instead (Sandbox bills active CPU, provisioned
   memory, creations and transfer; a Hobby allotment stops when spent, Pro
   bills past its credit). Moving the gate converts 53 s of free compute
   per PR into metered compute, for no capability we lack.
2. **It would mean rebuilding the integration the workflow is built on.**
   `ci.yml` depends on per-job check runs that branch protection matches by
   name, `$GITHUB_STEP_SUMMARY`, `upload-artifact` for the STLs and f3d
   renders, and two sticky PR comments with stale-run guards. A Vercel-hosted
   gate *could* report failures as real failed checks — a GitHub App with
   `checks:write` can create a check run and set `conclusion: failure` — but
   it would have to recreate the check names, summaries, artifacts, sticky
   comments and stale-run guards through the API, and then keep them working.
3. **The overhead it would fix is fixable for free.** The one real waste is
   installing `openscad-nightly` from the OBS repo in three separate jobs —
   19 + 29 + 37 = 85 s of cumulative machine time every run. The fix is a
   prebuilt toolchain image published to GHCR and referenced with
   `container:`, which keeps everything GitHub-native and costs nothing.
   That is the change worth making, and it has nothing to do with Vercel.
4. **A sandbox is not reliably warmer than a runner.** A fresh session pays
   a cold start and an image pull in place of the 85 s we removed. A
   *persisted* named sandbox resumes from its snapshot instead, which does
   avoid re-pulling the image — but it trades that for snapshot storage
   billed by the GB-month, and keeping one alive rather than stopped bills
   provisioned memory for idle time. Neither shape is free of the overhead
   a prebuilt GHCR image removes outright.
5. **Reproducibility moves the wrong way.** `tools/photoshot` PNGs are
   committed and diffed, and are only byte-reproducible on the same
   machine. Rendering them on variable cloud hardware makes that guarantee
   weaker, not stronger.

## What is actually worth hosting (ranked)

The Vercel project `openscad` already exists under `shaiss-projects`, and
it is **already git-connected to this repo** — opening the PR that added
this document produced a preview deployment automatically. What's missing
is not wiring but content: `live: false`, and `openscad-tau.vercel.app`
returns 404 because the repo root has no site to build. There is a slot
waiting for exactly this, already plumbed.

**Tier 1 — the design site (static).** Everything a product page needs is
already committed: `designs/*/README.md`, `previews/*.png`, the product
shots, the GIFs, and the gallery `scripts/gallery.sh` generates. A static
build over `designs/` gives every design a real page, built from files CI
already gates.

Two caveats worth stating plainly. **It cannot ship STLs**: `build/` is
gitignored and STLs are regenerated from source, never committed, so there
is nothing static to put behind a Download button — that has to come from
the configurator below. And **static is not free of usage**: there is no
per-request function compute, but every visit still spends Edge Requests
and Fast Data Transfer against the plan's monthly allowance, and on Hobby
exhausting it pauses the project rather than billing overage. Our preview
assets were 3.8 MB across 22 files when this was measured (2026-08-02),
which is small — but the GIFs and product shots are the part that would
grow.

**Tier 1 — the browser configurator (static assets, visitor's compute).**
The actual prize. Every design here is parametric with Customizer sections
— `nuggs` alone exposes `bore_d`, `wall`, `port_tol`, `n_lug`, `twist_deg`.
[`openscad/openscad-wasm`](https://github.com/openscad/openscad-wasm) is a
headless WASM port with STL export. Ship it as a static asset and the
visitor's own browser renders their STL: sliders in, mesh out, no server
compute, no cold start. A hosted render endpoint would be strictly worse —
same output, but metered.

Three things to settle before building it, all since confirmed by building
it (see `site/README.md`):

- Its **releases are stale** — the newest tag is 2022.03.20, which predates
  the Manifold backend entirely — so the artifact has to be chosen and
  pinned deliberately rather than taken from `latest`.
- The flag is **`--backend=manifold`**. That repo's README still shows
  `--enable=manifold`, which is an obsolete spelling that does *not* error:
  OpenSCAD prints "Ignoring request to enable unknown feature" and silently
  runs the old CGAL backend instead — measured **145× slower** (79,696 ms
  vs 550 ms on one part). Anything built on this must assert that the
  geometry line says `(manifold)`.
- OpenSCAD is **GPL-2.0**: serving that WASM build to visitors is
  distribution, so it ships with its licence and notices, and with
  corresponding source or a written offer for the exact build served.

**Tier 2 — `printcheck` as an HTTP API (Python function).** The one tool
that fits source-based Functions outright: pure Python, 171 MB of wheels
against a 500 MB limit, no display, ~1 s per STL. The obvious design —
`POST` an STL, get the report — **does not survive contact with our own
files**: Vercel caps non-streaming function request and response bodies
(4.5 MB at the time of writing), and the STLs here run 2.0 MB
(desiccant-capsule) to 7.4 MB (sushi-battleship). The two biggest would be
rejected before `printcheck` ever ran. The fix is a client upload straight
to blob storage, with the function receiving only the storage key —
*not* streaming, which relieves the response side and does nothing for an
oversized request body. Worth building as a public service, but earning
nothing for CI — CI just
`pip install -e tools/printcheck` in 11 s and calls it locally.

**Anything public here needs abuse controls designed in, not added after.**
Both this endpoint and the Tier 3 service below take a file from a stranger
and spend metered storage and compute on it, which makes an unbounded one a
standing invitation. Settle these before writing the handler, not once a bill
arrives: whether uploads are authenticated at all (Vercel's own guidance is
that the upload-token route must authenticate the caller unless anonymous
upload is a deliberate choice); a maximum accepted file size, enforced when
the token is issued rather than after the bytes land; how long blobs are kept
and what deletes them; a request rate limit and a concurrency cap per caller;
and an execution timeout, since `printcheck` is ~1 s on our meshes but a
hostile mesh is not our meshes.

**Tier 3 — a hosted slice/render service.** Hosting `prusa-slicer` or full
`openscad-nightly` means a container image with the toolchain baked in —
either as a container-image Function/Service, or driven from a function via
the Sandbox SDK. Justified only if we want a user-facing "slice this and
tell me the print time" feature, at ~13 s of metered CPU per slice, and
subject to the same body-size problem as the `printcheck` endpoint above.
Never justified as a CI backend.

**One plan caveat across all of these.** Vercel's Hobby plan is for
personal, non-commercial use — its fair-use terms count things like ads,
donations, or being paid to build or host the site as commercial. A design
gallery published for its own sake sits inside that; the moment the site or
the `printcheck` endpoint is commercial in that sense, the baseline is Pro,
not Hobby, and the free-allowance reasoning above has to be redone at Pro's
rates.

**Not worth hosting:** `photoshot` (needs `bpy`, minutes of path-tracing,
and a byte-reproducibility guarantee that cloud hardware weakens), and the
gate itself (reasons above).

## Recommendation

1. Build the static design site on the existing `openscad` project — it is
   pure upside over a 404, and the content is already committed and gated.
2. Add the `openscad-wasm` configurator to it. That is the "hosted shared
   tool" with real leverage: the rendering compute is the visitor's, so the
   only usage it costs us is serving the asset. Pin the build deliberately
   and satisfy GPL-2.0 when shipping it.
3. Ship `printcheck` as a Python function if we want it usable outside this
   repo — with an upload path that isn't a plain `POST`, since our own STLs
   exceed the body cap. Keep the CI gate calling the local CLI either way.
4. If CI install time is the actual itch, fix it with a GHCR toolchain
   image and `container:` — not by moving CI off GitHub.
