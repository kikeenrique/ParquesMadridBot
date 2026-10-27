# Estado Parques Madrid

Swift CLI bot that monitors the weather-alert status of Madrid's parks, posts every change to Mastodon
(@ParquesMadridBot@mastodon.social) and publishes a static website (https://parques.lemambo.com).
Done and pending work: [ROADMAP.md](ROADMAP.md).

## Build & Run

```bash
swift build
swift run EstadoParques                    # fetch the API, update state files, print the post
swift run EstadoParques --website website  # only regenerate the website's pages (no API call, no post)
```

Set `PRODUCTION=true`, `MASTODON_INSTANCE`, and `MASTODON_ACCESS_TOKEN` to post to Mastodon.

## Tests

```bash
swift test
```

Swift Testing suites in `Tests/EstadoParquesTests/`, one per source file (`@testable import EstadoParques`), with
shared helpers in `Fixtures.swift`. They cover the run sequence (posting, saving, API outages and recovery) with
a fake API and fake Mastodon, Mastodon retries, post formatting and Madrid time, change detection, state and log
files (legacy formats included), API parsing, and the website's hours, dates and history.

- Only the raw network calls are untested. Coverage: `swift test --enable-code-coverage`, then
  `xcrun llvm-cov report` on `.build/debug/EstadoParquesTests.xctest` with `.build/debug/codecov/default.profdata`.
  CI prints the same report (without `Tests/` and `.build/`) in the log and the run summary.
- `busiestPostFits` is a known issue: posts with many mixed schedules exceed Mastodon's 500 characters until
  posts are shortened to fit (ROADMAP item 1).
- Networking types (`HTTPURLResponse`, `URLError`) need `import FoundationNetworking` on Linux, behind
  `#if canImport(FoundationNetworking)`; CI runs the tests on Linux.

## Rules for agents

- **Add or update tests with every behaviour change**, and run `swift test` before committing.
- **Never open, launch or script a web browser** — Google Chrome above all, and not even headless for
  screenshots. Verify generated HTML/CSS by inspecting the output; the maintainer previews pages.
- **Always use the latest major version of every GitHub Action** in `.github/workflows/`. Whenever you add or
  touch a `uses:` line, check the current release first (`gh api repos/<owner>/<action>/releases/latest --jq
  .tag_name`) and pin to its major tag (e.g. `@v5`); bump any other outdated action in the same workflow.
  Never copy a version from memory or from older examples.
- **The same goes for the CI Swift image** (`container: swift:X.Y` in all three jobs): use the latest `X.Y` tag
  on Docker Hub (`library/swift`), and bump the `swiftX.Y` prefix of the cache keys with it, or a binary built by
  the old toolchain is restored against the new runtime.
- **Times shown to people are Madrid local time** (`Europe/Madrid`); CI runs in UTC. State and log
  timestamps stay ISO 8601 UTC.
- **Keep the website JavaScript-free** unless the maintainer asks otherwise.

## Project Structure

- `Sources/EstadoParques/main.swift` — Entry point: `--website` mode, production flag, exit code
- `Sources/EstadoParques/Bot.swift` — One run: fetch, compare, save, post, and announcing an API outage once.
  The API, Mastodon, file paths and clock are injected so tests can replace them
- `Sources/EstadoParques/ChangeDetector.swift` — Which parks changed since the saved state, and their log events
- `Sources/EstadoParques/MadridAPI.swift` — Fetches park data from Madrid City Council ESRI API
- `Sources/EstadoParques/Models.swift` — Codable structs for API response, persisted state and change events
- `Sources/EstadoParques/StateManager.swift` — JSON state persistence + NDJSON statistics
- `Sources/EstadoParques/StatusFormatter.swift` — Emoji mapping and post text formatting
- `Sources/EstadoParques/MastodonPoster.swift` — TootSDK wrapper for posting to Mastodon (retries transient
  failures; publishing and waiting injectable for tests)
- `Sources/EstadoParques/WebsiteGenerator.swift` — Rebuilds per-day history from the change log and writes the
  static site
- `website/` — Static site published to GitHub Pages:
  - `index.html` (this month) and `historico/<year>-<1|2>.html` (earlier days, one page per half-year:
    January–June, July–December) — generated, and committed by CI alongside the state files. Closed half-years
    never change; the open one changes once a month. Each timeline ends in links to the neighbouring pages
  - `style.css`, `manifest.webmanifest`, icons, `parques.webp` (header banner) — hand-made
  - `parks/*.webp` — one picture per park for the status cards: the whole illustrated circle, cut flat above
    its name label, transparent around it (WebP with alpha)
  - Zero JavaScript: an "Ahora" section of status cards (home page only), then a timeline with one radio button
    per day. Day panels follow the timeline in the page flow, and each page's `<style>` has one rule per day
    (`body:has(#d-…:checked) #p-…`) that shows the checked day's panel, so the footer appears once. Installable
    as a Home Screen web app
- `resources/` — Source images: `parques madrid grande.png` (banner), `ParquesMadridBot.png` (app icons),
  `ParquesMadridBot_avatar.png` (Mastodon avatar), and `parks/<slug>.png`: one AI-generated illustration per
  park, named like its `website/parks/` picture, licensed CC BY-SA 4.0 (`parks/LICENSE.md`)

## Key Dependencies

- [TootSDK](https://github.com/TootSDK/TootSDK) — Mastodon API client

## State Files

- `estado_parques.json` — Current park state (`[String: ParkState]`: alert code, schedule, and the date the
  schedule refers to), committed to repo. A change in code or schedule triggers a post; the date changes daily,
  so it is saved but never posted. The legacy `[String: Int]` format is still read
- `estadisticas_parques.ndjson` — Append-only change log: one event per park whose level or schedule changed
  (`from_horario`/`to_horario` only on events logged since schedules were tracked, 2026-10-18)
- `estado_api.json` — Whether the city API is down, so the outage is posted only once

## GitHub Actions

`.github/workflows/check-parks.yml` runs every 30 minutes (and on push) in the `swift` container:

0. **test** — on push and manual runs only: `swift test` with code coverage (own debug build cache), then the
   coverage report in the log and the run summary. The other jobs wait for it
   and don't run if it fails; on a schedule it is skipped and they run without it.
1. **check** — builds (binary and SPM caches), runs the park check, regenerates the website, and commits state
   and the website's pages back to the repo. If the site's content hash has no deploy marker in the cache, it
   uploads the Pages artifact. The page changes at least once a day (a new timeline day), so it deploys then.
2. **deploy** — publishes to GitHub Pages (Settings → Pages → Source: GitHub Actions; custom domain
   `parques.lemambo.com`) and only then saves the deploy marker, so a failed deploy is retried next run.

## AI Agents

This project was developed with the assistance of AI coding agents.

### Claude Code (Anthropic)

- **Tool**: [Claude Code CLI](https://claude.com/claude-code)
- **Role**: Code generation, architecture design, and implementation of the Swift CLI bot, the website,
  the GitHub Actions workflow, the test suite, and project documentation.

All AI-generated code was reviewed and approved by a human maintainer.
