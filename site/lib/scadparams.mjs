// Extract the Customizer parameter block from an OpenSCAD design.
//
// The repo's convention (CLAUDE.md, "Design conventions") is that every
// user-tunable dimension is a top-level assignment at the top of the file,
// grouped with `/* [Section] */` markers and described by the comment line
// above it. That is exactly OpenSCAD's own Customizer syntax, so this reads
// the same thing the desktop Customizer panel would — from the .scad itself,
// never a hand-maintained copy that could drift.
//
// Deliberately conservative. A parameter is exposed only when its value is a
// literal we can round-trip back through `-D name=value` without changing its
// meaning. Anything computed, anything after geometry starts, and anything in
// a `[Hidden]` section is skipped rather than guessed at.

const SECTION = /^\s*\/\*\s*\[([^\]]+)\]\s*\*\/\s*$/;
const COMMENT = /^\s*\/\/\s?(.*)$/;
const ASSIGN = /^\s*(\$?[A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*;\s*(?:\/\/\s*(.*))?$/;

// A range annotation: [min:max] or [min:step:max]. A dropdown: [a, b, c].
const RANGE2 = /^\[\s*(-?[\d.]+)\s*:\s*(-?[\d.]+)\s*\]$/;
const RANGE3 = /^\[\s*(-?[\d.]+)\s*:\s*(-?[\d.]+)\s*:\s*(-?[\d.]+)\s*\]$/;
const OPTIONS = /^\[([^\]]*)\]$/;

// $fn/$fa/$fs drive render cost, not the product. Exposing them invites a
// visitor to set $fn=400 and wedge their own browser.
const SKIP_NAMES = new Set(["$fn", "$fa", "$fs", "$t", "$vpr", "$vpt", "$vpd"]);

function literalValue(raw) {
  const s = raw.trim();
  if (/^-?\d+$/.test(s)) return { type: "int", value: parseInt(s, 10) };
  if (/^-?(\d+\.\d*|\.\d+|\d+)(e-?\d+)?$/i.test(s)) return { type: "number", value: parseFloat(s) };
  if (s === "true" || s === "false") return { type: "bool", value: s === "true" };
  const str = s.match(/^"((?:[^"\\]|\\.)*)"$/);
  if (str) return { type: "string", value: str[1].replace(/\\(.)/g, "$1") };
  return null; // an expression — not safely round-trippable, so not exposed
}

function annotation(text) {
  if (!text) return null;
  const s = text.trim();
  let m = s.match(RANGE3);
  if (m) return { kind: "range", min: +m[1], step: +m[2], max: +m[3] };
  m = s.match(RANGE2);
  if (m) return { kind: "range", min: +m[1], max: +m[2] };
  m = s.match(OPTIONS);
  if (m && m[1].includes(",")) {
    const options = m[1]
      .split(",")
      .map((o) => o.trim().replace(/^"|"$/g, ""))
      .filter(Boolean);
    if (options.length > 1) return { kind: "options", options };
  }
  return null;
}

/**
 * @returns {{sections: {name: string, params: object[]}[], asserts: string[], stopped: string|null}}
 */
export function parseParameters(source) {
  const lines = source.split("\n");
  const sections = [];
  let current = null;
  let hidden = false;
  let pendingComment = [];
  let stopped = null;
  const asserts = [];

  const push = (param) => {
    if (!current) {
      current = { name: "Parameters", params: [] };
      sections.push(current);
    }
    current.params.push(param);
  };

  // assert() messages are the design's own safety floors — nuggs' 70 mm
  // minimum bore is a welfare constraint, not a nicety. They are collected
  // whole-file (not in the line loop below, which stops at the parameter
  // block) and span multiple lines in practice: nuggs writes the condition on
  // one line and its message on the next.
  for (const m of source.matchAll(/\bassert\s*\(/g)) {
    let depth = 0;
    let end = m.index;
    for (let i = m.index + m[0].length - 1; i < source.length; i++) {
      const c = source[i];
      if (c === "(") depth++;
      else if (c === ")") {
        depth--;
        if (depth === 0) {
          end = i;
          break;
        }
      }
    }
    const body = source.slice(m.index + m[0].length, end);
    // Split on the FIRST TOP-LEVEL comma: the condition, then the message.
    // A naive split breaks on messages built with str(...), whose arguments
    // are themselves comma-separated.
    let d = 0;
    let split = -1;
    let inStr = false;
    for (let i = 0; i < body.length; i++) {
      const c = body[i];
      if (inStr) {
        if (c === "\\") i++;
        else if (c === '"') inStr = false;
        continue;
      }
      if (c === '"') inStr = true;
      else if (c === "(" || c === "[") d++;
      else if (c === ")" || c === "]") d--;
      else if (c === "," && d === 0) {
        split = i;
        break;
      }
    }
    const condition = (split === -1 ? body : body.slice(0, split)).replace(/\s+/g, " ").trim();
    const rest = split === -1 ? "" : body.slice(split + 1);
    const msg = rest.match(/"((?:[^"\\]|\\.)*)"/);
    asserts.push({
      condition,
      message: msg ? msg[1].replace(/\\(.)/g, "$1") : null,
    });
  }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // `use <...>` / `include <...>` legitimately sit above the parameter
    // block (desiccant-capsule does exactly this), so they are skipped, not
    // treated as the end of it.
    if (/^\s*(use|include)\s*</.test(line)) {
      pendingComment = [];
      continue;
    }

    const sec = line.match(SECTION);
    if (sec) {
      const name = sec[1].trim();
      hidden = /^hidden$/i.test(name);
      current = hidden ? null : { name, params: [] };
      if (current) sections.push(current);
      pendingComment = [];
      continue;
    }

    const com = line.match(COMMENT);
    if (com) {
      pendingComment.push(com[1].trim());
      continue;
    }

    if (/^\s*$/.test(line)) {
      pendingComment = [];
      continue;
    }

    const asg = line.match(ASSIGN);
    if (asg && !hidden) {
      const [, name, rawValue, trailing] = asg;
      pendingComment = pendingComment.filter(Boolean);
      const description = pendingComment.join(" ");
      pendingComment = [];
      if (SKIP_NAMES.has(name)) continue;
      const lit = literalValue(rawValue);
      if (!lit) continue; // computed value — leave it to the .scad
      push({
        name,
        ...lit,
        description,
        annotation: annotation(trailing),
      });
      continue;
    }

    // First real statement that is not an assignment or a comment: the
    // parameter block is over. Everything below is geometry, and a variable
    // assigned there is an implementation detail, not a knob.
    if (asg) {
      pendingComment = [];
      continue;
    }
    if (/^\s*(module|function)\b/.test(line) || /[{}]/.test(line)) {
      stopped = `line ${i + 1}`;
      break;
    }
    pendingComment = [];
  }

  return {
    sections: sections.filter((s) => s.params.length > 0),
    asserts,
    stopped,
  };
}

/**
 * Every file that must exist in the WASM filesystem for this design to render.
 *
 * The WASM build has no `-I` and ignores OPENSCADPATH (it is read at startup,
 * before we can set it), so includes only resolve RELATIVE to the entry file.
 * Everything therefore lands in one flat directory next to `model.scad`, which
 * is why this returns basenames.
 */
export function includeClosure(source, resolve, seen = new Set()) {
  const files = {};
  const refs = [...source.matchAll(/^\s*(?:include|use)\s*<([^>]+)>/gm)].map((m) => m[1].trim());
  for (const ref of refs) {
    const base = ref.split("/").pop();
    if (seen.has(base)) continue;
    seen.add(base);
    const resolved = resolve(ref);
    if (!resolved) continue;
    files[base] = resolved.contents;
    Object.assign(files, includeClosure(resolved.contents, resolve, seen));
  }
  return files;
}
