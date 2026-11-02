/* ════════════════════════════════════════════════════════════════════════════
 * w_doorlock · board/Editor.tsx - one door's settings, by tab
 *
 *   general     name, code, autolock, distance, speed, the two sounds, the six switches
 *   characters  the citizen ids that always open it
 *   store       2.2.0: the w_store store whose owner and staff open it (the nearest stores first)
 *   groups      job / gang names and the lowest grade that opens it
 *   items       the items that open it (a key), their metadata type, used up or not
 *   lockpick    the rounds of the lock pick (none = the server's default)
 * ════════════════════════════════════════════════════════════════════════════ */

import { parseNumber, ROUND_KINDS, type Problem } from '../door';
import { useI18n } from '../i18n';
import type { Form, RoundKind, StoreOption, Tab, Vec3 } from '../types';
import { Add, Field, Remove, Stepper, Switch, type Nav } from './fields';

interface Props {
  tab: Tab;
  form: Form;
  setForm: (fn: (form: Form) => Form) => void;
  problems: Problem[];
  isNew: boolean;
  sounds: string[];
  stores: StoreOption[];
  at?: Vec3;
  hear: (sound: string) => void;
  nav: Nav;
}

const MAX_LINES = 32;

export default function Editor({ tab, form, setForm, problems, isNew, sounds, stores, at, hear, nav }: Props) {
  const { t } = useI18n();
  const error = (field: string) => {
    const p = problems.find((x) => x.field === field);
    return p ? t(p.key) : undefined;
  };
  const set = <K extends keyof Form>(key: K, value: Form[K]) => setForm((f) => ({ ...f, [key]: value }));

  if (tab === 'general') {
    const soundOptions = [{ value: '', label: t('board.sound_default') }, ...sounds.map((s) => ({ value: s, label: s }))];
    return (
      <>
        <div className="dl-grid">
          <Field id="f:name" nav={nav} wide label={t('board.f.name')} placeholder={t('board.f.name_hint')}
            value={form.name} onChange={(v) => set('name', v)} error={error('f:name')} />
          <Field id="f:passcode" nav={nav} label={t('board.f.passcode')} placeholder={t('board.f.passcode_hint')}
            value={form.passcode} onChange={(v) => set('passcode', v)} error={error('f:passcode')} maxLength={32} />
          <Field id="f:autolock" nav={nav} numeric label={t('board.f.autolock')} placeholder={t('board.f.autolock_hint')}
            value={form.autolock} onChange={(v) => set('autolock', v)} error={error('f:autolock')} maxLength={6} />
          <Field id="f:maxDistance" nav={nav} numeric label={t('board.f.distance')} placeholder="2"
            value={form.maxDistance} onChange={(v) => set('maxDistance', v)} error={error('f:maxDistance')} maxLength={5} />
          <Field id="f:doorRate" nav={nav} numeric label={t('board.f.rate')} placeholder={t('board.f.rate_hint')}
            value={form.doorRate} onChange={(v) => set('doorRate', v)} error={error('f:doorRate')} maxLength={5} />
          <Stepper id="f:lockSound" nav={nav} label={t('board.f.lock_sound')} options={soundOptions}
            value={form.lockSound} onChange={(v) => set('lockSound', v)} hear={() => hear(form.lockSound)} />
          <Stepper id="f:unlockSound" nav={nav} label={t('board.f.unlock_sound')} options={soundOptions}
            value={form.unlockSound} onChange={(v) => set('unlockSound', v)} hear={() => hear(form.unlockSound || form.lockSound)} />
        </div>
        <div className="dl-switches">
          <Switch id="sw:state" nav={nav} label={t('board.sw.locked')} on={form.state} onToggle={() => set('state', !form.state)} />
          <Switch id="sw:double" nav={nav} label={t('board.sw.double')} on={form.double} locked={!isNew}
            onToggle={() => set('double', !form.double)} />
          <Switch id="sw:auto" nav={nav} label={t('board.sw.auto')} on={form.auto} onToggle={() => set('auto', !form.auto)} />
          <Switch id="sw:lockpick" nav={nav} label={t('board.sw.lockpick')} on={form.lockpick} onToggle={() => set('lockpick', !form.lockpick)} />
          <Switch id="sw:hideUi" nav={nav} label={t('board.sw.hide')} on={form.hideUi} onToggle={() => set('hideUi', !form.hideUi)} />
          <Switch id="sw:holdOpen" nav={nav} label={t('board.sw.hold')} on={form.holdOpen} onToggle={() => set('holdOpen', !form.holdOpen)} />
        </div>
      </>
    );
  }

  if (tab === 'characters') {
    const rows = form.characters;
    const update = (i: number, v: string) => setForm((f) => ({ ...f, characters: f.characters.map((c, j) => (j === i ? v : c)) }));
    const remove = (i: number) => setForm((f) => ({ ...f, characters: f.characters.filter((_, j) => j !== i) }));
    return (
      <>
        <p className="dl-note-line">{t('board.characters_note')}</p>
        <div className="dl-lines">
          {rows.map((c, i) => (
            <div className="dl-line" key={i} style={{ gridTemplateColumns: 'auto minmax(0, 1fr) auto' }}>
              <span className="dl-line-num">{i + 1}</span>
              <Field id={`c:${i}`} nav={nav} value={c} placeholder={t('board.f.citizen_hint')} onChange={(v) => update(i, v)} maxLength={64} />
              <Remove id={`x:c:${i}`} nav={nav} onClick={() => remove(i)} />
            </div>
          ))}
        </div>
        <Add id="add:c" nav={nav} label={t('board.add_character')} disabled={rows.length >= 64}
          onClick={() => { setForm((f) => ({ ...f, characters: [...f.characters, ''] })); nav.focusTo(`c:${rows.length}`); }} />
      </>
    );
  }

  if (tab === 'store') {
    // the nearest stores to the door first (a new door has no place yet: by number)
    const far = (s: StoreOption) => (at && s.at ? Math.hypot(s.at.x - at.x, s.at.y - at.y, s.at.z - at.z) : null);
    const list = stores
      .map((s) => ({ s, d: far(s) }))
      .sort((a, b) => (a.d ?? Infinity) - (b.d ?? Infinity) || a.s.id - b.s.id);
    const linked = stores.find((s) => String(s.id) === form.store);
    const options = [
      { value: '', label: t('board.store_none') },
      // a link to a store the list does not hold (closed by the admins, or w_store stopped) stays choosable
      ...(form.store && !linked ? [{ value: form.store, label: t('board.store_missing', form.store) }] : []),
      ...list.map(({ s, d }) => ({
        value: String(s.id),
        label: [s.name, `#${s.id}`, d !== null ? t('board.metres', Math.round(d)) : ''].filter(Boolean).join(' · '),
      })),
    ];
    const autolock = parseNumber(form.autolock) ?? 0;
    return (
      <>
        <p className="dl-note-line">{t('board.store_note')}</p>
        {stores.length === 0 && <p className="dl-note-line">{t('board.store_offline')}</p>}
        <div className="dl-grid">
          <Stepper id="f:store" nav={nav} wide label={t('board.f.store')} options={options}
            value={form.store} onChange={(v) => set('store', v)} />
        </div>
        {linked && <p className="dl-note-line">{linked.owner ? t('board.store_owner', linked.owner) : t('board.store_gov')}</p>}
        {form.store && autolock > 0 && <p className="dl-note-line">{t('board.store_autolock', autolock)}</p>}
      </>
    );
  }

  if (tab === 'groups') {
    const rows = form.groups;
    const update = (i: number, key: 'name' | 'grade', v: string) =>
      setForm((f) => ({ ...f, groups: f.groups.map((g, j) => (j === i ? { ...g, [key]: v } : g)) }));
    const remove = (i: number) => setForm((f) => ({ ...f, groups: f.groups.filter((_, j) => j !== i) }));
    return (
      <>
        <p className="dl-note-line">{t('board.groups_note')}</p>
        <div className="dl-lines">
          {rows.map((g, i) => (
            <div className="dl-line" key={i} style={{ gridTemplateColumns: 'minmax(0, 1fr) 8rem auto' }}>
              <Field id={`g:${i}:name`} nav={nav} label={i === 0 ? t('board.f.group') : undefined} value={g.name}
                placeholder={t('board.f.group_hint')} onChange={(v) => update(i, 'name', v)} error={error(`g:${i}:name`)} maxLength={50} />
              <Field id={`g:${i}:grade`} nav={nav} numeric label={i === 0 ? t('board.f.grade') : undefined} value={g.grade}
                placeholder="0" onChange={(v) => update(i, 'grade', v)} error={error(`g:${i}:grade`)} maxLength={3} />
              <Remove id={`x:g:${i}`} nav={nav} onClick={() => remove(i)} />
            </div>
          ))}
        </div>
        <Add id="add:g" nav={nav} label={t('board.add_group')} disabled={rows.length >= MAX_LINES}
          onClick={() => { setForm((f) => ({ ...f, groups: [...f.groups, { name: '', grade: '' }] })); nav.focusTo(`g:${rows.length}:name`); }} />
      </>
    );
  }

  if (tab === 'items') {
    const rows = form.items;
    const update = (i: number, patch: Partial<Form['items'][number]>) =>
      setForm((f) => ({ ...f, items: f.items.map((it, j) => (j === i ? { ...it, ...patch } : it)) }));
    const remove = (i: number) => setForm((f) => ({ ...f, items: f.items.filter((_, j) => j !== i) }));
    return (
      <>
        <p className="dl-note-line">{t('board.items_note')}</p>
        <div className="dl-lines">
          {rows.map((it, i) => (
            <div className="dl-line" key={i} style={{ gridTemplateColumns: 'minmax(0, 1fr) minmax(0, 0.8fr) 9.5rem auto' }}>
              <Field id={`i:${i}:name`} nav={nav} label={i === 0 ? t('board.f.item') : undefined} value={it.name}
                placeholder={t('board.f.item_hint')} onChange={(v) => update(i, { name: v })} error={error(`i:${i}:name`)} maxLength={64} />
              <Field id={`i:${i}:meta`} nav={nav} label={i === 0 ? t('board.f.metadata') : undefined} value={it.metadata}
                placeholder={t('board.f.metadata_hint')} onChange={(v) => update(i, { metadata: v })} maxLength={64} />
              <Switch id={`sw:i:${i}`} nav={nav} label={t('board.sw.use_up')} on={it.remove} onToggle={() => update(i, { remove: !it.remove })} />
              <Remove id={`x:i:${i}`} nav={nav} onClick={() => remove(i)} />
            </div>
          ))}
        </div>
        <Add id="add:i" nav={nav} label={t('board.add_item')} disabled={rows.length >= MAX_LINES}
          onClick={() => { setForm((f) => ({ ...f, items: [...f.items, { name: '', metadata: '', remove: false }] })); nav.focusTo(`i:${rows.length}:name`); }} />
      </>
    );
  }

  // lockpick
  const rows = form.rounds;
  const kinds = ROUND_KINDS.map((k) => ({ value: k, label: t(`board.round.${k}`) }));
  const update = (i: number, patch: Partial<Form['rounds'][number]>) =>
    setForm((f) => ({ ...f, rounds: f.rounds.map((r, j) => (j === i ? { ...r, ...patch } : r)) }));
  const remove = (i: number) => setForm((f) => ({ ...f, rounds: f.rounds.filter((_, j) => j !== i) }));
  return (
    <>
      <p className="dl-note-line">{form.lockpick ? t('board.rounds_note') : t('board.rounds_off')}</p>
      <div className="dl-lines">
        {rows.map((r, i) => (
          <div className="dl-line" key={i} style={{ gridTemplateColumns: 'auto minmax(0, 1fr) 6.5rem 6.5rem auto' }}>
            <span className="dl-line-num">{i + 1}</span>
            <Stepper<RoundKind> id={`r:${i}`} nav={nav} label={i === 0 ? t('board.f.difficulty') : undefined} options={kinds} value={r.kind}
              onChange={(v) => update(i, { kind: v, areaSize: v === 'custom' && !r.areaSize ? '40' : r.areaSize, speedMultiplier: v === 'custom' && !r.speedMultiplier ? '1' : r.speedMultiplier })} />
            {r.kind === 'custom' ? (
              <>
                <Field id={`r:${i}:size`} nav={nav} numeric label={t('board.f.area')} value={r.areaSize}
                  placeholder="40" onChange={(v) => update(i, { areaSize: v })} error={error(`r:${i}:size`)} maxLength={3} />
                <Field id={`r:${i}:speed`} nav={nav} numeric label={t('board.f.speed')} value={r.speedMultiplier}
                  placeholder="1" onChange={(v) => update(i, { speedMultiplier: v })} error={error(`r:${i}:speed`)} maxLength={4} />
              </>
            ) : (
              <><span /><span /></>
            )}
            <Remove id={`x:r:${i}`} nav={nav} onClick={() => remove(i)} />
          </div>
        ))}
      </div>
      <Add id="add:r" nav={nav} label={t('board.add_round')} disabled={rows.length >= 10}
        onClick={() => { setForm((f) => ({ ...f, rounds: [...f.rounds, { kind: 'medium', areaSize: '', speedMultiplier: '' }] })); nav.focusTo(`r:${rows.length}`); }} />
    </>
  );
}
