# Estado Parques Madrid

Swift CLI bot that monitors the weather-alert status of Madrid's parks, posts every change to Mastodon
(@ParquesMadridBot@mastodon.social) and publishes a static website (https://parques.lemambo.com).

## Build & Run

```bash
swift build
swift run EstadoParques                    # fetch the API, update state files, print the post
swift run EstadoParques --website website  # only regenerate website/index.html (no API call, no post)
```

Set `PRODUCTION=true`, `MASTODON_INSTANCE`, and `MASTODON_ACCESS_TOKEN` to post to Mastodon.

## Tests

```bash
swift test
```

Swift Testing suites in `Tests/EstadoParquesTests/`, one per source file (`@testable import EstadoParques`).
They cover the run sequence (posting, saving, API outages and recovery) with a fake API and fake Mastodon,
Mastodon retries, post formatting and Madrid time, change detection, state and log files (legacy formats
included), API parsing, and the website's hours, dates and history. Only the raw network calls are untested
(`swift test --enable-code-coverage`, then `xcrun llvm-cov report` on the test bundle). `busiestPostFits` is a known issue: posts with many
mixed schedules exceed Mastodon's 500 characters until posts are shortened to fit.

## Rules for agents

- **Add or update tests with every behaviour change**, and run `swift test` before committing.

- **Never open, launch or script a web browser** — Google Chrome above all, and not even headless for
  screenshots. Verify generated HTML/CSS by inspecting the output; the maintainer previews pages.
- **Always use the latest major version of every GitHub Action** in `.github/workflows/`. Whenever you add or
  touch a `uses:` line, check the current release first (`gh api repos/<owner>/<action>/releases/latest --jq
  .tag_name`) and pin to its major tag (e.g. `@v5`); bump any other outdated action in the same workflow.
  Never copy a version from memory or from older examples.
- **The same goes for the CI Swift image** (`container: swift:X.Y` in both jobs): use the latest `X.Y` tag on
  Docker Hub (`library/swift`), and bump the `swiftX.Y` prefix of the binary/SPM cache keys with it, or a
  binary built by the old toolchain is restored against the new runtime.
- **Times shown to people are Madrid local time** (`Europe/Madrid`); CI runs in UTC. State and log
  timestamps stay ISO 8601 UTC.

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
  failures)
- `Sources/EstadoParques/WebsiteGenerator.swift` — Rebuilds per-day history from the change log and writes the
  static site
- `website/` — Static site published to GitHub Pages:
  - `index.html` — generated, and committed by CI alongside the state files
  - `style.css`, `manifest.webmanifest`, icons, `parques.webp` — hand-made
  - Zero JavaScript: an "Ahora" section of status cards, then a timeline with one radio button per day; a single
    CSS rule (`input:checked + label + .day`) shows the selected day. Installable as a Home Screen web app
- `resources/` — Source images: `parques madrid grande.png` (banner), `ParquesMadridBot.png` (app icons),
  `ParquesMadridBot_avatar.png` (Mastodon avatar)

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

0. **test** — on push and manual runs only: `swift test` (own debug build cache). The other jobs wait for it
   and don't run if it fails; on a schedule it is skipped and they run without it.
1. **check** — builds (binary and SPM caches), runs the park check, regenerates the website, and commits state
   and `website/index.html` back to the repo. If the site's content hash has no deploy marker in the cache, it
   uploads the Pages artifact.
2. **deploy** — publishes to GitHub Pages (Settings → Pages → Source: GitHub Actions; custom domain
   `parques.lemambo.com`) and only then saves the deploy marker, so a failed deploy is retried next run.

## AI Agents

This project was developed with the assistance of AI coding agents.

### Claude Code (Anthropic)

- **Tool**: [Claude Code CLI](https://claude.com/claude-code)
- **Role**: Code generation, architecture design, and implementation of the Swift CLI bot, the website,
  the GitHub Actions workflow, and project documentation.

All AI-generated code was reviewed and approved by a human maintainer.
