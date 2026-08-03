// Renders a design to STL with OpenSCAD compiled to WebAssembly.
//
// Runs in a Web Worker because a render is seconds of solid CPU: on the main
// thread it would freeze the page, including the progress text telling the
// visitor to wait.
//
// Three things here are load-bearing and were established by testing the
// actual binary, not by reading its docs:
//
//   1. The flag is `--backend=manifold`. `--enable=manifold` — which the
//      upstream openscad-wasm README still shows — is an obsolete spelling
//      that does NOT error: OpenSCAD prints "Ignoring request to enable
//      unknown feature 'manifold'" and silently runs the old CGAL backend
//      instead, measured 145x slower. So the render also watches for that
//      fallback and reports it rather than trusting the flag took.
//   2. One module instance per render, always. A second callMain() on the
//      same instance throws — and the previous run's output file is STILL
//      readable, so a naive retry hands the visitor the PREVIOUS model.
//   3. OPENSCADPATH works, but only if it is set in `preRun` (before the
//      runtime starts) AND the directories exist before callMain — OpenSCAD's
//      parser only adds search paths that exist at that moment. So the repo
//      layout is mirrored under /repo and the same `lib:root` search path the
//      shell scripts export is set there.

// Where the repo layout is recreated inside the virtual filesystem.
const ROOT = "/repo";

let createOpenSCAD = null;

async function loadRuntime(runtimeUrl) {
  if (!createOpenSCAD) {
    const mod = await import(runtimeUrl);
    createOpenSCAD = mod.createOpenSCAD || mod.default;
    if (typeof createOpenSCAD !== "function") {
      throw new Error("openscad runtime did not export createOpenSCAD");
    }
  }
  return createOpenSCAD;
}

// OpenSCAD's -D takes OpenSCAD literal syntax: strings quoted, numbers and
// booleans bare. Getting this wrong on a string turns it into an undefined
// variable, which OpenSCAD warns about and then treats as undef.
function formatValue(v) {
  if (typeof v === "string") return `"${v.replace(/(["\\])/g, "\\$1")}"`;
  if (typeof v === "boolean") return v ? "true" : "false";
  if (Array.isArray(v)) return `[${v.map(formatValue).join(",")}]`;
  return String(v);
}

self.onmessage = async (event) => {
  const { id, runtimeUrl, fontUrl, entry, source, files = {}, params = {} } = event.data;
  const log = [];
  const started = Date.now();

  const post = (msg) => self.postMessage({ id, ...msg });

  try {
    post({ type: "status", text: "loading OpenSCAD…" });
    const create = await loadRuntime(runtimeUrl);

    let fontBytes = null;
    if (fontUrl) {
      try {
        const res = await fetch(fontUrl);
        if (res.ok) fontBytes = new Uint8Array(await res.arrayBuffer());
      } catch {
        /* text() will warn and drop glyphs; the render still succeeds */
      }
    }

    post({ type: "status", text: "rendering…" });

    const instance = await create({
      noInitialRun: true,
      print: (t) => log.push(String(t)),
      printErr: (t) => log.push(String(t)),
      // Must be set here: the runtime reads the environment at startup, so
      // assigning ENV afterwards is too late to affect the include search.
      preRun: [(mod) => { mod.ENV.OPENSCADPATH = `${ROOT}/lib:${ROOT}`; }],
    });
    const m = instance.getInstance ? instance.getInstance() : instance;

    // FS.mkdir is one level at a time and throws on a missing parent, so a
    // nested path like styles/<name>/ needs this rather than a bare mkdir.
    const mkdirp = (p) => {
      let cur = "";
      for (const seg of p.split("/").filter(Boolean)) {
        cur += `/${seg}`;
        try {
          m.FS.mkdir(cur);
        } catch {
          /* already exists */
        }
      }
    };

    // Without a font on the virtual filesystem, text() emits "Can't get font"
    // and silently contributes NO geometry — calibration-cube's embossed size
    // marker just vanishes while the render still reports success.
    if (fontBytes) {
      mkdirp("/fonts");
      m.FS.writeFile("/fonts/design.ttf", fontBytes);
      // Silences "Fontconfig error: Cannot load default config file"; fonts
      // are found relative to the working directory, hence the chdir below.
      m.FS.writeFile(
        "/fonts/fonts.conf",
        '<?xml version="1.0" encoding="UTF-8"?>\n' +
          '<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">\n<fontconfig>\n</fontconfig>'
      );
    }
    try {
      m.FS.chdir("/");
    } catch {
      /* already there */
    }

    // Mirror the repo layout so OPENSCADPATH resolves exactly as it does on
    // a developer's machine. Directories must exist BEFORE callMain: the
    // parser only registers search paths that are present at that point.
    mkdirp(`${ROOT}/lib`);
    const entryPath = `${ROOT}/${entry || "model.scad"}`;
    for (const [name, contents] of Object.entries(files)) {
      const full = `${ROOT}/${name}`;
      mkdirp(full.slice(0, full.lastIndexOf("/")));
      m.FS.writeFile(full, contents);
    }
    mkdirp(entryPath.slice(0, entryPath.lastIndexOf("/")));
    m.FS.writeFile(entryPath, source);

    const args = [
      entryPath,
      "-o",
      "/out.stl",
      "--backend=manifold",
      "--export-format=binstl",
      ...Object.entries(params).map(([k, v]) => `-D${k}=${formatValue(v)}`),
    ];

    let code;
    try {
      code = m.callMain(args);
    } catch (err) {
      // Emscripten can throw a bare pointer; formatException turns it into
      // something a human can act on.
      let e = err;
      if (typeof e === "number" && m.formatException) e = m.formatException(e);
      code = -1;
      log.push(`EXCEPTION: ${e && e.message ? e.message : String(e)}`);
    }

    const diagnostics = log.filter((l) => /^(ERROR|WARNING|TRACE)/.test(l));
    const elapsedMs = Date.now() - started;

    if (code !== 0) {
      post({ type: "error", code, diagnostics, log, elapsedMs });
      return;
    }

    let stl = null;
    try {
      stl = m.FS.readFile("/out.stl");
    } catch {
      post({
        type: "error",
        code,
        diagnostics: [...diagnostics, "ERROR: OpenSCAD reported success but wrote no STL"],
        log,
        elapsedMs,
      });
      return;
    }

    // Costs nothing and catches a silent 145x regression. Detects the
    // FALLBACK rather than requiring the success line: OpenSCAD does not
    // always print a geometry line, so demanding "(manifold)" would cry wolf,
    // while "(Nef polyhedron)" or a refused feature is unambiguous.
    const usedManifold = !log.some((l) =>
      /Ignoring request to enable unknown feature|\(Nef polyhedron\)|Unknown rendering backend/.test(l)
    );

    const buffer = stl.buffer.slice(stl.byteOffset, stl.byteOffset + stl.byteLength);
    self.postMessage({ id, type: "done", stl: buffer, diagnostics, usedManifold, elapsedMs }, [
      buffer,
    ]);
  } catch (err) {
    post({
      type: "error",
      code: -1,
      diagnostics: [`ERROR: ${err && err.message ? err.message : String(err)}`],
      log,
      elapsedMs: Date.now() - started,
    });
  }
};
