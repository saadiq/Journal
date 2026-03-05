# journal-dark

Custom Ghost theme for the newsletter at `https://saadiq.xyz/newsletter`.

## Architecture

This theme runs on a **Ghost** instance on a shared Digital Ocean droplet (`167.71.169.225`) alongside the main Astro static site.

### How the server is laid out

- **Droplet**: `167.71.169.225` (root access via ssh)
- **Ghost install**: `/var/www/ghost/`
- **Ghost config**: `/var/www/ghost/config.production.json`
- **Theme on server**: `/var/www/ghost/content/themes/journal-dark/`
- **Static site files**: `/var/www/saadiq.xyz/` (separate Astro repo)
- **Ghost URL**: `https://saadiq.xyz/newsletter`
- **Ghost admin**: `https://saadiq.xyz/newsletter/ghost/`

### Routing (nginx at `/etc/nginx/sites-enabled/saadiq.xyz.conf`)

- `/newsletter/*` — proxied to Ghost on `127.0.0.1:2368`
- `/content`, `/members` — rewritten and proxied to Ghost
- Everything else — served from the Astro static site

## Related repo

- **Astro site** (`saadiq.xyz`): `~/dev/saadiq.xyz`
- Both repos share a color system — keep `text-muted`, `accent`, `bg`, etc. in sync when changing colors

## Color tokens (in `assets/css/dark-theme.css`)

| Token / Variable | Value | Notes |
|---|---|---|
| `--color-white` (bg) | `#0c0c0c` | Inverted for dark mode |
| `--color-lighter-gray` | `#141414` | Surface color |
| `--color-mid-gray` | `#ac9e90` | Muted text (AAA contrast) |
| `--color-dark-gray` | `#c0b9ad` | Secondary content text |
| `--color-darker-gray` / `--color-black` | `#f0ece4` | Primary text |
| `--color-secondary-text` | `#ac9e90` | Same as mid-gray |
| `--ghost-accent-color` | `#d4a843` | Gold accent |

## Deploy

```bash
# 1. Build the zip
bun run zip

# 2. Copy changed CSS files to server and restart Ghost
scp assets/css/dark-theme.css root@167.71.169.225:/var/www/ghost/content/themes/journal-dark/assets/css/dark-theme.css
scp assets/built/screen.css root@167.71.169.225:/var/www/ghost/content/themes/journal-dark/assets/built/screen.css
ssh root@167.71.169.225 "cd /var/www/ghost && ghost restart"
```

For full theme uploads, use the Ghost admin UI at `/newsletter/ghost/#/settings/design` and upload `dist/journal-dark.zip`.

## Commands

- `bun run dev` — local dev with livereload (gulp)
- `bun run zip` — build theme zip to `dist/journal-dark.zip`
- `bun run test` — validate theme with gscan
