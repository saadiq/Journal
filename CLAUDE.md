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

Three custom settings in `package.json` under `config.custom`, consumed in `default.hbs` to toggle CSS classes:

- `navigation_layout` — "Logo on the left", "Logo in the middle", "Stacked" (default)
- `body_font` — "Modern sans-serif" (Inter) or "Elegant serif" (Instrument Serif)
- `newsletter_name` — free text

### Ghost 6 overrides theme font settings

**Don't add a `title_font` custom setting back.** Ghost 6 ships its own Typography picker (Settings → Design & branding → Customize) that *supersedes* a theme's `title_font`/`body_font` custom settings — they stop rendering in admin and sit stuck on their declared default, silently. There was a `title_font` select here; it went unreachable that way, which is why the theme's tuned serif-title mode appeared dead.

Ghost's picker offers 21 faces (`@tryghost/custom-fonts`: Cardo, Chakra Petch, Old Standard TT, Libre Baskerville, Rufina, Space Grotesk, Tenor Sans, plus the body list). **Instrument Serif is not one of them**, so the display face can only be set in the theme. `has-serif-title` is therefore hardcoded on `<body>` — see the comment there. That class drives 10 rules that swap `var(--font-serif)` in at weight 400 with per-context letter-spacing.

Keeping it matters: Instrument Serif is the display face on saadiq.xyz, and matching it is what makes `/newsletter` read as the same brand. See the "Related repo" section of `~/dev/saadiq.xyz/CLAUDE.md` for what the two properties do and don't share.

If you remove a custom setting, also delete it from `package.json` — gscan errors on a setting declared but unused.

## Upstream

This repo is a fork of `TryGhost/Journal`. Stay close to upstream — merge, don't cherry-pick.

- `origin/main` tracks `upstream/main` (sync via GitHub "Sync fork" button or `git fetch upstream && git merge upstream/main` on `main`)
- `origin/dark-theme` is the deployed branch with dark-theme customizations
- To pull upstream changes: `git checkout dark-theme && git merge origin/main`
- Expect conflicts only in `assets/built/screen.css{,.map}` — resolve with `git checkout --theirs`, then `bunx gulp build` to regenerate from merged source

## Local preview

`bun run dev` only watches/builds CSS + JS — it does not render templates. To see the theme with real Ghost rendering (post bodies, bylines, feature images, the hamburger overlay), run a local Ghost in Docker via `scripts/preview-ghost.sh`:

```bash
./scripts/preview-ghost.sh up             # start/restart at http://localhost:2368
./scripts/preview-ghost.sh sync-theme     # re-stage after editing + bun run build
./scripts/preview-ghost.sh sync-images    # pull prod content/images/ down (~476MB, one-time)
./scripts/preview-ghost.sh down           # stop container (DB/images/theme stay on disk)
./scripts/preview-ghost.sh reset          # nuke container + local DB
```

First `up` seeds an admin (`preview@example.com` / `PreviewPass1234`) and activates the `journal-field-notes` theme via Ghost's admin API. The device-verification gate is disabled so login works without SMTP. Content (SQLite DB), images, and the staged theme all live under `/tmp/journal-*` bind-mounts so container recreation preserves them.

**Gotchas:**

- **Never bind-mount the repo dir directly.** Ghost's entrypoint `chown -R`s the theme path at startup; our `.git/` objects (owned by the host user) make it exit 1. The script rsyncs into `/tmp/journal-theme-preview` first, excluding `.git`, `node_modules`, `dist`, and the agent dotdirs.
- **Ghost's default SQLite path is version-scoped** (`versions/5.x.x/content/data/ghost-dev.db`), not `content/data/ghost.db` under the configured `contentPath`. The script sets `database__connection__filename` explicitly so the DB lands in the bind-mounted dir and survives `docker rm -f`.
- **Content imports require a separate step.** Prod uses MySQL and posts contain member PII, so the script doesn't pull the DB. If you need prod posts in the preview, use Ghost Admin → Settings → Labs → Import content with a JSON export you've vetted locally.
- **After editing templates or running `bunx gulp build`**, run `sync-theme` (or just `up` again). Handlebars partials are re-read per request but the staged mount only reflects what's been rsync'd.

## Deploy

Theme is deployed to `/var/www/ghost/content/themes/journal-field-notes` on the shared droplet (`167.71.169.225`). The directory is **not a git repo on the server** — deploys are file sync. The active theme in Ghost Admin is `journal-field-notes` (`package.json` name, v2.0.0+). The old `journal-dark` directory may still exist on disk as a fallback — leave it unless explicitly asked to remove it.

### Permissions gotcha

The theme dir is owned by `ghost:ghost` (mode 775/664). The `saadiq` user is **not** in the `ghost` group, so a plain rsync fails silently (writes partial, then errors with `unexpected end of file`). Always use `--rsync-path='sudo rsync'` and chown after.

### Deploy steps

From `~/dev/journal` on `field-notes` branch, with a clean working tree and fresh `bunx gulp build`:

```bash
# 1. Push
git push origin field-notes

# 2. Sync files (macOS rsync lacks --chown, so chown separately)
rsync -av --partial --rsync-path='sudo rsync' \
  --exclude=node_modules --exclude=dist --exclude=.git \
  --exclude=.DS_Store --exclude=.superpowers --exclude=.claude \
  --exclude=CLAUDE.md --exclude=.gitignore --exclude=yarn-error.log \
  --exclude=scripts \
  ~/dev/journal/ saadiq@167.71.169.225:/var/www/ghost/content/themes/journal-field-notes/

# 3. Fix ownership (rsync ran as root)
ssh saadiq@167.71.169.225 "sudo chown -R ghost:ghost /var/www/ghost/content/themes/journal-field-notes"

# 4. Restart Ghost to flush theme cache
ssh saadiq@167.71.169.225 "sudo systemctl restart ghost_167-71-169-225.service"

# 5. Smoke test (wait ~8s after restart before probing — /newsletter/ returns 503 during boot)
curl -s -o /dev/null -w 'HTTP %{http_code}\n' https://saadiq.xyz/newsletter/
```

Ghost restart is ~8 seconds of 503s on `/newsletter/`. The main `saadiq.xyz` Astro site is unaffected (served directly by nginx).

### Verify share button / new features

```bash
curl -s https://saadiq.xyz/newsletter/<some-post-slug>/ | grep gh-button-share
```
