// The parametric configurator: build controls from the design's own
// Customizer parameters, render in the browser, hand back an STL.
//
// The OpenSCAD runtime is ~14 MB, so nothing here loads until the visitor
// actually asks for it. A product page that is only being read stays light.

(function () {
  const root = document.querySelector("[data-configurator]");
  if (!root) return;

  const manifestUrl = root.getAttribute("data-configurator");
  const runtimeUrl = root.getAttribute("data-runtime");
  const workerUrl = root.getAttribute("data-worker");
  const fontUrl = root.getAttribute("data-font") || null;

  const openBtn = root.querySelector("[data-open]");
  const panel = root.querySelector("[data-panel]");
  const controls = root.querySelector("[data-controls]");
  const status = root.querySelector("[data-status]");
  const diagnostics = root.querySelector("[data-diagnostics]");
  const renderBtn = root.querySelector("[data-render]");
  const resetBtn = root.querySelector("[data-reset]");
  const downloadBtn = root.querySelector("[data-download]");

  let manifest = null;
  let worker = null;
  let seq = 0;
  let busy = false;
  let lastUrl = null;

  function setStatus(text, kind) {
    status.textContent = text || "";
    status.className = "cfg-status" + (kind ? ` cfg-${kind}` : "");
  }

  function showDiagnostics(list) {
    diagnostics.innerHTML = "";
    if (!list || !list.length) {
      diagnostics.hidden = true;
      return;
    }
    diagnostics.hidden = false;
    for (const line of list) {
      const el = document.createElement("div");
      // An OpenSCAD assert() failure is the design refusing an unsafe value —
      // nuggs' 70 mm minimum bore, for instance. Show the design's own words.
      el.className = /^ERROR/.test(line) ? "cfg-diag cfg-diag-error" : "cfg-diag";
      el.textContent = line;
      diagnostics.appendChild(el);
    }
  }

  function controlFor(param) {
    const id = `cfg-${param.name}`;
    const wrap = document.createElement("div");
    wrap.className = "cfg-field";

    const label = document.createElement("label");
    label.setAttribute("for", id);
    label.textContent = param.name;
    wrap.appendChild(label);

    let input;
    const ann = param.annotation;

    if (param.type === "bool") {
      input = document.createElement("input");
      input.type = "checkbox";
      input.checked = param.value;
      wrap.classList.add("cfg-field-bool");
    } else if (ann && ann.kind === "options") {
      input = document.createElement("select");
      for (const opt of ann.options) {
        const o = document.createElement("option");
        o.value = opt;
        o.textContent = opt;
        if (opt === String(param.value)) o.selected = true;
        input.appendChild(o);
      }
    } else if (ann && ann.kind === "range") {
      input = document.createElement("input");
      input.type = "number";
      input.min = ann.min;
      input.max = ann.max;
      if (ann.step) input.step = ann.step;
      input.value = param.value;
    } else if (param.type === "string") {
      input = document.createElement("input");
      input.type = "text";
      input.value = param.value;
    } else {
      input = document.createElement("input");
      input.type = "number";
      input.step = param.type === "int" ? 1 : "any";
      input.value = param.value;
    }

    input.id = id;
    input.setAttribute("data-param", param.name);
    input.setAttribute("data-type", param.type);
    wrap.appendChild(input);

    if (param.description) {
      const help = document.createElement("p");
      help.className = "cfg-help";
      help.textContent = param.description;
      wrap.appendChild(help);
    }
    return wrap;
  }

  function buildControls() {
    controls.innerHTML = "";
    for (const section of manifest.sections) {
      const fs = document.createElement("fieldset");
      fs.className = "cfg-section";
      const legend = document.createElement("legend");
      legend.textContent = section.name;
      fs.appendChild(legend);
      for (const p of section.params) fs.appendChild(controlFor(p));
      controls.appendChild(fs);
    }

    if (manifest.asserts && manifest.asserts.length) {
      const box = document.createElement("div");
      box.className = "cfg-limits";
      const h = document.createElement("h4");
      h.textContent = "This design enforces its own limits";
      box.appendChild(h);
      const ul = document.createElement("ul");
      for (const a of manifest.asserts) {
        const li = document.createElement("li");
        li.textContent = a.message ? a.message : a.condition;
        ul.appendChild(li);
      }
      box.appendChild(ul);
      controls.appendChild(box);
    }
  }

  function collect() {
    const params = {};
    for (const el of controls.querySelectorAll("[data-param]")) {
      const name = el.getAttribute("data-param");
      const type = el.getAttribute("data-type");
      if (type === "bool") params[name] = el.checked;
      else if (type === "string") params[name] = el.value;
      else {
        const n = Number(el.value);
        if (Number.isFinite(n)) params[name] = n;
      }
    }
    return params;
  }

  function ensureWorker() {
    if (worker) return worker;
    worker = new Worker(workerUrl, { type: "module" });
    worker.onmessage = (e) => {
      const msg = e.data;
      if (msg.type === "status") {
        setStatus(msg.text);
        return;
      }
      busy = false;
      renderBtn.disabled = false;

      if (msg.type === "error") {
        setStatus("Render failed — see below.", "error");
        showDiagnostics(
          msg.diagnostics && msg.diagnostics.length
            ? msg.diagnostics
            : ["ERROR: OpenSCAD exited with code " + msg.code]
        );
        return;
      }

      const seconds = (msg.elapsedMs / 1000).toFixed(1);
      const kb = Math.round(msg.stl.byteLength / 1024);
      setStatus(`Done in ${seconds}s — ${kb} KB STL ready.`, "ok");
      showDiagnostics(msg.diagnostics);

      if (!msg.usedManifold) {
        showDiagnostics([
          ...(msg.diagnostics || []),
          "WARNING: this render did not use the Manifold backend — it will have been far slower than it should be.",
        ]);
      }

      if (lastUrl) URL.revokeObjectURL(lastUrl);
      lastUrl = URL.createObjectURL(new Blob([msg.stl], { type: "model/stl" }));
      downloadBtn.href = lastUrl;
      downloadBtn.download = `${manifest.name}.stl`;
      downloadBtn.hidden = false;
    };
    worker.onerror = () => {
      busy = false;
      renderBtn.disabled = false;
      setStatus("The renderer failed to start.", "error");
    };
    return worker;
  }

  async function open() {
    openBtn.disabled = true;
    setStatus("loading parameters…");
    try {
      const res = await fetch(manifestUrl);
      if (!res.ok) throw new Error(`manifest ${res.status}`);
      manifest = await res.json();
    } catch (err) {
      setStatus("Could not load this design's parameters.", "error");
      openBtn.disabled = false;
      return;
    }
    buildControls();
    panel.hidden = false;
    openBtn.hidden = true;
    setStatus("");
  }

  function render() {
    if (busy) return;
    busy = true;
    renderBtn.disabled = true;
    downloadBtn.hidden = true;
    showDiagnostics(null);
    setStatus("starting…");
    ensureWorker().postMessage({
      id: ++seq,
      runtimeUrl,
      fontUrl,
      source: manifest.source,
      files: manifest.files,
      params: collect(),
    });
  }

  openBtn.addEventListener("click", open);
  renderBtn.addEventListener("click", render);
  resetBtn.addEventListener("click", () => {
    buildControls();
    showDiagnostics(null);
    setStatus("");
    downloadBtn.hidden = true;
  });
})();
