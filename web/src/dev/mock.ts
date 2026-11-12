/* ════════════════════════════════════════════════════════════════════════════
 * Development only (dev.html, never in the build): a browser stand-in for Lua, so the page can be
 * worked on with `npm run dev` outside the game.
 *
 *   ?lang=ar|en            the language (Arabic by default)
 *   ?show=board|passcode|pick
 *
 * The texts are the resource's own locales/{ar,en}.json, read from one folder up.
 * ════════════════════════════════════════════════════════════════════════════ */

import ar from '../../../locales/ar.json';
import en from '../../../locales/en.json';

type Json = Record<string, unknown>;

function flatten(obj: Json, prefix = '', out: Record<string, string> = {}) {
  for (const [k, v] of Object.entries(obj)) {
    const key = prefix ? `${prefix}.${k}` : k;
    if (v && typeof v === 'object') flatten(v as Json, key, out);
    else out[key] = String(v);
  }
  return out;
}

const params = new URLSearchParams(window.location.search);
const lang = params.get('lang') === 'en' ? 'en' : 'ar';
const show = params.get('show') ?? 'board';

const doors = Array.from({ length: 14 }, (_, i) => ({
  id: i + 1,
  name: ['valentine_sheriff_front', 'rhodes_sheriff_back', 'saloon_backroom', 'bank_vault'][i % 4] + (i > 3 ? `_${i}` : ''),
  zone: lang === 'ar' ? 'هارتلاندز' : 'The Heartlands',
  // what Lua adds on the way (client/words.lua): the name in words, the place and distance
  label: (lang === 'ar'
    ? ['مكتب الشريف · الباب الأمامي', 'مكتب الشريف · الباب الخلفي', 'الصالون · الغرفة الخلفية', 'البنك · الخزنة']
    : ["Sheriff's office · Front door", "Sheriff's office · Back door", 'Saloon · Back room', 'Bank · Vault'])[i % 4] + (i > 3 ? ` ${i}` : ''),
  where: lang === 'ar' ? `${['فالنتاين', 'رودس', 'فالنتاين', 'سانت دينيس'][i % 4]} · ${8 + i * 23} م منك`
    : `${['Valentine', 'Rhodes', 'Valentine', 'Saint Denis'][i % 4]} · ${8 + i * 23} m from you`,
  meters: 8 + i * 23,
  coords: { x: i, y: 0, z: 0 },
  state: i % 4 === 3 ? 0 : 1,
  maxDistance: 2,
  groups: i === 5 ? { police: 2, pinkerton: 0 } : { police: 0 },
  items: i === 1 ? [{ name: 'prison_key', remove: false }] : undefined,
  lockpick: i === 3 ? true : undefined,
  doors: i === 2 ? [{ coords: { x: 0, y: 0, z: 0 }, hash: 1 }, { coords: { x: 1, y: 0, z: 0 }, hash: 2 }] : undefined,
  // 2.2.0: the first door is a store's, and locks itself after 3 s (the Valentine gunsmith's case)
  store: i === 0 ? 31 : undefined,
  autolock: i === 0 ? 3 : undefined,
}));

// 2.2.0: w_store's stores for the store tab's picker
const stores = [
  { id: 31, name: lang === 'ar' ? 'أسلحة بارنز · فالنتاين' : 'Barnes Guns · Valentine', owner: 'Jack Marston', at: { x: 2, y: 5, z: 0 } },
  { id: 26, name: lang === 'ar' ? 'صالون سميثفيلد · فالنتاين' : 'Smithfield Saloon · Valentine', at: { x: 30, y: 22, z: 0 } },
  { id: 36, name: lang === 'ar' ? 'جزار فالنتاين' : 'Valentine Butcher', at: { x: 60, y: 10, z: 0 } },
];

// the names the board shows instead of keys (w_doorlock:admin:names)
const names = {
  groups: [
    { name: 'police', kind: 'job', en: 'Sheriff', ar: 'الشريف', grades: [
      { grade: 0, en: 'Deputy', ar: 'نائب' }, { grade: 1, en: 'Officer', ar: 'ضابط' }, { grade: 2, en: 'Sergeant', ar: 'رقيب' }, { grade: 3, en: 'Sheriff', ar: 'الشريف' }] },
    { name: 'doctor', kind: 'job', en: 'Doctor', ar: 'الطبيب', grades: [{ grade: 0, en: 'Nurse', ar: 'ممرض' }, { grade: 1, en: 'Doctor', ar: 'طبيب' }] },
    { name: 'odriscoll', kind: 'gang', en: "O'Driscolls", ar: 'أودريسكول', grades: [{ grade: 0, en: 'Member', ar: 'عضو' }] },
  ],
  items: [{ name: 'prison_key', label: lang === 'ar' ? 'مفتاح السجن' : 'Prison key' }, { name: 'lockpick', label: lang === 'ar' ? 'أداة فك الأقفال' : 'Lock pick' }],
};

(window as unknown as { __dlMock: unknown }).__dlMock = {
  callback: (name: string, data: unknown) => {
    console.log('[nui]', name, data);
    if (name === 'dl:board:save') return { ok: false, reason: 'db' };
    return { ok: true };
  },
};

const send = (data: unknown) => window.postMessage(data, '*');
window.setTimeout(() => {
  send({ action: 'dl:locale', locale: lang, dir: lang === 'ar' ? 'rtl' : 'ltr', strings: flatten(lang === 'ar' ? ar : en) });
  if (show === 'passcode') send({ action: 'dl:passcode' });
  else if (show === 'pick') send({ action: 'dl:pick', rounds: ['easy', 'medium', { areaSize: 30, speedMultiplier: 1.4 }] });
  else send({
    action: 'dl:board', doors, sounds: ['door-bolt-4', 'button-remote', 'metal-locker', 'metallic-creak'], defaultSound: 'door-bolt-4', stores,
    names, world: true,
    focus: params.get('door') ? Number(params.get('door')) : undefined,
    fresh: params.get('fresh') ? { double: params.get('fresh') === 'double', where: lang === 'ar' ? 'فالنتاين · 3 م منك' : 'Valentine · 3 m from you' } : undefined,
  });
}, 200);
