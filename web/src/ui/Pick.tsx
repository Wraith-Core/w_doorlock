/* ════════════════════════════════════════════════════════════════════════════
 * The lock pick - a skill check on a torn card: one round per difficulty the door sets, ox_lib's
 * presets (easy / medium / hard, or a door's own size and speed).
 *
 * The needle (the red mark) sweeps the dial once; E (or Space, Enter, a click, the pad's A) while it
 * crosses the paper mark wins the round. A press off the mark, or a full sweep with no press, loses.
 * Escape / Backspace / the pad's B gives up. The page only reports: the server decides what the
 * door does and whether the pick breaks.
 * ════════════════════════════════════════════════════════════════════════════ */

import { useEffect, useMemo, useRef, useState } from 'react';
import { presetOf } from '../door';
import { cls, useI18n } from '../i18n';
import { startPad } from '../nav';
import { cue, post } from '../nui';
import type { Difficulty } from '../types';
import { IconPick } from './icons';

const R = 42;
const BASE_SWEEP = 2300;   // ms for one full turn at speed 1

type Phase = 'spin' | 'hit' | 'miss' | 'won';

function point(deg: number, r = R) {
  const a = (deg * Math.PI) / 180;
  return { x: 50 + r * Math.sin(a), y: 50 - r * Math.cos(a) };
}

function arc(from: number, size: number) {
  const a = point(from);
  const b = point(from + size);
  return `M ${a.x.toFixed(3)} ${a.y.toFixed(3)} A ${R} ${R} 0 ${size > 180 ? 1 : 0} 1 ${b.x.toFixed(3)} ${b.y.toFixed(3)}`;
}

export default function Pick({ rounds }: { rounds: Difficulty[] }) {
  const { t, rtl, lang } = useI18n();
  const list = useMemo(() => (rounds.length ? rounds : ['medium' as Difficulty]).map(presetOf), [rounds]);

  const [round, setRound] = useState(0);
  const [phase, setPhase] = useState<Phase>('spin');
  const [zone, setZone] = useState(() => ({ from: 120 + Math.random() * 150, size: list[0].areaSize }));
  const needle = useRef<SVGLineElement>(null);

  const angle = useRef(0);
  const started = useRef(0);
  const phaseRef = useRef<Phase>('spin');
  phaseRef.current = phase;
  const roundRef = useRef(0);
  roundRef.current = round;
  const zoneRef = useRef(zone);
  zoneRef.current = zone;
  const finished = useRef(false);

  const report = (result: 'success' | 'fail' | 'cancel') => {
    if (finished.current) return;
    finished.current = true;
    void post('dl:pick', { result });
  };

  const startRound = (i: number) => {
    const preset = list[i];
    // the mark never sits at the very start of the sweep: there is always a moment to see it coming
    const from = 100 + Math.random() * Math.max(10, 240 - preset.areaSize);
    setZone({ from, size: preset.areaSize });
    setRound(i);
    angle.current = 0;
    started.current = performance.now();
    setPhase('spin');
  };

  const lose = () => {
    if (phaseRef.current !== 'spin') return;
    setPhase('miss');
    cue('locked');
    window.setTimeout(() => report('fail'), 650);
  };

  const press = () => {
    if (phaseRef.current !== 'spin') return;
    if (performance.now() - started.current < 180) return;   // the press that opened the pick
    const { from, size } = zoneRef.current;
    const a = angle.current;
    if (a >= from && a <= from + size) {
      setPhase('hit');
      cue('select');
      const next = roundRef.current + 1;
      if (next >= list.length) {
        window.setTimeout(() => { setPhase('won'); window.setTimeout(() => report('success'), 450); }, 250);
      } else {
        window.setTimeout(() => startRound(next), 420);
      }
    } else {
      lose();
    }
  };

  /* The sweep: written straight to the needle's transform, no render per frame */
  useEffect(() => {
    let raf = 0;
    started.current = performance.now();
    const frame = (now: number) => {
      raf = requestAnimationFrame(frame);
      if (phaseRef.current !== 'spin') return;
      const speed = list[roundRef.current]?.speedMultiplier ?? 1;
      const a = ((now - started.current) / (BASE_SWEEP / speed)) * 360;
      angle.current = a;
      if (needle.current) needle.current.setAttribute('transform', `rotate(${Math.min(a, 360).toFixed(2)} 50 50)`);
      if (a >= 360) lose();
    };
    raf = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(raf);
  }, [list]);

  /* The keys, the mouse and the pad */
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.repeat) return;
      switch (e.key) {
        case 'e': case 'E': case ' ': case 'Enter': press(); break;
        case 'Escape': case 'Backspace':
          cue('back');
          report('cancel');
          break;
        default: return;
      }
      e.preventDefault();
    };
    window.addEventListener('keydown', onKey);
    const stopPad = startPad((a) => {
      if (a === 'select') press();
      else if (a === 'back') { cue('back'); report('cancel'); }
    });
    return () => { window.removeEventListener('keydown', onKey); stopPad(); };
  }, []);

  const say = phase === 'miss' ? t('pick.miss') : phase === 'won' ? t('pick.won') : phase === 'hit' ? t('pick.hit') : t('pick.hint');

  return (
    <div className={cls('dl-pick', rtl && 'is-rtl')} dir={rtl ? 'rtl' : 'ltr'} lang={lang} onMouseDown={press}>
      <section className="dl-wrap dl-pick-wrap is-focus dl-in">
        <div className="dl-card">
          <div className="dl-card-body">
            <div className="dl-card-head" style={{ width: '100%' }}>
              <div>
                <div className="dl-kicker">{t('pick.kicker')}</div>
                <h2 className="dl-h">{t('pick.title')}</h2>
              </div>
              <IconPick />
            </div>

            <div className={cls('dl-dial', phase === 'hit' || phase === 'won' ? 'is-hit' : '', phase === 'miss' && 'is-miss')} dir="ltr">
              <svg viewBox="0 0 100 100">
                <circle className="dl-dial-track" cx="50" cy="50" r={R} />
                <g className="dl-dial-ticks">
                  {Array.from({ length: 12 }, (_, i) => {
                    const a = point(i * 30, R + 3);
                    const b = point(i * 30, R + 6);
                    return <line key={i} x1={a.x} y1={a.y} x2={b.x} y2={b.y} />;
                  })}
                </g>
                <path className="dl-dial-zone" d={arc(zone.from, zone.size)} />
                <line ref={needle} className="dl-dial-needle" x1="50" y1="50" x2="50" y2={50 - R - 2} />
                <circle className="dl-dial-hub" cx="50" cy="50" r="12" />
              </svg>
              <span className="dl-dial-key">E</span>
            </div>

            <p className="dl-pick-say">{say}</p>

            <div className="dl-rounds" aria-hidden="true">
              {list.map((_, i) => (
                <span key={i} className={cls('dl-round', i < round || phase === 'won' ? 'is-done' : '', i === round && phase !== 'won' && 'is-now')} />
              ))}
            </div>
          </div>
        </div>
        <i className="dl-tick" aria-hidden="true" />
      </section>
    </div>
  );
}
