# Estado Parques Madrid

Swift CLI bot that monitors Madrid park alert status and posts to Mastodon.

## Build & Run

```bash
swift build
swift run EstadoParques
```

Set `PRODUCTION=true`, `MASTODON_INSTANCE`, and `MASTODON_ACCESS_TOKEN` to post to Mastodon.

## Project Structure

- `Sources/EstadoParques/main.swift` — Entry point, orchestration
- `Sources/EstadoParques/MadridAPI.swift` — Fetches park data from Madrid City Council ESRI API
- `Sources/EstadoParques/Models.swift` — Codable structs for API response and change events
- `Sources/EstadoParques/StateManager.swift` — JSON state persistence + NDJSON statistics
- `Sources/EstadoParques/StatusFormatter.swift` — Emoji mapping and post text formatting
- `Sources/EstadoParques/MastodonPoster.swift` — TootSDK wrapper for posting to Mastodon

## Key Dependencies

- [TootSDK](https://github.com/TootSDK/TootSDK) — Mastodon API client

## State Files

- `estado_parques.json` — Current park alert state (`[String: Int]`), committed to repo
- `estadisticas_parques.ndjson` — Append-only change log

## GitHub Actions

Workflow in `.github/workflows/check-parks.yml` runs every 30 minutes and commits state changes back to the repo.

## AI Agents

This project was developed with the assistance of AI coding agents.

### Claude Code (Anthropic)

- **Model**: Claude Opus 4.6
- **Tool**: [Claude Code CLI](https://claude.com/claude-code)
- **Role**: Code generation, architecture design, and implementation of the Swift CLI bot, GitHub Actions workflow, and project documentation.

All AI-generated code was reviewed and approved by a human maintainer.
