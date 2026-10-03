/* ════════════════════════════════════════════════════════════════════════════
 * The editor's parts - every one of them a stop for the cursor (the board's navigation):
 *
 *   Field      a text box: the cursor rests on it, Enter (or a click) types into it
 *   Stepper    one of a few (◀ value ▶): Left / Right turn it where the cursor rests
 *   Switch     the pause menu's on / off row
 *   Remove     the ✕ at the end of a line
 *   Add        "add a line"
 * ════════════════════════════════════════════════════════════════════════════ */

import { useEffect } from 'react';
import { cls, useI18n } from '../i18n';
import { cue } from '../nui';
import { GlyphCross, GlyphHear, GlyphNext, GlyphPlus, GlyphPrev } from '../ui/icons';

export interface Nav {
  reg: (id: string) => (el: HTMLElement | null) => void;
  hover: (id: string) => () => void;
  here: (id: string) => boolean;
  regStep: (id: string, fn: ((delta: number) => void) | null) => void;
  focusTo: (id: string) => void;
}

interface FieldProps {
  id: string;
  nav: Nav;
  label?: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  numeric?: boolean;
  wide?: boolean;
  error?: string;
  maxLength?: number;
}

export function Field({ id, nav, label, value, onChange, placeholder, numeric, wide, error, maxLength }: FieldProps) {
  return (
    <label className={cls('dl-field', wide && 'is-wide')} onMouseEnter={nav.hover(id)}>
      {label && <span className="dl-label">{label}</span>}
      <input
        ref={nav.reg(id) as (el: HTMLInputElement | null) => void}
        className={cls('dl-input', numeric && 'is-num', nav.here(id) && 'is-here', error && 'is-invalid')}
        value={value}
        placeholder={placeholder}
        maxLength={maxLength ?? 100}
        inputMode={numeric ? 'decimal' : undefined}
        spellCheck={false}
        autoComplete="off"
        onFocus={() => nav.focusTo(id)}
        onChange={(e) => onChange(e.target.value)}
      />
      {error && <span className="dl-error">{error}</span>}
    </label>
  );
}

interface StepperProps<T extends string> {
  id: string;
  nav: Nav;
  label?: string;
  options: { value: T; label: string }[];
  value: T;
  onChange: (value: T) => void;
  hear?: () => void;
  wide?: boolean;
}

export function Stepper<T extends string>({ id, nav, label, options, value, onChange, hear, wide }: StepperProps<T>) {
  const index = Math.max(0, options.findIndex((o) => o.value === value));
  const step = (delta: number) => {
    if (options.length < 2) return;
    const next = options[(index + delta + options.length) % options.length];
    cue(delta > 0 ? 'navDown' : 'navUp');
    onChange(next.value);
  };

  useEffect(() => {
    nav.regStep(id, step);
    return () => nav.regStep(id, null);
  });

  // The row mirrors with the language: in Arabic the "previous" arrow stands on the right and
  // points right (door.css flips the glyph), the "next" one on the left.
  return (
    <div className={cls('dl-field', wide && 'is-wide')} onMouseEnter={nav.hover(id)}>
      {label && <span className="dl-label">{label}</span>}
      <div ref={nav.reg(id)} className={cls('dl-stepper', nav.here(id) && 'is-here')} data-kind="stepper"
        onClick={() => step(1)}>
        <button type="button" className="dl-stepper-arrow" tabIndex={-1}
          onClick={(e) => { e.stopPropagation(); step(-1); }} aria-label="previous">
          <GlyphPrev />
        </button>
        <span className="dl-stepper-value">{options[index]?.label ?? ''}</span>
        <button type="button" className="dl-stepper-arrow" tabIndex={-1}
          onClick={(e) => { e.stopPropagation(); step(1); }} aria-label="next">
          <GlyphNext />
        </button>
        {hear && (
          <button type="button" className="dl-play" tabIndex={-1}
            onClick={(e) => { e.stopPropagation(); hear(); }} aria-label="hear">
            <GlyphHear />
          </button>
        )}
      </div>
    </div>
  );
}

interface SwitchProps {
  id: string;
  nav: Nav;
  label: string;
  on: boolean;
  onToggle: () => void;
  locked?: boolean;
}

export function Switch({ id, nav, label, on, onToggle, locked }: SwitchProps) {
  const { t } = useI18n();
  return (
    <button
      type="button"
      ref={nav.reg(id)}
      className={cls('dl-switch-row', nav.here(id) && 'is-here', locked && 'is-locked')}
      onMouseEnter={nav.hover(id)}
      onClick={() => {
        if (locked) { cue('locked'); return; }
        cue(on ? 'toggleOff' : 'toggleOn');
        onToggle();
      }}
    >
      <span>{label}</span>
      <span className="dl-switch" data-on={on}>{on ? t('board.on') : t('board.off')}</span>
    </button>
  );
}

export function Remove({ id, nav, onClick }: { id: string; nav: Nav; onClick: () => void }) {
  const { t } = useI18n();
  return (
    <button type="button" ref={nav.reg(id)} className={cls('dl-x', nav.here(id) && 'is-here')}
      onMouseEnter={nav.hover(id)} aria-label={t('board.remove')} title={t('board.remove')}
      onClick={() => { cue('back'); onClick(); }}>
      <GlyphCross />
    </button>
  );
}

export function Add({ id, nav, label, onClick, disabled }: { id: string; nav: Nav; label: string; onClick: () => void; disabled?: boolean }) {
  return (
    <button type="button" ref={nav.reg(id)} className={cls('dl-add', nav.here(id) && 'is-here')} disabled={disabled}
      onMouseEnter={nav.hover(id)}
      onClick={() => {
        if (disabled) { cue('locked'); return; }
        cue('select');
        onClick();
      }}>
      <GlyphPlus />
      <span>{label}</span>
    </button>
  );
}
