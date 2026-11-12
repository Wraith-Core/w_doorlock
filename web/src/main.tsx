import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './door.css';
import './notebook.css';

/* * The fonts and the textures are injected from here and not from CSS: their path must be relative
   to the build page (nui://w_doorlock/web/build/) and Vite writes absolute CSS paths that break under
   nui://. In development the root is the dev server and the public/ folder is served from it.

   The faces and the two paper textures are w_pausemenu's own (licences next to the files in
   public/fonts, CREDITS.md):
     EB Garamond   Latin text, titles and figures (SIL OFL 1.1)
     Amiri         Arabic text (SIL OFL 1.1)
     Lalezar       Arabic titles (SIL OFL 1.1)
     Tajawal       Arabic small labels
     RDR Lino      the board's name in the masthead
   The selection band is the game's own art, as w_lib's theme ships it (nui/theme/tex). */
try {
  const base = new URL('./', window.location.href).href;
  const FONTS = `${base}fonts/`;
  const AR = 'U+0600-06FF,U+0750-077F,U+0870-088E,U+0890-0891,U+0897-08E1,U+08E3-08FF,U+FB50-FDFF,U+FE70-FE74,U+FE76-FEFC,U+200C-200E,U+2010-2011,U+0660-0669';

  // one Arabic face server-wide (owner, 2026-10-22): the Arabic faces of the role names (Amiri, Tajawal,
  // Noto Sans Arabic, Aref Ruqaa) draw Lalezar's file at their own weights, so every stack keeps working.
  const style = document.createElement('style');
  style.textContent = `
    @font-face { font-family: "EB Garamond"; font-style: normal; font-weight: 400 800; src: url("${FONTS}EBGaramond-latin.woff2") format("woff2"); font-display: swap; }
    @font-face { font-family: "EB Garamond"; font-style: italic; font-weight: 400 800; src: url("${FONTS}EBGaramond-Italic-latin.woff2") format("woff2"); font-display: swap; }
    @font-face { font-family: "Amiri"; font-weight: 400; src: url("${FONTS}Lalezar-400-arabic.woff2") format("woff2"); unicode-range: ${AR}; font-display: swap; }
    @font-face { font-family: "Amiri"; font-weight: 700; src: url("${FONTS}Lalezar-400-arabic.woff2") format("woff2"); unicode-range: ${AR}; font-display: swap; }
    @font-face { font-family: "Lalezar"; font-weight: 400; src: url("${FONTS}Lalezar-400-arabic.woff2") format("woff2"); unicode-range: ${AR}; font-display: swap; }
    @font-face { font-family: "RDR Lino"; src: url("${FONTS}RDRLino-Regular.woff2") format("woff2"); font-display: swap; }
    @font-face { font-family: "Noto Sans Arabic"; src: url("${FONTS}Lalezar-400-arabic.woff2") format("woff2"); font-weight: 100 900; font-display: swap; }
    @font-face { font-family: "Tajawal"; font-weight: 400; src: url("${FONTS}Lalezar-400-arabic.woff2") format("woff2"); unicode-range: ${AR}; font-display: swap; }
    @font-face { font-family: "Tajawal"; font-weight: 700; src: url("${FONTS}Lalezar-400-arabic.woff2") format("woff2"); unicode-range: ${AR}; font-display: swap; }
  `;
  document.head.appendChild(style);

  const root = document.documentElement.style;
  root.setProperty('--tex-tear', `url("${base}tex/tear.png")`);
  root.setProperty('--tex-grain', `url("${base}tex/grain.png")`);
  root.setProperty('--tex-band', `url("${base}tex/band.png")`);
  root.setProperty('--tex-band-sm', `url("${base}tex/band-sm.png")`);
} catch {
  /* The fallback font is enough - the board is not dropped for the sake of a font */
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode><App /></React.StrictMode>
);
