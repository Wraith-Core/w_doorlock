import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
// Every px in the CSS follows the screen (720p .. 8K, ultrawide by height): ui-scale.cjs.
import uiScale from './ui-scale.cjs';

// Strip crossorigin from the injected tags -- inside RedM's CEF a module request can
// fail in CORS mode over nui://, which shows up as a black screen with no error.
const stripCrossorigin = () => ({
  name: 'strip-crossorigin',
  enforce: 'post' as const,
  transformIndexHtml(html: string) {
    return html.replace(/\s+crossorigin(=("|')?.*?\2)?/g, '');
  },
});

export default defineConfig({
  plugins: [react(), stripCrossorigin()],
  base: './',
  css: { postcss: { plugins: [uiScale()] } },
  // dev only: the mock reads the resource's own locales/*.json one folder up
  server: { fs: { allow: ['..'] } },
  build: {
    outDir: 'build',
    target: ['chrome87', 'edge88', 'firefox78', 'safari14'],
    minify: true,
    cssCodeSplit: false,
    rollupOptions: {
      output: {
        entryFileNames: 'assets/app.js',
        chunkFileNames: 'assets/[name].js',
        assetFileNames: (info) =>
          info.name && info.name.endsWith('.css') ? 'assets/app.css' : 'assets/[name][extname]',
      },
    },
  },
});
