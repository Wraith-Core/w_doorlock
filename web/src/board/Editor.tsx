/* ════════════════════════════════════════════════════════════════════════════
 * w_doorlock · board/Editor.tsx - one door in the notebook column (2026-11-12: the builders' look)
 *
 *   الأساس            the name, locked now, a double door (new ones), from how near it opens, the self-lock
 *   من يفتحه           jobs / gangs by their names and grades, the key items by their labels, listed
 *                      characters, the linked w_store store
 *   طرق أخرى للفتح     the code, the lock pick and its rounds (easy / medium / hard)
 *   خيارات متقدمة      folded: the numbers (seconds, metres, speed), the sounds, the rare switches, the item
 *                      metadata, custom rounds, and the door's identity in the game (id, hash, model)
 *
 * One column, one scroll: every part is a stop for the cursor (the board's navigation, nav.ts).
 * ════════════════════════════════════════════════════════════════════════════ */

import { parseNumber, ROUND_KINDS, type Problem } from '../door';
import { cls, Txt, useI18n } from '../i18n';
import { cue } from '../nui';
import type { Door, Form, Fresh, Names, RoundKind, StoreOption, Vec3 } from '../types';
import { GlyphNext } from '../ui/icons';
import { gradeLabel, groupOf, itemMatches, itemOf } from '../words';
import { Add, Field, Remove, Stepper, Switch, type Nav } from './fields';

interface Props {
  form: Form;
  setForm: (fn: (form: Form) => Form) => void;
  problems: Problem[];
  isNew: boolean;
  door?: Door;
  fresh?: Fresh;
  sounds: string[];
  stores: StoreOption[];
  at?: Vec3;
  names: Names;
  advanced: boolean;
  toggleAdvanced: () => void;
  hear: (sound: string) => void;
  nav: Nav;
}

const MAX_LINES = 32;
const REACH = ['1.5', '2', '3'];
const AUTOLOCK = ['', '3', '10', '30', '60'];

const sameNumber = (a: string, b: string) => (parseNumber(a) ?? NaN) === (parseNumber(b) ?? NaN);

export default function Editor({ form, setForm, problems, isNew, door, fresh, sounds, stores, at, names, advanced, toggleAdvanced, hear, nav }: Props) {
  const { t, lang } = useI18n();
  const error = (field: string) => {
    const p = problems.find((x) => x.field === field);
    return p ? t(p.key) : undefined;
  };
  const set = <K extends keyof Form>(key: K, value: Form[K]) => setForm((f) => ({ ...f, [key]: value }));

  /* ── the choices that stand for numbers ── */
  const reachValue = REACH.find((r) => sameNumber(r, form.maxDistance)) ?? 'other';
  const reachOptions = [
    { value: '1.5', label: t('board.reach.near') },
    { value: '2', label: t('board.reach.mid') },
    { value: '3', label: t('board.reach.far') },
    ...(reachValue === 'other' ? [{ value: 'other', label: t('board.reach.other', form.maxDistance || '?') }] : []),
  ];
  const autoValue = form.autolock.trim() === '' || sameNumber(form.autolock, '0')
    ? '' : (AUTOLOCK.find((a) => a && sameNumber(a, form.autolock)) ?? 'other');
  const autoOptions = [
    { value: '', label: t('board.auto.never') },
    { value: '3', label: t('board.auto.s', 3) },
    { value: '10', label: t('board.auto.s', 10) },
    { value: '30', label: t('board.auto.s', 30) },
    { value: '60', label: t('board.auto.min') },
    ...(autoValue === 'other' ? [{ value: 'other', label: t('board.auto.s', form.autolock) }] : []),
  ];

  /* ── groups: a picker of the server's jobs and gangs by their names ── */
  const groupOptions = (current: string) => {
    const list = names.groups.map((g) => ({
      value: g.name,
      label: `${lang === 'ar' ? g.ar : g.en}${g.kind === 'gang' ? ` · ${t('board.gang')}` : ''}`,
    }));
    if (current && !groupOf(names, current)) list.unshift({ value: current, label: t('board.group_unknown', current) });
    if (!current) list.unshift({ value: '', label: t('board.group_pick') });
    return list;
  };
  const gradeOptions = (name: string, grade: string) => {
    const g = groupOf(names, name);
    const list = (g?.grades ?? []).map((x) => ({
      value: String(x.grade),
      label: x.grade === 0 ? t('board.grade_all') : t('board.grade_from', lang === 'ar' ? x.ar : x.en),
    }));
    if (!list.length) list.push({ value: '0', label: t('board.grade_all') });
    if (grade && !list.some((o) => o.value === String(Math.floor(parseNumber(grade) ?? 0)))) {
      list.push({ value: grade, label: t('board.grade_from', gradeLabel(names, name, Math.floor(parseNumber(grade) ?? 0), lang)) });
    }
    return list;
  };
  const updateGroup = (i: number, patch: Partial<Form['groups'][number]>) =>
    setForm((f) => ({ ...f, groups: f.groups.map((g, j) => (j === i ? { ...g, ...patch } : g)) }));
  const updateItem = (i: number, patch: Partial<Form['items'][number]>) =>
    setForm((f) => ({ ...f, items: f.items.map((it, j) => (j === i ? { ...it, ...patch } : it)) }));
  const updateRound = (i: number, patch: Partial<Form['rounds'][number]>) =>
    setForm((f) => ({ ...f, rounds: f.rounds.map((r, j) => (j === i ? { ...r, ...patch } : r)) }));

  /* ── the store link, the nearest stores first ── */
  const far = (s: StoreOption) => (at && s.at ? Math.hypot(s.at.x - at.x, s.at.y - at.y, s.at.z - at.z) : null);
  const storeList = stores.map((s) => ({ s, d: far(s) })).sort((a, b) => (a.d ?? Infinity) - (b.d ?? Infinity) || a.s.id - b.s.id);
  const linked = stores.find((s) => String(s.id) === form.store);
  const storeOptions = [
    { value: '', label: t('board.store_none') },
    ...(form.store && !linked ? [{ value: form.store, label: t('board.store_missing', form.store) }] : []),
    ...storeList.map(({ s, d }) => ({
      value: String(s.id),
      label: [s.name, d !== null ? t('board.metres', Math.round(d)) : ''].filter(Boolean).join(' · '),
    })),
  ];

  const kinds = ROUND_KINDS.filter((k) => advanced || k !== 'custom' || form.rounds.some((r) => r.kind === 'custom'))
    .map((k) => ({ value: k, label: t(`board.round.${k}`) }));
  const soundOptions = [{ value: '', label: t('board.sound_default') }, ...sounds.map((s) => ({ value: s, label: s }))];

  return (
    <>
      {/* ═══ the basics ═══ */}
      <div className="dl-sec">{t('board.sec.basic')}</div>
      {isNew && (
        <p className={cls('dl-note-line dl-place', fresh?.where && 'is-ok')}>
          {fresh ? t('board.ready.chosen', fresh.where || t('board.here')) : t('board.ready.choose')}
        </p>
      )}
      <div className="dl-grid">
        <Field id="f:name" nav={nav} wide label={t('board.f.name')} placeholder={t('board.f.name_hint')}
          value={form.name} onChange={(v) => set('name', v)} error={error('f:name')} />
        <Stepper id="f:reach" nav={nav} label={t('board.f.reach')} options={reachOptions} value={reachValue}
          onChange={(v) => { if (v !== 'other') set('maxDistance', v); }} />
        <Stepper id="f:auto" nav={nav} label={t('board.f.autolock_say')} options={autoOptions} value={autoValue}
          onChange={(v) => { if (v !== 'other') set('autolock', v); }} />
      </div>
      <div className="dl-switches">
        <Switch id="sw:state" nav={nav} label={t('board.sw.locked')} on={form.state} onToggle={() => set('state', !form.state)} />
        <Switch id="sw:double" nav={nav} label={t('board.sw.double')} on={form.double} locked={!isNew || !!fresh}
          onToggle={() => set('double', !form.double)} />
      </div>

      {/* ═══ who opens it ═══ */}
      <div className="dl-sec">{t('board.sec.who')}</div>
      <p className="dl-note-line">{t('board.groups_note')}</p>
      <div className="dl-lines">
        {form.groups.map((g, i) => (
          <div className="dl-line" key={`g${i}`} style={{ gridTemplateColumns: 'minmax(0, 1.15fr) minmax(0, 1fr) auto' }}>
            {names.groups.length ? (
              <>
                <Stepper id={`g:${i}:name`} nav={nav} label={i === 0 ? t('board.f.group') : undefined}
                  options={groupOptions(g.name.trim())} value={g.name.trim()}
                  onChange={(v) => updateGroup(i, { name: v, grade: '0' })} />
                <Stepper id={`g:${i}:grade`} nav={nav} label={i === 0 ? t('board.f.grade') : undefined}
                  options={gradeOptions(g.name.trim(), g.grade)} value={String(Math.floor(parseNumber(g.grade) ?? 0))}
                  onChange={(v) => updateGroup(i, { grade: v })} />
              </>
            ) : (
              <>
                {/* no list from the core (VORP): the name is typed, as before */}
                <Field id={`g:${i}:name`} nav={nav} label={i === 0 ? t('board.f.group') : undefined} value={g.name}
                  placeholder={t('board.f.group_hint')} onChange={(v) => updateGroup(i, { name: v })} maxLength={50} />
                <Field id={`g:${i}:grade`} nav={nav} numeric label={i === 0 ? t('board.f.grade') : undefined} value={g.grade}
                  placeholder="0" onChange={(v) => updateGroup(i, { grade: v })} error={error(`g:${i}:grade`)} maxLength={3} />
              </>
            )}
            <Remove id={`x:g:${i}`} nav={nav} onClick={() => setForm((f) => ({ ...f, groups: f.groups.filter((_, j) => j !== i) }))} />
            {error(`g:${i}:name`) && <span className="dl-error" style={{ gridColumn: '1 / -1' }}>{error(`g:${i}:name`)}</span>}
          </div>
        ))}
      </div>
      <Add id="add:g" nav={nav} label={t('board.add_group')} disabled={form.groups.length >= MAX_LINES}
        onClick={() => {
          const first = names.groups[0]?.name ?? '';
          setForm((f) => ({ ...f, groups: [...f.groups, { name: first, grade: '0' }] }));
          nav.focusTo(`g:${form.groups.length}:name`);
        }} />

      <div className="dl-lines">
        {form.items.map((it, i) => {
          const known = itemOf(names, it.name);
          const hints = known ? [] : itemMatches(names, it.name);
          return (
            <div className="dl-line" key={`i${i}`} style={{ gridTemplateColumns: 'minmax(0, 1fr) 9rem auto' }}>
              <Field id={`i:${i}:name`} nav={nav} label={i === 0 ? t('board.f.item') : undefined} value={it.name}
                placeholder={t('board.f.item_hint')} onChange={(v) => updateItem(i, { name: v })} error={error(`i:${i}:name`)} maxLength={64} />
              <Switch id={`sw:i:${i}`} nav={nav} label={t('board.sw.use_up')} on={it.remove} onToggle={() => updateItem(i, { remove: !it.remove })} />
              <Remove id={`x:i:${i}`} nav={nav} onClick={() => setForm((f) => ({ ...f, items: f.items.filter((_, j) => j !== i) }))} />
              {(known || hints.length > 0) && (
                <div className="dl-hints" style={{ gridColumn: '1 / -1' }}>
                  {known ? <span className="dl-hint-ok"><Txt s={known.label} /></span> : hints.map((h, k) => {
                    const id = `ih:${i}:${k}`;
                    return (
                      <button key={h.name} type="button" ref={nav.reg(id)} className={cls('dl-chip', nav.here(id) && 'is-here')}
                        onMouseEnter={nav.hover(id)} onClick={() => { cue('select'); updateItem(i, { name: h.name }); nav.focusTo(`i:${i}:name`); }}>
                        <Txt s={h.label} />
                      </button>
                    );
                  })}
                </div>
              )}
            </div>
          );
        })}
      </div>
      <Add id="add:i" nav={nav} label={t('board.add_item')} disabled={form.items.length >= MAX_LINES}
        onClick={() => { setForm((f) => ({ ...f, items: [...f.items, { name: '', metadata: '', remove: false }] })); nav.focusTo(`i:${form.items.length}:name`); }} />

      <div className="dl-lines">
        {form.characters.map((c, i) => (
          <div className="dl-line" key={`c${i}`} style={{ gridTemplateColumns: 'minmax(0, 1fr) auto' }}>
            <Field id={`c:${i}`} nav={nav} label={i === 0 ? t('board.f.character') : undefined} value={c}
              placeholder={t('board.f.citizen_hint')} onChange={(v) => setForm((f) => ({ ...f, characters: f.characters.map((x, j) => (j === i ? v : x)) }))} maxLength={64} />
            <Remove id={`x:c:${i}`} nav={nav} onClick={() => setForm((f) => ({ ...f, characters: f.characters.filter((_, j) => j !== i) }))} />
          </div>
        ))}
      </div>
      <Add id="add:c" nav={nav} label={t('board.add_character')} disabled={form.characters.length >= 64}
        onClick={() => { setForm((f) => ({ ...f, characters: [...f.characters, ''] })); nav.focusTo(`c:${form.characters.length}`); }} />

      <div className="dl-grid dl-gap">
        <Stepper id="f:store" nav={nav} wide label={t('board.f.store')} options={storeOptions}
          value={form.store} onChange={(v) => set('store', v)} />
      </div>
      {linked && <p className="dl-note-line">{linked.owner ? t('board.store_owner', linked.owner) : t('board.store_gov')}</p>}
      {stores.length === 0 && <p className="dl-note-line">{t('board.store_offline')}</p>}

      {/* ═══ other ways in ═══ */}
      <div className="dl-sec">{t('board.sec.other')}</div>
      <div className="dl-grid">
        <Field id="f:passcode" nav={nav} wide label={t('board.f.passcode')} placeholder={t('board.f.passcode_hint')}
          value={form.passcode} onChange={(v) => set('passcode', v)} error={error('f:passcode')} maxLength={32} />
      </div>
      <div className="dl-switches">
        <Switch id="sw:lockpick" nav={nav} label={t('board.sw.lockpick')} on={form.lockpick} onToggle={() => set('lockpick', !form.lockpick)} />
      </div>
      {form.lockpick && (
        <>
          <p className="dl-note-line">{t('board.rounds_note')}</p>
          <div className="dl-lines">
            {form.rounds.map((r, i) => (
              <div className="dl-line" key={`r${i}`} style={{ gridTemplateColumns: 'auto minmax(0, 1fr) auto' }}>
                <span className="dl-line-num">{i + 1}</span>
                <Stepper<RoundKind> id={`r:${i}`} nav={nav} options={kinds} value={r.kind}
                  onChange={(v) => updateRound(i, { kind: v, areaSize: v === 'custom' && !r.areaSize ? '40' : r.areaSize, speedMultiplier: v === 'custom' && !r.speedMultiplier ? '1' : r.speedMultiplier })} />
                <Remove id={`x:r:${i}`} nav={nav} onClick={() => setForm((f) => ({ ...f, rounds: f.rounds.filter((_, j) => j !== i) }))} />
              </div>
            ))}
          </div>
          <Add id="add:r" nav={nav} label={t('board.add_round')} disabled={form.rounds.length >= 10}
            onClick={() => { setForm((f) => ({ ...f, rounds: [...f.rounds, { kind: 'medium', areaSize: '', speedMultiplier: '' }] })); nav.focusTo(`r:${form.rounds.length}`); }} />
        </>
      )}
      {!form.lockpick && form.rounds.length > 0 && <p className="dl-note-line">{t('board.rounds_kept', form.rounds.length)}</p>}

      {/* ═══ advanced, folded ═══ */}
      <button type="button" ref={nav.reg('adv')} className={cls('dl-fold', advanced && 'is-open', nav.here('adv') && 'is-here')}
        onMouseEnter={nav.hover('adv')} onClick={() => { cue(advanced ? 'toggleOff' : 'toggleOn'); toggleAdvanced(); }}>
        <GlyphNext />
        <span>{t('board.sec.advanced')}</span>
      </button>
      {advanced && (
        <div className="dl-adv">
          <div className="dl-grid">
            <Field id="f:autolock" nav={nav} numeric label={t('board.f.autolock')} placeholder={t('board.f.autolock_hint')}
              value={form.autolock} onChange={(v) => set('autolock', v)} error={error('f:autolock')} maxLength={6} />
            <Field id="f:maxDistance" nav={nav} numeric label={t('board.f.distance')} placeholder="2"
              value={form.maxDistance} onChange={(v) => set('maxDistance', v)} error={error('f:maxDistance')} maxLength={5} />
            <Field id="f:doorRate" nav={nav} numeric label={t('board.f.rate')} placeholder={t('board.f.rate_hint')}
              value={form.doorRate} onChange={(v) => set('doorRate', v)} error={error('f:doorRate')} maxLength={5} />
            <span />
            <Stepper id="f:lockSound" nav={nav} label={t('board.f.lock_sound')} options={soundOptions}
              value={form.lockSound} onChange={(v) => set('lockSound', v)} hear={() => hear(form.lockSound)} />
            <Stepper id="f:unlockSound" nav={nav} label={t('board.f.unlock_sound')} options={soundOptions}
              value={form.unlockSound} onChange={(v) => set('unlockSound', v)} hear={() => hear(form.unlockSound || form.lockSound)} />
          </div>
          <div className="dl-switches">
            <Switch id="sw:auto" nav={nav} label={t('board.sw.auto')} on={form.auto} onToggle={() => set('auto', !form.auto)} />
            <Switch id="sw:hideUi" nav={nav} label={t('board.sw.hide')} on={form.hideUi} onToggle={() => set('hideUi', !form.hideUi)} />
            <Switch id="sw:holdOpen" nav={nav} label={t('board.sw.hold')} on={form.holdOpen} onToggle={() => set('holdOpen', !form.holdOpen)} />
          </div>
          {form.items.length > 0 && (
            <div className="dl-lines">
              {form.items.map((it, i) => (
                <div className="dl-line" key={`im${i}`} style={{ gridTemplateColumns: 'minmax(0, 1fr) minmax(0, 1fr)' }}>
                  <span className="dl-line-text"><Txt s={itemOf(names, it.name)?.label ?? it.name} /> <span className="dl-mono">{it.name}</span></span>
                  <Field id={`i:${i}:meta`} nav={nav} label={i === 0 ? t('board.f.metadata') : undefined} value={it.metadata}
                    placeholder={t('board.f.metadata_hint')} onChange={(v) => updateItem(i, { metadata: v })} maxLength={64} />
                </div>
              ))}
            </div>
          )}
          {form.rounds.some((r) => r.kind === 'custom') && (
            <div className="dl-lines">
              {form.rounds.map((r, i) => r.kind !== 'custom' ? null : (
                <div className="dl-line" key={`rc${i}`} style={{ gridTemplateColumns: 'auto minmax(0, 1fr) minmax(0, 1fr)' }}>
                  <span className="dl-line-num">{i + 1}</span>
                  <Field id={`r:${i}:size`} nav={nav} numeric label={t('board.f.area')} value={r.areaSize}
                    placeholder="40" onChange={(v) => updateRound(i, { areaSize: v })} error={error(`r:${i}:size`)} maxLength={3} />
                  <Field id={`r:${i}:speed`} nav={nav} numeric label={t('board.f.speed')} value={r.speedMultiplier}
                    placeholder="1" onChange={(v) => updateRound(i, { speedMultiplier: v })} error={error(`r:${i}:speed`)} maxLength={4} />
                </div>
              ))}
            </div>
          )}
          {door && (
            <p className="dl-note-line dl-ident">
              {t('board.ident')} <span className="dl-mono">#{door.id}</span>
              {door.hash != null && <> · <span className="dl-mono">{door.hash}</span></>}
              {door.model != null && <> · <span className="dl-mono">{door.model}</span></>}
              {door.doors && <> · {t('board.double')}</>}
              {door.coords && <> · <span className="dl-mono">{door.coords.x.toFixed(1)}, {door.coords.y.toFixed(1)}, {door.coords.z.toFixed(1)}</span></>}
            </p>
          )}
        </div>
      )}
    </>
  );
}
