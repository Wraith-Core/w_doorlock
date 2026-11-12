/* ════════════════════════════════════════════════════════════════════════════
 * The line icons - drawn by hand for the board, in the pause menu's manner (w_pausemenu/web/src/
 * ui/icons.tsx): one 24-unit grid, one stroke, round ends; the lines wobble a little on purpose so
 * they read as pen on paper rather than as a font's glyphs.
 * ════════════════════════════════════════════════════════════════════════════ */

const line = {
  viewBox: '0 0 24 24',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 1.5,
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
  'aria-hidden': true,
};

/** A plank door in its frame, the knob on the right */
export function IconDoor({ className = 'dl-ico' }: { className?: string }) {
  return (
    <svg {...line} className={className}>
      <path d="M5.2 21.2l-.15-17.1c2.4-.9 11.4-.95 13.85-.05l.1 17.2" />
      <path d="M3.4 21.25c5.8-.15 11.4-.12 17.2.02" />
      <path d="M7.4 20.9l-.05-14.6c1.9-.5 7.4-.52 9.25-.02l.05 14.65" />
      <path d="M10.15 6.15l.08 14.7M13.2 6.1l.05 14.75" strokeOpacity={0.55} />
      <path d="M15.05 13.35c.02.42-.28.75-.68.76-.4.02-.72-.3-.73-.7-.02-.4.28-.73.68-.75.4-.02.72.3.73.69Z" />
    </svg>
  );
}

/** A padlock, shut */
export function IconLock({ className = 'dl-row-state' }: { className?: string }) {
  return (
    <svg {...line} className={className}>
      <path d="M6.1 10.4c3.9-.2 8-.18 11.85.02l.15 9.9c-3.95.25-7.95.25-11.95.02l-.05-9.94Z" />
      <path d="M8.35 10.3l-.05-2.6c.02-2.15 1.65-3.85 3.72-3.85 2.05.02 3.7 1.75 3.68 3.9l-.02 2.55" />
      <path d="M12.02 14.2l.03 2.55" />
    </svg>
  );
}

/** A padlock, its shackle swung open */
export function IconUnlock({ className = 'dl-row-state' }: { className?: string }) {
  return (
    <svg {...line} className={className}>
      <path d="M6.1 10.4c3.9-.2 8-.18 11.85.02l.15 9.9c-3.95.25-7.95.25-11.95.02l-.05-9.94Z" />
      <path d="M8.35 10.3l-.05-2.6c.02-2.15 1.65-3.85 3.72-3.85 1.7.02 3.05 1.15 3.5 2.75" />
      <path d="M12.02 14.2l.03 2.55" />
    </svg>
  );
}

/** A lock pick and its tension wrench */
export function IconPick({ className = 'dl-ico' }: { className?: string }) {
  return (
    <svg {...line} className={className}>
      <path d="M3.6 19.9l10.6-10.55c.55-.55 1.05-.5 1.45-.1l.6.62 2.15-2.1c.4-.42.95-.45 1.4-.02" />
      <path d="M3.3 15.6l8.4-.1c.65 0 1 .35 1 .95l-.05 2.4" />
      <path d="M17.2 3.6c.55.5.6 1.15.15 1.65" strokeOpacity={0.6} />
    </svg>
  );
}

/* ── The small glyphs (pager, steppers, rows) ─────────────────────────────── */

const glyph = { ...line, className: 'dl-glyph' };

/** Points to the inline end (mirrored by CSS in Arabic) */
export function GlyphNext() {
  return (
    <svg {...glyph}>
      <path d="M9.1 4.9l7.2 7.05-7.15 7.1" strokeWidth={2} />
    </svg>
  );
}

export function GlyphPrev() {
  return (
    <svg {...glyph}>
      <path d="M14.9 4.9l-7.2 7.05 7.15 7.1" strokeWidth={2} />
    </svg>
  );
}

export function GlyphCross() {
  return (
    <svg {...glyph}>
      <path d="M5.6 5.4l12.9 13.1M18.4 5.5L5.5 18.45" strokeWidth={2} />
    </svg>
  );
}

export function GlyphPlus() {
  return (
    <svg {...glyph}>
      <path d="M12.05 4.4l-.1 15.2M4.4 11.95l15.2.1" strokeWidth={2.2} />
    </svg>
  );
}

export function GlyphSearch() {
  return (
    <svg {...glyph}>
      <path d="M16.4 10.2c0 3.5-2.8 6.3-6.25 6.3S3.9 13.7 3.9 10.2 6.7 3.9 10.15 3.9s6.25 2.8 6.25 6.3Z" />
      <path d="M14.85 14.95l5.3 5.25" strokeWidth={2} />
    </svg>
  );
}

/** A small horn: hear the sound */
export function GlyphHear() {
  return (
    <svg {...glyph}>
      <path d="M4.4 9.4l3.1-.05 5.2-4.1.25 13.6-5.3-4.05-3.2.03-.05-5.43Z" />
      <path d="M16.1 8.6c1.25 1.05 1.3 5.6.05 6.75M18.6 6.4c2.45 2.3 2.55 8.85.1 11.2" />
    </svg>
  );
}

/** the place line's pin (the builders' notebook) */
export function GlyphPin() {
  return (
    <svg className="dl-glyph dl-pin" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden="true">
      <path d="M12 21c-3.6-4.3-5.6-7.4-5.6-10.1a5.6 5.6 0 0 1 11.2 0c0 2.7-2 5.8-5.6 10.1z" />
      <circle cx="12" cy="10.6" r="1.9" />
    </svg>
  );
}
