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
  coords: { x: i, y: 0, z: 0 },
  state: i % 4 === 3 ? 0 : 1,
  maxDistance: 2,
  groups: { police: 0 },
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
  else send({ action: 'dl:board', doors, sounds: ['door-bolt-4', 'button-remote', 'metal-locker', 'metallic-creak'], defaultSound: 'door-bolt-4', stores });
}, 200);
