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
//      instead, measured 145x slower. So the render also asserts that the
//      geometry line says "(manifold)" and reports it if not.
//   2. One module instance per render, always. A second callMain() on the
//      same instance throws — and the previous run's output file is STILL
//      readable, so a naive retry hands the visitor the PREVIOUS model.
//   3. There is no -I/include path and OPENSCADPATH is read before we can
//      set it, so every included file must be written into the SAME
//      directory as the entry file.

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
  const { id, runtimeUrl, fontUrl, source, files = {}, params = {} } = event.data;
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
    });
    const m = instance.getInstance ? instance.getInstance() : instance;

    const mkdir = (p) => {
      try {
        m.FS.mkdir(p);
      } catch {
        /* already exists */
      }
    };

    // Without a font on the virtual filesystem, text() emits "Can't get font"
    // and silently contributes NO geometry — calibration-cube's embossed size
    // marker just vanishes while the render still reports success.
    if (fontBytes) {
      mkdir("/fonts");
      m.FS.writeFile("/fonts/design.ttf", fontBytes);
    }

    for (const [name, contents] of Object.entries(files)) {
      m.FS.writeFile(`/${name}`, contents);
    }
    m.FS.writeFile("/model.scad", source);

    const args = [
      "/model.scad",
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
      code = -1;
      log.push(`EXCEPTION: ${err && err.message ? err.message : String(err)}`);
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

    // Costs nothing and catches a silent 145x regression: if the flag ever
    // stops taking effect this says "(Nef polyhedron)" instead.
    const usedManifold = log.some((l) => l.includes("3D object (manifold)"));

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
