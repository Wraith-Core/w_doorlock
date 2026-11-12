/* ════════════════════════════════════════════════════════════════════════════
 * w_doorlock · words.ts - a door said in words (the notebook board, 2026-11-12)
 *
 *   who(form, names)       «الشرطة من رتبة ضابط وما فوق، ومن معه مفتاح السجن»
 *   sentence(form, ...)    «مقفل · يفتحه الشرطة …»
 *   readiness(form, ...)   what is still wrong, in words, with the field to fix (the save's own checks)
 *
 * Keys (police, prison_key) are never the words the staff read: the jobs, grades and items come with
 * their names from the server (w_doorlock:admin:names). A key the lists do not hold is said as it is.
 * ════════════════════════════════════════════════════════════════════════════ */

import { parseNumber, validate, type Problem } from './door';
import type { Form, GroupName, ItemName, Lang, Names } from './types';

type T = (key: string, ...args: (string | number)[]) => string;

export function groupOf(names: Names, name: string): GroupName | undefined {
  return names.groups.find((g) => g.name === name);
}

export function groupLabel(names: Names, name: string, lang: Lang): string {
  const g = groupOf(names, name);
  return g ? (lang === 'ar' ? g.ar : g.en) : name;
}

export function gradeLabel(names: Names, name: string, grade: number, lang: Lang): string {
  const g = groupOf(names, name)?.grades.find((x) => x.grade === grade);
  return g ? (lang === 'ar' ? g.ar : g.en) : String(grade);
}

export function itemOf(names: Names, name: string): ItemName | undefined {
  const key = name.trim().toLowerCase();
  return names.items.find((i) => i.name.toLowerCase() === key);
}

export function itemLabel(names: Names, name: string): string {
  return itemOf(names, name)?.label ?? name;
}

/** Items whose name or label holds the text (the key picker's suggestions) */
export function itemMatches(names: Names, text: string, max = 4): ItemName[] {
  const q = text.trim().toLowerCase();
  if (q.length < 2) return [];
  const out: ItemName[] = [];
  for (const it of names.items) {
    if (it.name.toLowerCase() === q) continue;
    if (it.name.toLowerCase().includes(q) || it.label.toLowerCase().includes(q)) out.push(it);
    if (out.length >= max) break;
  }
  return out;
}

const joinWords = (parts: string[], t: T) => {
  if (parts.length <= 1) return parts.join('');
  return parts.slice(0, -1).join(t('board.say.comma')) + t('board.say.and') + parts[parts.length - 1];
};

/** Who opens the door, in words ('' = nobody but the scripts and the lock pick) */
export function who(form: Form, names: Names, lang: Lang, t: T): string {
  const parts: string[] = [];
  for (const g of form.groups) {
    const name = g.name.trim();
    if (!name) continue;
    const grade = Math.max(0, Math.floor(parseNumber(g.grade) ?? 0));
    const label = groupLabel(names, name, lang);
    parts.push(grade > 0 ? t('board.say.group_from', label, gradeLabel(names, name, grade, lang)) : label);
  }
  const people = form.characters.filter((c) => c.trim()).length;
  if (people > 0) parts.push(t('board.say.people', people));
  if (form.store) parts.push(t('board.say.store'));
  for (const it of form.items) {
    if (it.name.trim()) parts.push(t('board.say.item', itemLabel(names, it.name)));
  }
  if (form.passcode.trim()) parts.push(t('board.say.code'));
  return parts.length ? joinWords(parts, t) : '';
}

/** The door's line: its state, who opens it, the lock pick, the self-lock */
export function sentence(form: Form, names: Names, lang: Lang, t: T): string {
  const bits = [form.state ? t('board.locked') : t('board.unlocked')];
  const w = who(form, names, lang, t);
  bits.push(w ? t('board.say.opens', w) : t('board.say.nobody'));
  if (form.lockpick) bits.push(t('board.say.lockpick'));
  const auto = parseNumber(form.autolock) ?? 0;
  if (auto >= 1) bits.push(t('board.say.auto', Math.floor(auto)));
  return bits.join(' · ');
}

export interface Ready {
  /** the first thing that stops the save (the save's own checks), with the field to fix */
  block?: { text: string; field: string };
  /** said but not blocking */
  warn?: string;
}

const FIELD_WORD: Record<string, string> = {
  'f:name': 'board.f.name',
  'f:passcode': 'board.f.passcode',
  'f:autolock': 'board.f.autolock',
  'f:maxDistance': 'board.f.distance',
  'f:doorRate': 'board.f.rate',
};

function fieldWord(field: string, t: T): string {
  if (FIELD_WORD[field]) return t(FIELD_WORD[field]);
  if (field.startsWith('g:')) return t('board.f.group');
  if (field.startsWith('i:')) return t('board.f.item');
  if (field.startsWith('r:')) return t('board.f.difficulty');
  return '';
}

/** The fields that live under «خيارات متقدمة» (a fix there opens the fold first) */
export function isAdvanced(field: string): boolean {
  return field === 'f:autolock' || field === 'f:maxDistance' || field === 'f:doorRate'
    || /^r:\d+:(size|speed)$/.test(field) || /^i:\d+:meta$/.test(field);
}

export function readiness(form: Form, names: Names, isNew: boolean, t: T, problems?: Problem[]): Ready {
  const found = problems && problems.length ? problems : validate(form);
  if (found.length) {
    const p = found[0];
    const what = fieldWord(p.field, t);
    return { block: { text: what ? `${what}: ${t(p.key)}` : t(p.key), field: p.field } };
  }
  // the server refuses a job / gang it does not define (unknownName): said before the save
  if (names.groups.length) {
    const i = form.groups.findIndex((g) => g.name.trim() && !groupOf(names, g.name.trim()));
    if (i >= 0) return { block: { text: t('board.ready.unknown_group', form.groups[i].name.trim()), field: `g:${i}:name` } };
  }
  if (names.items.length) {
    const i = form.items.findIndex((it) => it.name.trim() && !itemOf(names, it.name));
    if (i >= 0) return { block: { text: t('board.ready.unknown_item', form.items[i].name.trim()), field: `i:${i}:name` } };
  }
  if (!who(form, names, 'en', t) && !form.lockpick) return { warn: t('board.ready.nobody') };
  if (isNew) return { warn: '' };
  return {};
}
