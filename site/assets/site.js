// Theme toggle. The page defaults to the OS preference via CSS
// (prefers-color-scheme); this only records an explicit override on
// documentElement, which the [data-theme] rules in site.css outrank.
//
// The inline bootstrap in the page <head> applies the stored choice before
// first paint — this file only wires the button, so a slow load never
// flashes the wrong theme.
(function () {
  var KEY = "print-bench-theme";
  var root = document.documentElement;

  function current() {
    var stored = null;
    try {
      stored = localStorage.getItem(KEY);
    } catch (e) {
      /* private mode / storage disabled — fall through to the OS preference */
    }
    if (stored === "light" || stored === "dark") return stored;
    return window.matchMedia("(prefers-color-scheme: dark)").matches
      ? "dark"
      : "light";
  }

  function apply(theme) {
    root.setAttribute("data-theme", theme);
    var btn = document.querySelector(".theme-toggle");
    if (btn) {
      btn.textContent = theme === "dark" ? "☀" : "☾";
      btn.setAttribute(
        "aria-label",
        theme === "dark" ? "Switch to light theme" : "Switch to dark theme"
      );
    }
  }

  document.addEventListener("DOMContentLoaded", function () {
    apply(current());
    var btn = document.querySelector(".theme-toggle");
    if (!btn) return;
    btn.addEventListener("click", function () {
      var next = current() === "dark" ? "light" : "dark";
      try {
        localStorage.setItem(KEY, next);
      } catch (e) {
        /* not persisting is survivable; the toggle still works this visit */
      }
      apply(next);
    });
  });
})();
