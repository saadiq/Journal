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
