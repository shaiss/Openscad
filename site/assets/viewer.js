// In-browser 3D viewer (issue #100).
//
// Renders the design's own source at its DEFAULT parameters with the
// OpenSCAD-WASM worker the site already ships — the same geometry the gate
// exports — then draws the resulting STL with three.js. Rotate, zoom, pan.
//
// Everything is lazy. three.js and its addons are imported dynamically inside
// the click handler, not at the top level, so shipping this module on every
// product page fetches nothing heavy until the visitor presses "View in 3D";
// the ~14 MB OpenSCAD runtime is fetched only then too (by the worker). A page
// with no JavaScript is complete without this file — the <noscript> fallback in
// the panel points at the previews already rendered above.

const root = document.querySelector("[data-viewer]");
if (root) init(root);

function init(root) {
  const modelUrl = root.getAttribute("data-model");
  const runtimeUrl = root.getAttribute("data-runtime");
  const workerUrl = root.getAttribute("data-worker");
  const fontUrl = root.getAttribute("data-font") || null;

  const openBtn = root.querySelector("[data-view-open]");
  const stage = root.querySelector("[data-stage]");
  const canvasHost = root.querySelector("[data-canvas]");
  const statusEl = root.querySelector("[data-view-status]");

  let started = false;

  function setStatus(text, isError) {
    statusEl.textContent = text || "";
    statusEl.classList.toggle("viewer-error", !!isError);
  }

  // three.js is heavy, so it is not a top-level import: bringing it in here
  // means the page-load module graph is just this file, and three (plus the
  // vendored addons) is fetched only on the first "View in 3D". The bare
  // `three` specifier resolves through the page's import map.
  let deps = null;
  async function loadDeps() {
    if (!deps) {
      const [THREE, stl, orbit] = await Promise.all([
        import("three"),
        import("/assets/three/STLLoader.js"),
        import("/assets/three/OrbitControls.js"),
      ]);
      deps = { THREE, STLLoader: stl.STLLoader, OrbitControls: orbit.OrbitControls };
    }
    return deps;
  }

  openBtn.addEventListener("click", async () => {
    if (started) return;
    started = true;
    openBtn.disabled = true;
    stage.hidden = false;
    setStatus("loading model…");
    try {
      const res = await fetch(modelUrl);
      if (!res.ok) throw new Error(`model ${res.status}`);
      const model = await res.json();
      // Load three in parallel with the render — the two are independent.
      const [three, stl] = await Promise.all([loadDeps(), renderStl(model)]);
      setStatus("drawing…");
      draw(three, stl);
      setStatus("");
    } catch (err) {
      setStatus(`Could not display this model: ${err && err.message ? err.message : err}`, true);
      // Let the visitor try again rather than dead-ending on a transient failure.
      openBtn.disabled = false;
      started = false;
    }
  });

  // Drive the shared OpenSCAD worker to render the entry .scad at its defaults.
  // params is empty on purpose: no override means OpenSCAD uses the file's own
  // default values, which is exactly what render.sh/gate.sh export.
  function renderStl(model) {
    return new Promise((resolve, reject) => {
      let worker;
      try {
        worker = new Worker(workerUrl, { type: "module" });
      } catch (e) {
        reject(e);
        return;
      }
      worker.onmessage = (e) => {
        const msg = e.data;
        if (msg.type === "status") {
          setStatus(msg.text);
          return;
        }
        worker.terminate();
        if (msg.type === "error") {
          const first = msg.diagnostics && msg.diagnostics.length ? msg.diagnostics[0] : null;
          reject(new Error(first || `OpenSCAD exited with code ${msg.code}`));
          return;
        }
        resolve(msg.stl);
      };
      worker.onerror = () => {
        worker.terminate();
        reject(new Error("the renderer failed to start"));
      };
      worker.postMessage({
        id: 1,
        runtimeUrl,
        fontUrl,
        entry: model.entry,
        source: model.source,
        files: model.files,
        params: {},
      });
    });
  }

  function draw({ THREE, STLLoader, OrbitControls }, arrayBuffer) {
    const geometry = new STLLoader().parse(arrayBuffer);
    geometry.computeVertexNormals();
    geometry.computeBoundingBox();

    const size = new THREE.Vector3();
    const center = new THREE.Vector3();
    geometry.boundingBox.getSize(size);
    geometry.boundingBox.getCenter(center);
    geometry.translate(-center.x, -center.y, -center.z);
    const radius = Math.max(size.x, size.y, size.z, 1);

    const width = () => canvasHost.clientWidth || 640;
    const height = () => canvasHost.clientHeight || 440;

    const scene = new THREE.Scene();
    const css = getComputedStyle(root);
    const bg = css.getPropertyValue("--viewer-bg").trim() || "#1b1f23";
    scene.background = new THREE.Color(bg);

    const camera = new THREE.PerspectiveCamera(45, width() / height(), radius / 100, radius * 100);
    camera.up.set(0, 0, 1); // OpenSCAD models are Z-up
    camera.position.set(radius * 1.7, -radius * 2.1, radius * 1.5);

    const accent = css.getPropertyValue("--accent").trim() || "#ff9166";
    const mesh = new THREE.Mesh(
      geometry,
      new THREE.MeshStandardMaterial({ color: new THREE.Color(accent), metalness: 0.05, roughness: 0.65 })
    );
    scene.add(mesh);

    const key = new THREE.DirectionalLight(0xffffff, 2.4);
    key.position.set(1, -1, 1.6);
    scene.add(key);
    const fill = new THREE.DirectionalLight(0xffffff, 0.9);
    fill.position.set(-1.2, 0.6, 0.4);
    scene.add(fill);
    scene.add(new THREE.AmbientLight(0xffffff, 0.55));

    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setSize(width(), height());
    canvasHost.appendChild(renderer.domElement);

    const controls = new OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.target.set(0, 0, 0);
    camera.lookAt(0, 0, 0);

    // Render on demand rather than a perpetual rAF loop: a frame is drawn when
    // the camera changes, and the loop keeps itself alive only while damping is
    // still settling. An IntersectionObserver pauses it entirely while the
    // viewer is scrolled out of view, so an opened viewer costs no GPU when it
    // is off screen.
    let queued = false;
    let visible = true;
    const request = () => {
      if (!queued && visible) {
        queued = true;
        requestAnimationFrame(frame);
      }
    };
    const frame = () => {
      queued = false;
      const moving = controls.update();
      renderer.render(scene, camera);
      if (moving) request();
    };
    controls.addEventListener("change", request);
    new IntersectionObserver(([entry]) => {
      visible = entry.isIntersecting;
      if (visible) request();
    }).observe(canvasHost);

    window.addEventListener("resize", () => {
      camera.aspect = width() / height();
      camera.updateProjectionMatrix();
      renderer.setSize(width(), height());
      request();
    });

    request();
  }
}
