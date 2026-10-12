/* ════════════════════════════════════════════════════════════════════════════
 * w_doorlock · App.tsx - one page, three surfaces, one at a time:
 *
 *   board      the staff's board of doors (/doorlock)                     board/Board.tsx
 *   passcode   the paper note that asks for a door's code                 ui/Note.tsx
 *   pick       the lock pick's skill check                                ui/Pick.tsx
 *
 * and, open or closed, the door sounds heard in the world (dl:door-sound). Every text comes from
 * Lua (locales/{ar,en}.json through w_lib); the page carries no dictionary of its own.
 * ════════════════════════════════════════════════════════════════════════════ */

import { useCallback, useEffect, useMemo, useState } from 'react';
import Board from './board/Board';
import { I18nContext, translate, type I18n } from './i18n';
import { post } from './nui';
import type { BoardOpen, BoardResume, Door, Lang, PickRound, Strings } from './types';
import { CodeNote } from './ui/Note';
import Pick from './ui/Pick';

type Surface = 'board' | 'passcode' | 'pick';

export default function App() {
  const [lang, setLang] = useState<Lang>('ar');
  const [rtl, setRtl] = useState(true);
  const [strings, setStrings] = useState<Strings>({});
  const [surface, setSurface] = useState<Surface | null>(null);
  const [board, setBoard] = useState<BoardOpen | null>(null);
  const [resume, setResume] = useState<BoardResume | null>(null);
  const [rounds, setRounds] = useState<PickRound[]>([]);
  const [round, setRoundKey] = useState(0);

  const applyLocale = useCallback((l: Lang, isRtl: boolean) => {
    setLang(l);
    setRtl(isRtl);
    document.documentElement.lang = l;
    document.documentElement.dir = isRtl ? 'rtl' : 'ltr';
  }, []);

  useEffect(() => {
    const onMsg = (e: MessageEvent) => {
      const d = (e.data || {}) as Record<string, unknown>;
      switch (d.action) {
        case 'dl:locale': {
          const l: Lang = d.locale === 'ar' ? 'ar' : 'en';
          applyLocale(l, typeof d.dir === 'string' ? d.dir === 'rtl' : l === 'ar');
          if (d.strings && typeof d.strings === 'object') setStrings(d.strings as Strings);
          return;
        }
        case 'dl:board':
          setBoard((prev) => ({
            n: (prev?.n ?? 0) + 1,
            doors: Array.isArray(d.doors) ? (d.doors as Door[]) : [],
            sounds: Array.isArray(d.sounds) ? (d.sounds as string[]) : [],
            defaultSound: typeof d.defaultSound === 'string' ? d.defaultSound : '',
            focus: typeof d.focus === 'number' ? d.focus : undefined,
          }));
          setSurface('board');
          return;
        case 'dl:board:resume':
          setResume((prev) => ({ n: (prev?.n ?? 0) + 1, saved: d.saved && typeof d.saved === 'object' ? (d.saved as Door) : undefined }));
          setSurface('board');
          return;
        case 'dl:passcode':
          setSurface('passcode');
          return;
        case 'dl:pick':
          setRounds(Array.isArray(d.rounds) ? (d.rounds as PickRound[]) : []);
          setRoundKey((n) => n + 1);
          setSurface('pick');
          return;
        case 'dl:close':
          setSurface((now) => (now === d.surface ? null : now));
          return;
        case 'dl:door-sound': {
          if (typeof d.sound !== 'string' || d.sound === '') return;
          try {
            const audio = new Audio(`./sounds/${d.sound}.ogg`);
            audio.volume = Math.max(0, Math.min(1, Number(d.volume) || 0));
            void audio.play();
          } catch {
            /* a missing file is silent */
          }
          return;
        }
        default:
      }
    };
    window.addEventListener('message', onMsg);
    void post('dl:ready');
    return () => window.removeEventListener('message', onMsg);
  }, [applyLocale]);

  const i18n = useMemo<I18n>(() => ({
    lang,
    rtl,
    t: (key, ...args) => translate(strings, key, args),
  }), [lang, rtl, strings]);

  return (
    <I18nContext.Provider value={i18n}>
      {board && <Board open={surface === 'board'} message={board} resume={resume} />}
      {surface === 'passcode' && <CodeNote />}
      {surface === 'pick' && <Pick key={round} rounds={rounds} />}
    </I18nContext.Provider>
  );
}
