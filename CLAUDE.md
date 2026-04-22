# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Journal is a Ghost CMS theme — a minimal, typography-focused newsletter/blog theme. Requires Ghost >= 5.0.0.

## Commands

- `bun install` — install dependencies
- `bun run dev` — build CSS/JS, start watchers with livereload
- `bun run test` — validate theme with gscan (Ghost theme linter)
- `bun run zip` — build and package theme into `dist/journal.zip` for upload to Ghost

## Build System

Gulp 5 with two pipelines:

- **CSS:** `assets/css/screen.css` → PostCSS (easyimport, autoprefixer, cssnano) → `assets/built/screen.css`
- **JS:** Shared Ghost assets (`@tryghost/shared-theme-assets`) + `assets/js/lib/*.js` + `assets/js/main.js` → concat + uglify → `assets/built/main.min.js`

Both generate source maps. The `assets/built/` directory contains compiled output — edit source files, not built files.

## Architecture

**Handlebars templates** — Ghost uses Handlebars with custom helpers (`{{ghost_head}}`, `{{#foreach}}`, `{{content}}`, etc.):

- `default.hbs` — base layout wrapping all pages (head, header, footer, Ghost portal/search)
- `index.hbs` — homepage: featured post + post grid with sidebar (about, featured, topics, recommendations)
- `post.hbs` / `page.hbs` — single post and static page templates
- `author.hbs` / `tag.hbs` — archive pages
- `partials/` — reusable components (loop cards, feature images, content CTA, PhotoSwipe lightbox)
- `partials/icons/` — SVG icon partials for social platforms

**CSS** — single entry point `assets/css/screen.css` using PostCSS imports and `@import "fonts.css"`. Uses CSS custom properties for theming (`--font-sans: Inter`, `--font-serif: Lora`, `--ghost-accent-color`). Layout is CSS Grid with named areas.

**JS** — minimal; `assets/js/main.js` is 3 lines calling `pagination()` from shared Ghost assets.

## Theme Customization

Three custom settings in `package.json` under `config.custom`, configurable via Ghost Admin:

- `navigation_layout` — "Logo on the left", "Logo in the middle", "Stacked" (default)
- `title_font` / `body_font` — "Modern sans-serif" (Inter) or "Elegant serif" (Lora)

These are consumed in `default.hbs` via `{{@custom.navigation_layout}}` to toggle CSS classes.

## Upstream

This repo is a fork of `TryGhost/Journal`. Stay close to upstream — merge, don't cherry-pick.

- `origin/main` tracks `upstream/main` (sync via GitHub "Sync fork" button or `git fetch upstream && git merge upstream/main` on `main`)
- `origin/dark-theme` is the deployed branch with dark-theme customizations
- To pull upstream changes: `git checkout dark-theme && git merge origin/main`
- Expect conflicts only in `assets/built/screen.css{,.map}` — resolve with `git checkout --theirs`, then `bunx gulp build` to regenerate from merged source

## Deploy

Theme is deployed to `/var/www/ghost/content/themes/journal-dark` on the shared droplet (`167.71.169.225`). The directory is **not a git repo on the server** — deploys are file sync.

### Permissions gotcha

The theme dir is owned by `ghost:ghost` (mode 775/664). The `saadiq` user is **not** in the `ghost` group, so a plain rsync fails silently (writes partial, then errors with `unexpected end of file`). Always use `--rsync-path='sudo rsync'` and chown after.

### Deploy steps

From `~/dev/journal` on `dark-theme` branch, with a clean working tree and fresh `bunx gulp build`:

```bash
# 1. Push
git push origin dark-theme

# 2. Sync files (macOS rsync lacks --chown, so chown separately)
rsync -av --partial --rsync-path='sudo rsync' \
  --exclude=node_modules --exclude=dist --exclude=.git \
  --exclude=.DS_Store --exclude=.superpowers --exclude=.claude \
  --exclude=CLAUDE.md --exclude=.gitignore --exclude=yarn-error.log \
  ~/dev/journal/ saadiq@167.71.169.225:/var/www/ghost/content/themes/journal-dark/

# 3. Fix ownership (rsync ran as root)
ssh saadiq@167.71.169.225 "sudo chown -R ghost:ghost /var/www/ghost/content/themes/journal-dark"

# 4. Restart Ghost to flush theme cache
ssh saadiq@167.71.169.225 "sudo systemctl restart ghost_167-71-169-225.service"

# 5. Smoke test
curl -s -o /dev/null -w 'HTTP %{http_code}\n' https://saadiq.xyz/newsletter/
```

Ghost restart is ~5 seconds of 503s on `/newsletter/`. The main `saadiq.xyz` Astro site is unaffected (served directly by nginx).

### Verify share button / new features

```bash
curl -s https://saadiq.xyz/newsletter/<some-post-slug>/ | grep gh-button-share
```
