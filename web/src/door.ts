/* ════════════════════════════════════════════════════════════════════════════
 * w_doorlock · door.ts - a door between the server's shape and the editor's
 *
 *   formOf(door)        the row as the editor shows it (text fields, lists of rows)
 *   emptyForm()         a new door
 *   payloadOf(form)     what is sent to Lua (the server cleans it again: it trusts nothing)
 *   validate(form)      { fieldId: errorKey } - nothing leaves while a field is wrong
 *   settingsOf / paste  ox_doorlock's "copy settings": everything but the name and the door itself
 * ════════════════════════════════════════════════════════════════════════════ */

import type { Difficulty, Door, Form, RoundForm, RoundKind, Tab } from './types';

/** ox_lib's skill check presets - the lock pick plays them the same way */
export const PRESETS: Record<'easy' | 'medium' | 'hard', { areaSize: number; speedMultiplier: number }> = {
  easy: { areaSize: 50, speedMultiplier: 1 },
  medium: { areaSize: 40, speedMultiplier: 1.5 },
  hard: { areaSize: 25, speedMultiplier: 1.75 },
};

export const ROUND_KINDS: RoundKind[] = ['easy', 'medium', 'hard', 'custom'];

const text = (v: unknown): string => (v === undefined || v === null ? '' : String(v));

function groupRows(groups: Door['groups']): Form['groups'] {
  if (!groups) return [];
  if (typeof groups === 'string') return [{ name: groups, grade: '0' }];
  if (Array.isArray(groups)) return groups.map((name) => ({ name: String(name), grade: '0' }));
  return Object.entries(groups).map(([name, grade]) => ({ name, grade: text(grade ?? 0) }));
}

function roundOf(d: Difficulty): RoundForm {
  if (typeof d === 'string') return { kind: d, areaSize: '', speedMultiplier: '' };
  return { kind: 'custom', areaSize: text(d.areaSize), speedMultiplier: text(d.speedMultiplier) };
}

export function emptyForm(): Form {
  return {
    name: '',
    passcode: '',
    autolock: '',
    maxDistance: '2',
    doorRate: '',
    lockSound: '',
    unlockSound: '',
    state: true,
    double: false,
    auto: false,
    lockpick: false,
    hideUi: false,
    holdOpen: false,
    characters: [],
    groups: [],
    items: [],
    rounds: [],
    store: '',
  };
}

export function formOf(door: Door): Form {
  return {
    name: text(door.name),
    passcode: text(door.passcode),
    autolock: door.autolock ? text(door.autolock) : '',
    maxDistance: text(door.maxDistance ?? 2),
    doorRate: door.doorRate ? text(door.doorRate) : '',
    lockSound: text(door.lockSound),
    unlockSound: text(door.unlockSound),
    state: door.state !== 0,
    double: Array.isArray(door.doors) && door.doors.length === 2,
    auto: !!door.auto,
    lockpick: !!door.lockpick,
    hideUi: !!door.hideUi,
    holdOpen: !!door.holdOpen,
    characters: (door.characters ?? []).map((c) => String(c)),
    groups: groupRows(door.groups),
    items: (door.items ?? []).map((item) =>
      typeof item === 'string'
        ? { name: item, metadata: '', remove: false }
        : { name: text(item.name), metadata: text(item.metadata), remove: !!item.remove }),
    rounds: (door.lockpickDifficulty ?? []).map(roundOf),
    store: door.store ? text(door.store) : '',
  };
}

/** A number typed by a person: Arabic-Indic digits and a comma for the decimal point are accepted */
export function parseNumber(value: string): number | null {
  const western = value
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06f0))
    .replace(/[,٫]/g, '.')
    .trim();
  if (western === '') return null;
  const n = Number(western);
  return Number.isFinite(n) ? n : null;
}

const trimmed = (v: string) => v.trim();

export function payloadOf(form: Form) {
  return {
    name: trimmed(form.name),
    passcode: trimmed(form.passcode),
    autolock: parseNumber(form.autolock) ?? 0,
    maxDistance: parseNumber(form.maxDistance) ?? 2,
    doorRate: parseNumber(form.doorRate) ?? 0,
    lockSound: form.lockSound,
    unlockSound: form.unlockSound,
    state: form.state,
    double: form.double,
    auto: form.auto,
    lockpick: form.lockpick,
    hideUi: form.hideUi,
    holdOpen: form.holdOpen,
    characters: form.characters.map(trimmed).filter(Boolean),
    groups: form.groups
      .filter((g) => trimmed(g.name) !== '')
      .map((g) => ({ name: trimmed(g.name), grade: Math.max(0, Math.floor(parseNumber(g.grade) ?? 0)) })),
    items: form.items
      .filter((i) => trimmed(i.name) !== '')
      .map((i) => ({ name: trimmed(i.name), metadata: trimmed(i.metadata), remove: i.remove })),
    lockpickDifficulty: form.rounds.map((r): Difficulty =>
      r.kind === 'custom'
        ? { areaSize: parseNumber(r.areaSize) ?? 40, speedMultiplier: parseNumber(r.speedMultiplier) ?? 1 }
        : r.kind),
    store: form.store ? Number(form.store) : 0,
  };
}

export interface Problem { field: string; key: string; tab: Tab }

/** The first problems of the form, by the tab they sit on */
export function validate(form: Form): Problem[] {
  const out: Problem[] = [];
  const num = (field: string, value: string, low: number, high: number, tab: Tab, required = false) => {
    if (value.trim() === '') {
      if (required) out.push({ field, key: 'board.error.required', tab });
      return;
    }
    const n = parseNumber(value);
    if (n === null) out.push({ field, key: 'board.error.number', tab });
    else if (n < low || n > high) out.push({ field, key: 'board.error.range', tab });
  };

  if (form.name.trim().length > 100) out.push({ field: 'f:name', key: 'board.error.long', tab: 'general' });
  if (form.passcode.trim().length > 32) out.push({ field: 'f:passcode', key: 'board.error.long', tab: 'general' });
  num('f:autolock', form.autolock, 0, 86400, 'general');
  num('f:maxDistance', form.maxDistance, 0.5, 30, 'general', true);
  num('f:doorRate', form.doorRate, 0, 10, 'general');

  form.groups.forEach((g, i) => {
    if (g.name.trim() === '' && g.grade.trim() !== '') out.push({ field: `g:${i}:name`, key: 'board.error.required', tab: 'groups' });
    num(`g:${i}:grade`, g.grade, 0, 100, 'groups');
  });
  form.items.forEach((item, i) => {
    if (item.name.trim() === '' && item.metadata.trim() !== '') out.push({ field: `i:${i}:name`, key: 'board.error.required', tab: 'items' });
  });
  form.rounds.forEach((r, i) => {
    if (r.kind !== 'custom') return;
    num(`r:${i}:size`, r.areaSize, 5, 180, 'lockpick', true);
    num(`r:${i}:speed`, r.speedMultiplier, 0.1, 5, 'lockpick', true);
  });
  return out;
}

type Settings = Omit<Form, 'name' | 'double'>;

export function settingsOf(form: Form): Settings {
  const { name: _name, double: _double, ...rest } = form;
  return JSON.parse(JSON.stringify(rest)) as Settings;
}

export function paste(form: Form, settings: Settings): Form {
  return { ...form, ...JSON.parse(JSON.stringify(settings)) as Settings, name: form.name, double: form.double };
}

/** A round as the lock pick plays it */
export function presetOf(d: Difficulty): { areaSize: number; speedMultiplier: number } {
  if (typeof d === 'string') return PRESETS[d] ?? PRESETS.medium;
  const areaSize = Math.min(180, Math.max(5, Number(d.areaSize) || 40));
  const speedMultiplier = Math.min(5, Math.max(0.1, Number(d.speedMultiplier) || 1));
  return { areaSize, speedMultiplier };
}
