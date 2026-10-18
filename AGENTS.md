# Estado Parques Madrid

Swift CLI bot that monitors Madrid park alert status and posts to Mastodon.

## Build & Run

```bash
swift build
swift run EstadoParques
```

Set `PRODUCTION=true`, `MASTODON_INSTANCE`, and `MASTODON_ACCESS_TOKEN` to post to Mastodon.

`swift run EstadoParques --website website` only regenerates `website/index.html` from the state and history
files (no API call, no post).

## Rules for agents

- **Never open, launch or script a web browser** — Google Chrome above all, and not even headless for
  screenshots. Verify generated HTML/CSS by inspecting the output; the maintainer previews pages.
- **Always use the latest major version of every GitHub Action** in `.github/workflows/`. Whenever you add or
  touch a `uses:` line, check the current release first (`gh api repos/<owner>/<action>/releases/latest --jq
  .tag_name`) and pin to its major tag (e.g. `@v5`); bump any other outdated action in the same workflow.
  Never copy a version from memory or from older examples.
- **The same goes for the CI Swift image** (`container: swift:X.Y` in both jobs): use the latest `X.Y` tag on
  Docker Hub (`library/swift`), and bump the `swiftX.Y` prefix of the binary/SPM cache keys with it, or a
  binary built by the old toolchain is restored against the new runtime.

## Project Structure

- `Sources/EstadoParques/main.swift` — Entry point, orchestration
- `Sources/EstadoParques/MadridAPI.swift` — Fetches park data from Madrid City Council ESRI API
- `Sources/EstadoParques/Models.swift` — Codable structs for API response and change events
- `Sources/EstadoParques/StateManager.swift` — JSON state persistence + NDJSON statistics
- `Sources/EstadoParques/StatusFormatter.swift` — Emoji mapping and post text formatting
- `Sources/EstadoParques/MastodonPoster.swift` — TootSDK wrapper for posting to Mastodon
- `Sources/EstadoParques/WebsiteGenerator.swift` — Rebuilds per-day history and writes the static site
- `website/` — Static site published to GitHub Pages: `style.css` is hand-written, `index.html` is generated
  and committed by CI alongside the state files. Zero JavaScript: one radio button per day, and a single CSS rule
  (`input:checked + label + .day`) shows the selected day

## Key Dependencies

- [TootSDK](https://github.com/TootSDK/TootSDK) — Mastodon API client

## State Files

- `estado_parques.json` — Current park state (`[String: ParkState]`: alert code + schedule), committed to repo. A change in either triggers a post; the legacy `[String: Int]` format is still read
- `estadisticas_parques.ndjson` — Append-only change log: one event per park whose level or schedule changed
  (`from_horario`/`to_horario` only on events logged since schedules were tracked, 2026-10-18)

## GitHub Actions

Workflow in `.github/workflows/check-parks.yml` runs every 30 minutes and commits state changes back to the repo.
It also regenerates the website and, when its content hash is new (cache lookup), deploys it to GitHub Pages
(repo Settings → Pages → Source: GitHub Actions).

## AI Agents

This project was developed with the assistance of AI coding agents.

### Claude Code (Anthropic)

- **Model**: Claude Opus 4.6
- **Tool**: [Claude Code CLI](https://claude.com/claude-code)
- **Role**: Code generation, architecture design, and implementation of the Swift CLI bot, GitHub Actions workflow, and project documentation.

All AI-generated code was reviewed and approved by a human maintainer.
