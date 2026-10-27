# Roadmap

What has been done and what is still open. Pending items are in recommended order.

## Done

### Bot and Mastodon posts

- Posts when a park's alert **hours** change, not only its level (e.g. orange 21:00–24:00 → orange 00:00–18:00).
- Hours shown for every alert level, yellow included.
- Times in **Madrid local time** (CI runs in UTC).
- Only a leading "Parque " is dropped from names ("Rosaleda del Parque del Oeste" stays whole).
- Every post ends with a link to the website.
- The city API's schedule date (`FECHA_INCIDENCIA`) is saved silently: it moves every day, so it never posts.
- City API outages are announced once, and the current state is posted when the service recovers.
- Transient Mastodon failures (rate limits, server and network errors) are retried after 5 s and 15 s.

### Change history

- Change log events carry the hours before and after (`from_horario` / `to_horario`, since 2026-10-18).
- Schedule-only changes are logged too, so past days can show their hours.
- Old state and log formats still load.

### Website — [parques.lemambo.com](https://parques.lemambo.com)

- Static site on GitHub Pages with the custom domain and HTTPS; **no JavaScript**, no cookies.
- **Ahora**: last-change note, summary chips, and one card per park, two per row (one on phones), with the park's
  picture, status, name and dated hours (e.g. "Dom 18, 18:00 – lun 19, 09:00").
- A picture for each of the nine parks; eight are sharp 450 px cuts of one AI-generated illustration per park
  (`resources/parks/`, CC BY-SA 4.0, credited once under the cards).
- **Registro histórico**: a timeline with one column per day since March 2026; choosing a day shows that day's
  status, hours and changes. Past days show the hours recorded in the change log (confirmed with real data on
  18 October).
- **Pages that stay small**: the home page shows this month; earlier days live in one page per half-year
  (`historico/2026-1.html`, `2026-2.html`, …), linked from the ends of each timeline. The footer appears once per
  page instead of once per day: the home page went from 443 KB to 32 KB (4 KB compressed).
- Footer with the Mastodon and "Instalar como app" buttons, data and code credits, and a no-cookies note.
- Light and dark mode, following the device.
- Installable as a web app (iPhone, iPad, Mac, Android): manifest, icons, safe areas for the notch and home
  indicator, wider timeline columns on touch screens.
- Mastodon profile link verified (`rel="me"`).

### CI and quality

- GitHub Actions on the latest action versions and the `swift:6.4` image, with build caches keyed by toolchain.
- Pages deploys only when the page changes (about once a day otherwise), and a failed deploy is retried.
- **61 Swift Testing tests, 90% line coverage**; only the raw network calls are untested. CI prints the coverage
  report in each test run and its summary.
- Tests run on every push before the bot and the deploy; scheduled runs skip them and still deploy when the page
  changes (confirmed on 19 October).
- Project documentation: README, AGENTS.md and this roadmap.

## Pending

### 1. Posts that fit Mastodon's 500 characters

A day with several alert levels, each with different hours, makes a post over 500 characters, which Mastodon
rejects (the run then fails). The `busiestPostFits` test records it as a known issue. Fix: count the post as
Mastodon does and shorten it when needed (e.g. a shorter header line). Once that guard exists, posts can also show
dates with the hours, like the website cards.

### 2. Lineal del Manzanares picture

The only park still on the old ~300 px picture from the shared illustration. It needs its own illustration like
the others in `resources/parks/` (its landmark: the Dama del Manzanares); then cut it the same way (whole circle, transparent around it, flat at 86%,
450 px).

### 3. Header illustration

The banner (`website/parques.webp`) is the first illustration: several of its scenes match no park. It needs a new
illustration; nothing to do in code until one exists.

### 4. App icon

The Home Screen icon is a round scene on a white square, which stands out in dark mode. It needs a designed
icon, ideally at 512 px or more; nothing to do in code until one exists.

### Optional ideas

- **Map** of the parks and districts, as a precomputed SVG, keeping the site JavaScript-free.
- **Refresh while open**: the installed web app only updates when reopened; reloading on return would need a
  little JavaScript.
- **Theme switch** inside the page (it follows the device today); remembering the choice needs JavaScript.
