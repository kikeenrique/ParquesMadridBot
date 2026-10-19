# Estado Parques Madrid

Estado de apertura y alertas meteorológicas de los parques de Madrid, comprobado cada 30 minutos.

- **Mastodon:** [@ParquesMadridBot@mastodon.social](https://mastodon.social/@ParquesMadridBot) — publica cada cambio.
- **Web:** [parques.lemambo.com](https://parques.lemambo.com) — estado actual e histórico día a día. Se puede
  instalar como app en iPhone, iPad, Mac y Android.

Usa datos públicos del Ayuntamiento de Madrid, sin afiliación oficial. Inspirado en
[estado-parques-madrid](https://github.com/juanalonso/estado-parques-madrid).

## Desarrollo

Requiere Swift 6 (CI usa Swift 6.4).

```bash
swift run EstadoParques                    # consulta la API e imprime el estado (no publica)
swift run EstadoParques --website website  # regenera website/index.html
swift test                                 # ejecuta los tests
```

Para publicar en Mastodon: `PRODUCTION=true`, `MASTODON_INSTANCE` y `MASTODON_ACCESS_TOKEN`
(permiso `write:statuses`). En GitHub Actions van como secretos, y `PRODUCTION` como variable.

El workflow `.github/workflows/check-parks.yml` se ejecuta cada 30 minutos: guarda el estado
(`estado_parques.json`, `estadisticas_parques.ndjson`) y despliega la web en GitHub Pages. En cada push
ejecuta antes los tests.

Lo hecho y lo pendiente está en [ROADMAP.md](ROADMAP.md).
