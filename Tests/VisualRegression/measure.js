/*
 * In-page measurement function of the visual regression harness.
 *
 * Evaluated in the page as `(SOURCE)(roles, side, properties)`, where `roles` maps a
 * semantic role name to a definition with one selector per side (`static`, `main`,
 * `vue`; `null` when the role does not exist in that DOM), `side` selects which
 * selector to use and `properties` lists the computed style properties to record.
 *
 * A selector may pierce a same-origin frame with ` >>> `: the part before it selects
 * the frame element in the page, the part after it is evaluated inside the frame's
 * document.  Boxes of elements inside a frame are reported in page coordinates.
 *
 * A role definition may set `pick` to `"in-viewport"` (the first match that is visible
 * inside the viewport) or leave it unset (the first visible match anywhere, or the
 * first match if none is visible).  Roles with `geometry: true` also record their
 * horizontal position and width.
 *
 * The result is plain JSON with deterministic key order.
 */
(roles, side, properties) => {
  const round = (n) => Math.round(n * 100) / 100;

  const resolve = (selector) => {
    const parts = selector.split(' >>> ');
    let scope = document;
    let offset = { x: scrollX, y: scrollY };
    for (let i = 0; i < parts.length - 1; i++) {
      const frame = scope.querySelector(parts[i]);
      if (!frame || !frame.contentDocument) return { nodes: [], offset, view: window };
      const r = frame.getBoundingClientRect();
      offset = { x: offset.x + r.x + frame.clientLeft, y: offset.y + r.y + frame.clientTop };
      scope = frame.contentDocument;
    }
    const view = scope.defaultView || window;
    return { nodes: Array.from(scope.querySelectorAll(parts[parts.length - 1])), offset, view };
  };

  const visible = (el, view, inViewport) => {
    const r = el.getBoundingClientRect();
    const cs = view.getComputedStyle(el);
    if (!(r.width > 0 && r.height > 0 && cs.visibility !== 'hidden' && cs.display !== 'none')) return false;
    if (!inViewport) return true;
    return r.bottom > 0 && r.top < view.innerHeight && r.right > 0 && r.left < view.innerWidth;
  };

  const result = {
    viewport: { width: innerWidth, height: innerHeight },
    scheme: matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light',
    document: {
      htmlFontSize: getComputedStyle(document.documentElement).fontSize,
      scrollWidth: document.documentElement.scrollWidth,
    },
    roles: {},
  };

  for (const name of Object.keys(roles).sort()) {
    const definition = roles[name];
    const selector = definition[side];
    if (!selector) continue;
    const entry = { found: 0 };
    let resolved;
    try { resolved = resolve(selector); } catch (error) { entry.error = String(error); result.roles[name] = entry; continue; }
    const { nodes, offset, view } = resolved;
    entry.found = nodes.length;
    const inViewport = definition.pick === 'in-viewport';
    const element = nodes.find((el) => visible(el, view, inViewport)) || (inViewport ? null : nodes[0]);
    if (element) {
      const cs = view.getComputedStyle(element);
      entry.visible = visible(element, view, false);
      entry.style = {};
      for (const property of properties) entry.style[property] = cs[property];
      if (definition.geometry) {
        const r = element.getBoundingClientRect();
        entry.box = { x: round(r.x + offset.x), width: round(r.width) };
      }
    }
    result.roles[name] = entry;
  }
  return result;
}
