/* ════════════════════════════════════════════════════════════════════════════
 * w_doorlock · nav.ts - moving between the cards with the keyboard and the pad (w_pausemenu's, unchanged)
 *
 * The board is a grid of cards of different sizes, so "the next item" is spatial and not a list
 * index: from the focused element we pick the nearest one whose box lies in the pressed direction.
 * It reads the boxes the browser actually laid out, so it mirrors with Arabic by itself (the left
 * arrow goes to whatever is on the left of the screen) and it survives any change to the CSS.
 * ════════════════════════════════════════════════════════════════════════════ */

export type Dir = 'up' | 'down' | 'left' | 'right';

export interface Target {
  id: string;
  rect: DOMRect;
}

/** How far two boxes may overlap along the pressed direction and still count as "beyond" each other
 *  (the torn edges and the focus lift move a card by a few pixels) */
const SLACK = 6;
/** Any target that overlaps on the cross axis beats every one that does not */
const OFF_LINE = 10000;

/** The nearest target in `dir` from `from`, or null.
 *  * A target must lie wholly beyond the focused box in that direction: the news card beside the map is
 *    not "below" it only because it is taller (the map's Down goes to the strip under it, not sideways).
 *  * Overlap on the cross axis is preferred outright: moving down from a card lands on what is under it,
 *    not on a nearer corner of its neighbour; only when nothing lies straight ahead does it go diagonally. */
export function pickNext(from: DOMRect, targets: Target[], dir: Dir): string | null {
  const fx = from.left + from.width / 2;
  const fy = from.top + from.height / 2;
  let best: string | null = null;
  let bestScore = Infinity;

  for (const t of targets) {
    const r = t.rect;
    if (r.width === 0 && r.height === 0) continue;
    let gap: number;     // distance along the pressed direction (must be forward)
    let cross: number;   // how far off the line it is (0 when the boxes overlap on the cross axis)
    const tx = r.left + r.width / 2;
    const ty = r.top + r.height / 2;

    switch (dir) {
      case 'down':
        if (r.top < from.bottom - SLACK) continue;
        gap = Math.max(0, r.top - from.bottom);
        cross = Math.max(0, r.left - from.right, from.left - r.right);
        break;
      case 'up':
        if (r.bottom > from.top + SLACK) continue;
        gap = Math.max(0, from.top - r.bottom);
        cross = Math.max(0, r.left - from.right, from.left - r.right);
        break;
      case 'right':
        if (r.left < from.right - SLACK) continue;
        gap = Math.max(0, r.left - from.right);
        cross = Math.max(0, r.top - from.bottom, from.top - r.bottom);
        break;
      default:
        if (r.right > from.left + SLACK) continue;
        gap = Math.max(0, from.left - r.right);
        cross = Math.max(0, r.top - from.bottom, from.top - r.bottom);
    }

    const centre = dir === 'up' || dir === 'down' ? Math.abs(tx - fx) : Math.abs(ty - fy);
    const score = (cross > 0 ? OFF_LINE : 0) + gap + cross * 4 + centre * 0.15;
    if (score < bestScore) {
      bestScore = score;
      best = t.id;
    }
  }
  return best;
}

/* ── The pad ─────────────────────────────────────────────────────────────────
 * CEF exposes the Gamepad API; the game does not see the pad while the page holds the focus. The
 * standard mapping: 0 A (select) · 1 B (back) · 4/5 LB/RB (the news) · 12..15 the d-pad; the left stick
 * counts as the d-pad. A held direction repeats after 380 ms, then every 140 ms. */

export type PadAction = Dir | 'select' | 'back' | 'prev' | 'next';

export function startPad(onAction: (a: PadAction) => void): () => void {
  if (typeof navigator === 'undefined' || typeof navigator.getGamepads !== 'function') return () => {};

  let raf = 0;
  let first = true;                          // what is already held when the menu opens is ignored until released
  const held = new Map<string, number>();   // key -> next time it may fire

  const frame = (now: number) => {
    raf = requestAnimationFrame(frame);
    let pads: (Gamepad | null)[] = [];
    try { pads = Array.from(navigator.getGamepads()); } catch { return; }
    const pad = pads.find((p) => p && p.connected);
    if (!pad) { held.clear(); return; }

    const btn = (i: number) => !!pad.buttons[i]?.pressed;
    const ax = pad.axes[0] ?? 0;
    const ay = pad.axes[1] ?? 0;
    const state: Record<string, boolean> = {
      up: btn(12) || ay < -0.6,
      down: btn(13) || ay > 0.6,
      left: btn(14) || ax < -0.6,
      right: btn(15) || ax > 0.6,
      select: btn(0),
      back: btn(1),
      prev: btn(4),
      next: btn(5),
    };

    if (first) {
      first = false;
      for (const key of Object.keys(state)) if (state[key]) held.set(key, Infinity);
      return;
    }

    for (const key of Object.keys(state)) {
      if (!state[key]) { held.delete(key); continue; }
      const due = held.get(key);
      const repeats = key === 'up' || key === 'down' || key === 'left' || key === 'right';
      if (due === undefined) {
        held.set(key, repeats ? now + 380 : Infinity);
        onAction(key as PadAction);
      } else if (repeats && now >= due) {
        held.set(key, now + 140);
        onAction(key as PadAction);
      }
    }
  };

  raf = requestAnimationFrame(frame);
  return () => cancelAnimationFrame(raf);
}
