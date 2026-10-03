/* ════════════════════════════════════════════════════════════════════════════
 * w_doorlock · board/Board.tsx - the staff's board of doors (/doorlock), on the pause menu's torn
 * cards:
 *
 *   masthead     the board's name · how many doors
 *   the list     every door - its state, its name, its number, its region - searched, in pages
 *   the door     its head, five tabs of settings (board/Editor.tsx)
 *   actions      new door · close   |   save · copy · paste · teleport · delete · back
 *   the note     "delete this door?" on paper
 *
 * The arrows, WASD, the pad and the mouse move between the stops spatially (nav.ts); Enter types
 * into a field or presses what the cursor is on; Q / E (LB / RB) turn the page or the tab; Escape /
 * Backspace goes back. The 'Select' / 'Back' buttons are the library's prompt group, drawn by Lua.
 *
 * ★ The board stays mounted while it is hidden: a new door is chosen in the world with the board
 *   out of the way, and it comes back exactly as it was left (dl:board:resume).
 * ════════════════════════════════════════════════════════════════════════════ */

import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { emptyForm, formOf, paste, payloadOf, settingsOf, validate, type Problem } from '../door';
import { cls, Txt, useI18n } from '../i18n';
import { pickNext, startPad, type Dir } from '../nav';
import { cue, post, type Cue } from '../nui';
import type { BoardOpen, BoardResume, Door, Form, Tab } from '../types';
import { GlyphNext, GlyphPrev, GlyphSearch, IconDoor, IconLock, IconUnlock } from '../ui/icons';
import { ConfirmNote } from '../ui/Note';
import Editor from './Editor';
import type { Nav } from './fields';

const PAGE = 10;
const TABS: Tab[] = ['general', 'characters', 'groups', 'items', 'lockpick'];

type View = 'list' | 'door';
interface Editing { id?: number; door?: Door; form: Form }
type Settings = ReturnType<typeof settingsOf>;

interface SaveAnswer { ok: boolean; door?: Door; reason?: string; choosing?: boolean }

function upsert(list: Door[], door: Door): Door[] {
  const out = list.filter((d) => d.id !== door.id);
  out.push(door);
  out.sort((a, b) => a.id - b.id);
  return out;
}

function playDoorSound(name: string) {
  if (!name) return;
  try {
    const audio = new Audio(`./sounds/${name}.ogg`);
    audio.volume = 0.6;
    void audio.play();
  } catch {
    /* a missing file is silent */
  }
}

export default function Board({ open, message, resume }: { open: boolean; message: BoardOpen; resume: BoardResume | null }) {
  const { t, rtl, lang } = useI18n();

  const [doors, setDoors] = useState<Door[]>(message.doors);
  const [sounds, setSounds] = useState<string[]>(message.sounds);
  const [defaultSound, setDefaultSound] = useState(message.defaultSound ?? '');
  const [view, setView] = useState<View>('list');
  const [query, setQuery] = useState('');
  const [page, setPage] = useState(0);
  const [editing, setEditing] = useState<Editing | null>(null);
  const [tab, setTab] = useState<Tab>('general');
  const [problems, setProblems] = useState<Problem[]>([]);
  const [copied, setCopied] = useState<Settings | null>(null);
  const [confirm, setConfirm] = useState(false);
  const [saving, setSaving] = useState(false);
  const [fresh, setFresh] = useState<number | null>(null);
  const [focus, setFocus] = useState('search');
  const [typing, setTyping] = useState(false);

  const navEls = useRef(new Map<string, HTMLElement>());
  const steppers = useRef(new Map<string, (delta: number) => void>());
  const openedAt = useRef(0);

  /* ! The focused id lives in a ref as well as the state: an arrow and an enter inside one frame arrive
     before React redraws, and the enter must act on the element the arrow just reached. */
  const focusRef = useRef(focus);
  focusRef.current = focus;
  const confirmRef = useRef(confirm);
  confirmRef.current = confirm;

  /* ── What the list shows ─────────────────────────────────────────────────── */
  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return doors;
    const id = q.replace(/^#/, '');
    return doors.filter((d) =>
      d.name.toLowerCase().includes(q) || (d.zone ?? '').toLowerCase().includes(q) || String(d.id) === id);
  }, [doors, query]);
  const pages = Math.max(1, Math.ceil(filtered.length / PAGE));
  const pageNow = Math.min(page, pages - 1);
  const shown = filtered.slice(pageNow * PAGE, pageNow * PAGE + PAGE);
  const lockedCount = doors.filter((d) => d.state === 1).length;
  const shownRef = useRef(shown);
  shownRef.current = shown;

  /* ── The cursor ──────────────────────────────────────────────────────────── */
  const reg = useCallback((id: string) => (el: HTMLElement | null) => {
    if (el) navEls.current.set(id, el); else navEls.current.delete(id);
  }, []);

  const regStep = useCallback((id: string, fn: ((delta: number) => void) | null) => {
    if (fn) steppers.current.set(id, fn); else steppers.current.delete(id);
  }, []);

  const setCursor = useCallback((id: string) => {
    focusRef.current = id;
    setFocus(id);
  }, []);

  const focusTo = useCallback((id: string, sound?: Cue) => {
    if (id === focusRef.current) return;
    setCursor(id);
    if (sound) cue(sound);
  }, [setCursor]);

  const scope = useCallback(() => {
    const out: { id: string; rect: DOMRect }[] = [];
    navEls.current.forEach((el, id) => {
      const inNote = id === 'yes' || id === 'no';
      if (confirmRef.current ? inNote : !inNote) out.push({ id, rect: el.getBoundingClientRect() });
    });
    return out;
  }, []);

  const move = useCallback((dir: Dir) => {
    const targets = scope();
    if (targets.length === 0) return;
    const cur = navEls.current.get(focusRef.current);
    if (!cur || !targets.some((x) => x.id === focusRef.current)) {
      focusTo(targets[0].id, 'navDown');
      return;
    }
    const next = pickNext(cur.getBoundingClientRect(), targets.filter((x) => x.id !== focusRef.current), dir);
    if (next) focusTo(next, dir === 'up' || dir === 'left' ? 'navUp' : 'navDown');
  }, [scope, focusTo]);

  /* Left / Right turn a stepper where the cursor rests on one (the arrow on the left of the screen
     goes left, whatever the language); elsewhere they move */
  const side = useCallback((dir: 'left' | 'right') => {
    const step = steppers.current.get(focusRef.current);
    if (step && !confirmRef.current) {
      step((dir === 'left') !== rtl ? -1 : 1);
      return;
    }
    move(dir);
  }, [move, rtl]);

  const hover = useCallback((id: string) => () => focusTo(id, 'navDown'), [focusTo]);

  /* The element the cursor reached is kept in view - inside the tab's own scroll only: a card is
     clipped by its torn mask (overflow: hidden), and scrolling one would slide its content away */
  useLayoutEffect(() => {
    const el = navEls.current.get(focus);
    if (el && el.closest('.dl-page.is-scroll')) el.scrollIntoView({ block: 'nearest' });
  }, [focus]);

  /* A page turned or a door left: the cursor never rests on something that is not there */
  useLayoutEffect(() => {
    if (!open || navEls.current.has(focusRef.current)) return;
    const firstRow = shown[0] ? `row:${shown[0].id}` : null;
    const fallback = confirm ? 'no' : view === 'door' ? 'tab:general' : (firstRow ?? 'search');
    setCursor(fallback);
  });

  /* ── Opening, resuming ───────────────────────────────────────────────────── */
  const openDoor = useCallback((door?: Door) => {
    setEditing(door ? { id: door.id, door, form: formOf(door) } : { form: emptyForm() });
    setTab('general');
    setProblems([]);
    setConfirm(false);
    setView('door');
    setCursor(door ? 'tab:general' : 'f:name');
  }, [setCursor]);

  const showRow = useCallback((list: Door[], id: number) => {
    const index = list.findIndex((d) => d.id === id);
    setQuery('');
    setPage(index >= 0 ? Math.floor(index / PAGE) : 0);
    setCursor(`row:${id}`);
  }, [setCursor]);

  useEffect(() => {
    setDoors(message.doors);
    setSounds(message.sounds);
    setDefaultSound(message.defaultSound ?? '');
    setQuery('');
    setPage(0);
    setConfirm(false);
    setSaving(false);
    setProblems([]);
    setFresh(null);
    openedAt.current = performance.now();
    const target = message.focus != null ? message.doors.find((d) => d.id === message.focus) : undefined;
    if (target) {
      openDoor(target);
    } else {
      setView('list');
      setEditing(null);
      setCursor(message.doors[0] ? `row:${message.doors[0].id}` : 'act:new');
    }
  }, [message.n]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (!resume) return;
    openedAt.current = performance.now();
    setSaving(false);
    if (resume.saved) {
      const door = resume.saved;
      const next = upsert(doors, door);
      setDoors(next);
      setView('list');
      setEditing(null);
      setFresh(door.id);
      showRow(next, door.id);
    } else {
      setCursor('act:save');
    }
  }, [resume?.n]); // eslint-disable-line react-hooks/exhaustive-deps

  /* ── The actions ─────────────────────────────────────────────────────────── */
  const notify = (key: string, style: 'success' | 'error' = 'success') => { void post('dl:board:notify', { key, style }); };

  const setForm = useCallback((fn: (form: Form) => Form) => {
    setEditing((e) => (e ? { ...e, form: fn(e.form) } : e));
  }, []);

  const close = useCallback(() => { void post('dl:board:close'); }, []);

  const leaveDoor = useCallback(() => {
    const id = editing?.id;
    cue('back');
    setView('list');
    setEditing(null);
    setProblems([]);
    if (id) showRow(doors, id); else setCursor('act:new');
  }, [editing, doors, showRow, setCursor]);

  const save = async () => {
    if (!editing || saving) return;
    const found = validate(editing.form);
    setProblems(found);
    if (found.length) {
      cue('locked');
      setTab(found[0].tab);
      setCursor(found[0].field);
      return;
    }
    cue('select');
    setSaving(true);
    const answer = await post<SaveAnswer>('dl:board:save', { id: editing.id ?? null, form: payloadOf(editing.form) });
    if (answer?.choosing) return;   // the board steps aside while the door is chosen in the world
    setSaving(false);
    if (!answer || !answer.ok || !answer.door) {
      cue('locked');
      notify(`notify.${answer?.reason ?? 'save_failed'}`, 'error');
      return;
    }
    const next = upsert(doors, answer.door);
    setDoors(next);
    notify('notify.door_saved');
    setView('list');
    setEditing(null);
    showRow(next, answer.door.id);
  };

  const copy = () => {
    if (!editing) return;
    setCopied(settingsOf(editing.form));
    cue('select');
    notify('notify.copied');
  };

  const pasteSettings = () => {
    if (!editing) return;
    if (!copied) { cue('locked'); notify('notify.nothing_copied', 'error'); return; }
    setForm((f) => paste(f, copied));
    cue('select');
    notify('notify.pasted');
  };

  const teleport = () => {
    if (!editing?.id) return;
    cue('select');
    void post('dl:board:teleport', { id: editing.id });
  };

  const askDelete = () => {
    if (!editing?.id) return;
    cue('select');
    setConfirm(true);
    setCursor('no');
  };

  const closeConfirm = useCallback(() => {
    setConfirm(false);
    cue('back');
    setCursor('act:delete');
  }, [setCursor]);

  const remove = async () => {
    const id = editing?.id;
    if (!id) return;
    setConfirm(false);
    const answer = await post<{ ok: boolean; reason?: string }>('dl:board:delete', { id });
    if (!answer?.ok) {
      cue('locked');
      notify(`notify.${answer?.reason ?? 'save_failed'}`, 'error');
      setCursor('act:delete');
      return;
    }
    cue('select');
    notify('notify.door_deleted');
    setDoors((list) => list.filter((d) => d.id !== id));
    setView('list');
    setEditing(null);
    setCursor('search');
  };

  const selectTab = useCallback((next: Tab, sound: Cue = 'select') => {
    setTab(next);
    cue(sound);
    setCursor(`tab:${next}`);
  }, [setCursor]);

  const turn = useCallback((delta: number) => {
    if (view === 'list') {
      if (pages < 2) return;
      setPage((p) => (Math.min(p, pages - 1) + delta + pages) % pages);
      cue(delta > 0 ? 'navDown' : 'navUp');
      return;
    }
    const i = TABS.indexOf(tab);
    selectTab(TABS[(i + delta + TABS.length) % TABS.length], delta > 0 ? 'navDown' : 'navUp');
  }, [view, pages, tab, selectTab]);

  const back = useCallback(() => {
    if (confirmRef.current) { closeConfirm(); return; }
    if (view === 'door') { leaveDoor(); return; }
    close();
  }, [view, closeConfirm, leaveDoor, close]);

  /* Enter / the pad's A: type into a field, press anything else */
  const activate = useCallback(() => {
    const el = navEls.current.get(focusRef.current);
    if (!el) return;
    if (el instanceof HTMLInputElement) {
      el.focus();
      el.select();
      return;
    }
    el.click();
  }, []);

  /* ── The keyboard ────────────────────────────────────────────────────────── */
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (performance.now() - openedAt.current < 150) return;
      const target = e.target as HTMLElement | null;
      if (target instanceof HTMLInputElement) {
        // a field holds the keyboard: only the keys that leave it are ours
        switch (e.key) {
          case 'Escape': target.blur(); break;
          case 'Enter':
            target.blur();
            if (focusRef.current === 'search') {
              const first = shownRef.current[0];
              if (first) focusTo(`row:${first.id}`, 'navDown');
            } else move('down');
            break;
          case 'ArrowUp': target.blur(); move('up'); break;
          case 'ArrowDown': target.blur(); move('down'); break;
          default: return;
        }
        e.preventDefault();
        return;
      }
      switch (e.key) {
        case 'ArrowUp': case 'w': case 'W': move('up'); break;
        case 'ArrowDown': case 's': case 'S': move('down'); break;
        case 'ArrowLeft': case 'a': case 'A': side('left'); break;
        case 'ArrowRight': case 'd': case 'D': side('right'); break;
        case 'Enter': case ' ': activate(); break;
        case 'Escape': case 'Backspace': back(); break;
        case 'q': case 'Q': turn(rtl ? 1 : -1); break;
        case 'e': case 'E': turn(rtl ? -1 : 1); break;
        case 'PageUp': turn(-1); break;
        case 'PageDown': turn(1); break;
        default: return;
      }
      e.preventDefault();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, move, side, activate, back, turn, rtl, focusTo]);

  /* The pad */
  const padRef = useRef<(a: string) => void>(() => {});
  padRef.current = (a: string) => {
    if (a === 'select') activate();
    else if (a === 'back') back();
    else if (a === 'prev') turn(-1);
    else if (a === 'next') turn(1);
    else if (a === 'left' || a === 'right') side(a);
    else move(a as Dir);
  };
  useEffect(() => {
    if (!open) return;
    return startPad((a) => padRef.current(a));
  }, [open]);

  /* Whether a field holds the keyboard - for the 'Select' button's label */
  useEffect(() => {
    const onIn = (e: FocusEvent) => setTyping(e.target instanceof HTMLInputElement);
    const onOut = () => setTyping(false);
    document.addEventListener('focusin', onIn);
    document.addEventListener('focusout', onOut);
    return () => { document.removeEventListener('focusin', onIn); document.removeEventListener('focusout', onOut); };
  }, []);

  const pageName = confirm ? 'confirm' : typing ? 'field' : 'root';
  useEffect(() => {
    if (open) void post('dl:page', { page: pageName });
  }, [open, pageName]);

  /* The board was hidden while a field held the keyboard: give it back to the game */
  useEffect(() => {
    if (!open && document.activeElement instanceof HTMLInputElement) document.activeElement.blur();
  }, [open]);

  /* ── The drawing ─────────────────────────────────────────────────────────── */
  const here = (id: string) => focus === id;
  const nav: Nav = { reg, hover, here, regStep, focusTo: (id) => setCursor(id) };

  const inActions = focus.startsWith('act:');
  const inList = view === 'list' && !inActions;
  const inPage = view === 'door' && !inActions && !confirm;
  const Tick = () => <i className="dl-tick" aria-hidden="true" />;

  const listActions = [
    { id: 'act:new', label: t('board.new'), run: () => { cue('select'); openDoor(); }, primary: true },
    { id: 'act:close', label: t('board.close'), run: () => close() },
  ];
  const doorActions = editing ? [
    { id: 'act:save', label: editing.id ? t('board.save') : t('board.choose'), run: () => void save(), primary: true, disabled: saving },
    { id: 'act:copy', label: t('board.copy'), run: copy },
    { id: 'act:paste', label: t('board.paste'), run: pasteSettings, disabled: !copied },
    ...(editing.id ? [
      { id: 'act:teleport', label: t('board.teleport'), run: teleport },
      { id: 'act:delete', label: t('board.delete'), run: askDelete },
    ] : []),
    { id: 'act:back', label: t('board.back'), run: leaveDoor },
  ] : [];
  const actions = view === 'list' ? listActions : doorActions;

  const counts: Partial<Record<Tab, number>> = editing ? {
    characters: editing.form.characters.filter((c) => c.trim()).length,
    groups: editing.form.groups.filter((g) => g.name.trim()).length,
    items: editing.form.items.filter((i) => i.name.trim()).length,
    lockpick: editing.form.rounds.length,
  } : {};

  const doorName = editing ? (editing.form.name.trim() || editing.door?.name || t('board.unnamed')) : '';
  const doorKicker = editing
    ? [editing.id ? t('board.door_n', editing.id) : t('board.new_door'), editing.door?.zone,
       editing.form.double ? t('board.double') : t('board.single')].filter(Boolean).join(' · ')
    : '';

  return (
    <div className={cls('dl', rtl && 'is-rtl', !open && 'is-hidden')} dir={rtl ? 'rtl' : 'ltr'} lang={lang}>
      <div className="dl-scrim" aria-hidden="true" />

      <main className={cls('dl-panel', confirm && 'is-dim')} key={message.n}>
        <i className="dl-strip" aria-hidden="true" />

        {/* ── The masthead ── */}
        <header className="dl-mast dl-in" style={{ ['--i' as string]: 0 }}>
          <span className="dl-mark"><Txt s={t('board.mark')} /></span>
          <span className="dl-mast-rule" aria-hidden="true" />
          <span className="dl-mast-item">{t('board.count')} <b className="dl-num">{doors.length}</b></span>
          <span className="dl-mast-item">{t('board.locked_count')} <b className="dl-num">{lockedCount}</b></span>
        </header>

        {view === 'list' ? (
          /* ── The list ── */
          <section className={cls('dl-wrap dl-list-wrap dl-in', inList && 'is-focus')} style={{ ['--i' as string]: 1 }}>
            <div className="dl-card">
              <div className="dl-card-body">
                <div className="dl-card-head">
                  <div style={{ minWidth: 0 }}>
                    <div className="dl-kicker">{t('board.kicker')}</div>
                    <h2 className="dl-h">{t('board.title')}</h2>
                  </div>
                  <IconDoor />
                </div>

                <label className={cls('dl-search', here('search') && 'is-here')} onMouseEnter={hover('search')}>
                  <GlyphSearch />
                  <input
                    ref={reg('search') as (el: HTMLInputElement | null) => void}
                    value={query}
                    placeholder={t('board.search')}
                    spellCheck={false}
                    autoComplete="off"
                    onFocus={() => setCursor('search')}
                    onChange={(e) => { setQuery(e.target.value); setPage(0); }}
                  />
                </label>

                {shown.length === 0 ? (
                  <p className="dl-empty">{query.trim() ? t('board.no_match') : t('board.empty')}</p>
                ) : (
                  <ul className="dl-rows">
                    {shown.map((d) => {
                      const id = `row:${d.id}`;
                      return (
                        <li
                          key={d.id}
                          ref={reg(id)}
                          className={cls('dl-row', here(id) && 'is-here', fresh === d.id && 'is-new')}
                          onMouseEnter={hover(id)}
                          onClick={() => { cue('select'); openDoor(d); }}
                        >
                          {d.state === 1 ? <IconLock /> : <IconUnlock />}
                          <div className="dl-row-main">
                            <span className="dl-row-name"><Txt s={d.name} /></span>
                            <span className="dl-row-meta">
                              <span className="dl-num">#{d.id}</span>
                              {d.zone ? <span>· <Txt s={d.zone} /></span> : null}
                              {d.doors ? <span>· {t('board.double')}</span> : null}
                            </span>
                          </div>
                          <span className="dl-row-end">{d.state === 1 ? t('board.locked') : t('board.unlocked')}</span>
                        </li>
                      );
                    })}
                  </ul>
                )}

                {pages > 1 && (
                  <div className="dl-pager">
                    <button type="button" tabIndex={-1} aria-label={t('board.prev_page')} onClick={() => turn(-1)}><GlyphPrev /></button>
                    <span className="dl-num">{pageNow + 1} / {pages}</span>
                    <button type="button" tabIndex={-1} aria-label={t('board.next_page')} onClick={() => turn(1)}><GlyphNext /></button>
                  </div>
                )}
              </div>
            </div>
            <Tick />
          </section>
        ) : editing && (
          <>
            {/* ── The door's head ── */}
            <section className="dl-wrap dl-head-wrap dl-in" style={{ ['--i' as string]: 1 }}>
              <div className="dl-card dl-head">
                <div className="dl-card-body">
                  <div className="dl-card-head">
                    <div style={{ minWidth: 0 }}>
                      <div className="dl-kicker"><Txt s={doorKicker} /></div>
                      <h2 className="dl-h" title={doorName}><Txt s={doorName} /></h2>
                    </div>
                    <IconDoor />
                  </div>
                </div>
              </div>
            </section>

            {/* ── The tabs and their page ── */}
            <section className={cls('dl-wrap dl-page-wrap dl-in', inPage && 'is-focus')} style={{ ['--i' as string]: 2 }}>
              <div className="dl-card">
                <div className="dl-card-body">
                  <div className="dl-tabs" role="tablist">
                    {TABS.map((tb) => {
                      const id = `tab:${tb}`;
                      const count = counts[tb];
                      return (
                        <button
                          key={tb}
                          type="button"
                          role="tab"
                          aria-selected={tab === tb}
                          ref={reg(id)}
                          className={cls('dl-tab', tab === tb && 'is-active', here(id) && 'is-here')}
                          onMouseEnter={hover(id)}
                          onClick={() => selectTab(tb)}
                        >
                          {t(`board.tab.${tb}`)}
                          {count ? <span className="dl-tab-num">{count}</span> : null}
                        </button>
                      );
                    })}
                  </div>
                  <div className={cls('dl-page', tab !== 'general' && 'is-scroll')}>
                    <Editor
                      tab={tab}
                      form={editing.form}
                      setForm={setForm}
                      problems={problems}
                      isNew={!editing.id}
                      sounds={sounds}
                      hear={(s) => playDoorSound(s || defaultSound)}
                      nav={nav}
                    />
                  </div>
                </div>
              </div>
              <Tick />
            </section>
          </>
        )}

        {/* ── The actions ── */}
        <nav className={cls('dl-wrap dl-actions-wrap dl-in', inActions && !confirm && 'is-focus')} style={{ ['--i' as string]: 3 }}>
          <div className={cls('dl-card dl-actions', actions.length > 4 && 'is-dense')}>
            {actions.map((a) => (
              <button
                key={a.id}
                type="button"
                ref={reg(a.id)}
                className={cls('dl-act', here(a.id) && 'is-here', a.primary && 'is-primary')}
                disabled={'disabled' in a && a.disabled === true && a.id !== 'act:paste'}
                onMouseEnter={hover(a.id)}
                onClick={a.run}
              >
                {a.label}
              </button>
            ))}
          </div>
        </nav>

        {/* ── Are you sure? ── */}
        {confirm && editing && (
          <ConfirmNote
            question={t('board.delete_q')}
            sub={editing.door?.name}
            here={focus}
            reg={reg}
            hover={hover}
            onYes={() => { void remove(); }}
            onNo={closeConfirm}
          />
        )}
      </main>
    </div>
  );
}
