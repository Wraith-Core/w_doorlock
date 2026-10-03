/* The texts: every one of them comes from Lua (locales/{ar,en}.json through w_lib) - the page
   carries no dictionary of its own. A key Lua has not sent reads as the key itself. */

import { createContext, useContext } from 'react';
import type { Lang, Strings } from './types';

export interface I18n {
  lang: Lang;
  rtl: boolean;
  t: (key: string, ...args: (string | number)[]) => string;
}

/** %s / %d are filled in order, as Lua's locale() does with string.format */
export function translate(strings: Strings, key: string, args: (string | number)[]): string {
  const raw = strings[key] ?? key;
  if (args.length === 0) return raw;
  let i = 0;
  return raw.replace(/%[sd]/g, () => String(args[i++] ?? ''));
}

export const I18nContext = createContext<I18n>({
  lang: 'ar',
  rtl: true,
  t: (key) => key,
});

export const useI18n = () => useContext(I18nContext);

export const cls = (...parts: (string | false | null | undefined)[]) => parts.filter(Boolean).join(' ');

/* Text that comes from the server or the staff (a door's name, a group, an item) may be Arabic on an
   English screen or Latin on an Arabic one. It is isolated (<bdi>) so its punctuation and figures keep
   their own direction, and Arabic is marked (.dl-ar) so the Latin letter-spacing, small caps and
   italics of its box never reach Arabic letters. */
const AR_RE = /[؀-ۿݐ-ݿࡰ-ࣿﭐ-﷿ﹰ-﻿]/;
export function Txt({ s }: { s: string | undefined | null }) {
  if (!s) return null;
  return AR_RE.test(s) ? <bdi lang="ar" className="dl-ar">{s}</bdi> : <bdi>{s}</bdi>;
}
