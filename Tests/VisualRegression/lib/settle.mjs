// Waits for observable page state instead of sleeping for a fixed time.
//
// The checks run in the page through Playwright, so they also work with JavaScript
// disabled in the page (where animation frame callbacks never run).

const POLL_MILLISECONDS = 25;
const DEFAULT_TIMEOUT_MILLISECONDS = 15000;

// Describes what is still changing in the document of the frame it is evaluated in:
// running transitions and time-based animations of finite length, fonts, images (other
// than lazily loaded ones, which may never load) and the size of the document.  Scroll-driven animations follow the scroll position and
// are never finished, so they do not count.
function pageStateInFrame() {
  const busy = document.getAnimations().filter((animation) => {
    if (animation.playState !== 'running' || animation.timeline !== document.timeline) return false;
    return Number.isFinite(animation.effect?.getComputedTiming().endTime);
  });
  const root = document.documentElement;
  return {
    ready: document.readyState === 'complete'
      && (!document.fonts || document.fonts.status === 'loaded')
      && [...document.images].every((image) => image.complete || image.loading === 'lazy')
      && busy.length === 0,
    size: `${root.scrollWidth}x${root.scrollHeight}`,
    busy: busy.map((animation) => animation.transitionProperty || animation.animationName || 'animation'),
  };
}

// Returns the state of every frame of a tab, or null for frames that went away.
async function pageState(tab) {
  return Promise.all(tab.frames().map((frame) => frame.evaluate(pageStateInFrame).catch(() => null)));
}

/**
 * Waits until a tab and its frames have settled: the document is loaded, fonts and
 * images are ready, no transition or time-based animation is running, and the size of
 * every document is the same on two consecutive polls.
 *
 * @param {import('playwright-core').Page} tab the tab to wait for
 * @param {{timeout?: number, minimum?: number}} options the longest wait in
 *   milliseconds before an error is thrown, and the shortest wait (for renderers that
 *   build the page with JavaScript after it has loaded)
 * @returns {Promise<void>} resolves once the tab has settled
 */
export async function waitForSettledPage(tab, { timeout = DEFAULT_TIMEOUT_MILLISECONDS, minimum = 0 } = {}) {
  const start = Date.now();
  if (minimum > 0) await tab.waitForTimeout(minimum);
  let previous = null;
  for (;;) {
    const states = await pageState(tab);
    const signature = JSON.stringify(states.map((state) => state?.size ?? null));
    const ready = states.every((state) => !state || state.ready);
    if (ready && signature === previous) return;
    previous = ready ? signature : null;
    if (Date.now() - start > timeout) {
      const busy = [...new Set(states.flatMap((state) => state?.busy ?? []))];
      throw new Error(`${tab.url()} did not settle within ${timeout}ms${busy.length ? ` (running: ${busy.join(', ')})` : ''}`);
    }
    await tab.waitForTimeout(POLL_MILLISECONDS);
  }
}

// Whether the scroll-driven animations of the document reflect the scroll position:
// every timeline of the root scroller reports the progress of the current position.
function scrollTimelinesCaughtUpInPage(position) {
  const root = document.scrollingElement || document.documentElement;
  if (Math.round(scrollY) !== position) return false;
  const maximum = root.scrollHeight - root.clientHeight;
  const expected = maximum > 0 ? (scrollY / maximum) * 100 : 100;
  return document.getAnimations().every((animation) => {
    const timeline = animation.timeline;
    if (typeof ScrollTimeline === 'undefined' || !(timeline instanceof ScrollTimeline) || timeline instanceof ViewTimeline) return true;
    if (timeline.source !== root || timeline.axis === 'inline' || timeline.axis === 'x') return true;
    const current = timeline.currentTime;
    return current !== null && Math.abs(current.value - expected) < 0.01;
  });
}

/**
 * Scrolls a tab to a vertical position and waits until the page reflects it: the
 * position is reached, the scroll-driven animations of the root scroller report it,
 * and every transition this started has finished.
 *
 * @param {import('playwright-core').Page} tab the tab to scroll
 * @param {number} position the vertical scroll position in CSS pixels
 * @param {{timeout?: number}} options the longest wait in milliseconds before an error
 *   is thrown
 * @returns {Promise<void>} resolves once the page shows the new position
 */
export async function scrollAndSettle(tab, position, { timeout = DEFAULT_TIMEOUT_MILLISECONDS } = {}) {
  const start = Date.now();
  await tab.evaluate((y) => window.scrollTo({ top: y, left: 0, behavior: 'instant' }), position);
  while (!(await tab.evaluate(scrollTimelinesCaughtUpInPage, position))) {
    if (Date.now() - start > timeout) {
      throw new Error(`${tab.url()} did not reach scroll position ${position} within ${timeout}ms`);
    }
    await tab.waitForTimeout(POLL_MILLISECONDS);
  }
  await waitForSettledPage(tab, { timeout: Math.max(timeout - (Date.now() - start), POLL_MILLISECONDS) });
}
