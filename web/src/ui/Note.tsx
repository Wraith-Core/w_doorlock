/* ════════════════════════════════════════════════════════════════════════════
 * The paper note - the one light sheet: ink on paper, the pause menu's "are you sure?".
 *
 *   ConfirmNote   inside the board: delete this door? (the board drives its keys)
 *   CodeNote      on its own, over the world: the door asks for its code
 * ════════════════════════════════════════════════════════════════════════════ */

import { useEffect, useRef, useState } from 'react';
import { cls, Txt, useI18n } from '../i18n';
import { startPad } from '../nav';
import { cue, post } from '../nui';

interface ConfirmProps {
  question: string;
  sub?: string;
  here: string;
  reg: (id: string) => (el: HTMLElement | null) => void;
  hover: (id: string) => () => void;
  onYes: () => void;
  onNo: () => void;
}

export function ConfirmNote({ question, sub, here, reg, hover, onYes, onNo }: ConfirmProps) {
  const { t } = useI18n();
  return (
    <div className="dl-note" role="dialog" aria-modal="true">
      <div className="dl-note-plate">
        <p className="dl-note-q"><Txt s={question} /></p>
        {sub && <p className="dl-note-sub"><Txt s={sub} /></p>}
        <div className="dl-note-row">
          <button type="button" ref={reg('yes')} className={cls('dl-choice', here === 'yes' && 'is-here')}
            onMouseEnter={hover('yes')} onClick={onYes}>{t('board.yes')}</button>
          <button type="button" ref={reg('no')} className={cls('dl-choice', here === 'no' && 'is-here')}
            onMouseEnter={hover('no')} onClick={onNo}>{t('board.no')}</button>
        </div>
      </div>
    </div>
  );
}

type CodeFocus = 'code' | 'yes' | 'no';

/** The door's code: typed on the note, Enter opens, Escape gives up */
export function CodeNote() {
  const { t, rtl, lang } = useI18n();
  const [code, setCode] = useState('');
  const [here, setHere] = useState<CodeFocus>('code');
  const [empty, setEmpty] = useState(false);
  const input = useRef<HTMLInputElement>(null);
  const done = useRef(false);
  const hereRef = useRef(here);
  hereRef.current = here;
  const codeRef = useRef(code);
  codeRef.current = code;

  const finish = (value: string | null) => {
    if (done.current) return;
    done.current = true;
    cue(value === null ? 'back' : 'select');
    void post('dl:passcode', { code: value ?? '' });
  };

  const submit = () => {
    const value = codeRef.current.trim();
    if (value === '') {
      setEmpty(true);
      cue('locked');
      input.current?.focus();
      setHere('code');
      return;
    }
    finish(value);
  };

  const go = (to: CodeFocus) => {
    if (to === hereRef.current) return;
    setHere(to);
    cue('navDown');
    if (to === 'code') input.current?.focus();
    else input.current?.blur();
  };

  useEffect(() => {
    const timer = window.setTimeout(() => input.current?.focus(), 60);
    const onKey = (e: KeyboardEvent) => {
      const at = hereRef.current;
      switch (e.key) {
        case 'Escape': case 'Backspace':
          if (e.key === 'Backspace' && at === 'code') return;   // a character to delete, not a way out
          finish(null);
          break;
        case 'Enter':
          if (at === 'no') finish(null); else submit();
          break;
        case 'ArrowDown': if (at === 'code') go('yes'); else return; break;
        case 'ArrowUp': if (at !== 'code') go('code'); else return; break;
        case 'ArrowLeft': case 'ArrowRight':
          if (at === 'code') return;
          go(at === 'yes' ? 'no' : 'yes');
          break;
        default: return;
      }
      e.preventDefault();
    };
    window.addEventListener('keydown', onKey);
    const stopPad = startPad((a) => {
      if (a === 'back') finish(null);
      else if (a === 'select') { if (hereRef.current === 'no') finish(null); else submit(); }
      else if (a === 'down' && hereRef.current === 'code') go('yes');
      else if (a === 'up') go('code');
      else if ((a === 'left' || a === 'right') && hereRef.current !== 'code') go(hereRef.current === 'yes' ? 'no' : 'yes');
    });
    return () => { window.clearTimeout(timer); window.removeEventListener('keydown', onKey); stopPad(); };
  }, []);

  return (
    <div className={cls('dl-note is-alone', rtl && 'is-rtl')} dir={rtl ? 'rtl' : 'ltr'} lang={lang} role="dialog" aria-modal="true">
      <div className="dl-note-plate">
        <p className="dl-note-kicker">{t('note.kicker')}</p>
        <p className="dl-note-q">{t('note.question')}</p>
        <input
          ref={input}
          className={cls('dl-code', empty && 'is-invalid')}
          type="password"
          maxLength={32}
          value={code}
          autoComplete="off"
          spellCheck={false}
          onFocus={() => setHere('code')}
          onChange={(e) => { setCode(e.target.value); setEmpty(false); }}
        />
        <div className="dl-note-row">
          <button type="button" className={cls('dl-choice', here === 'yes' && 'is-here')}
            onMouseEnter={() => go('yes')} onClick={submit}>{t('note.open')}</button>
          <button type="button" className={cls('dl-choice', here === 'no' && 'is-here')}
            onMouseEnter={() => go('no')} onClick={() => finish(null)}>{t('note.cancel')}</button>
        </div>
      </div>
    </div>
  );
}
