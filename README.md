# Estado Parques Madrid

Bot de Mastodon que comprueba cada 30 minutos el estado de apertura de los parques de Madrid.

Inspirado en [estado-parques-madrid](https://github.com/juanalonso/estado-parques-madrid).

## Funcionalidades

- Consulta la API de alertas de parques del Ayuntamiento de Madrid.
- Compara el estado actual con el anterior para detectar cambios.
- Si hay cambios, publica en Mastodon el estado de todos los parques (🟢🟡🟠🔴).
- Mantiene un registro local del estado (`estado_parques.json`) y un histórico de cambios (`estadisticas_parques.ndjson`).

## Requisitos

- Swift 5.9+
- Una cuenta de Mastodon con un token de acceso (`write:statuses`)

## Uso local

```bash
swift run EstadoParques
```

Con `PRODUCTION=false` (por defecto) solo imprime el estado en consola sin publicar.

Para publicar en Mastodon:

```bash
MASTODON_INSTANCE=mastodon.social MASTODON_ACCESS_TOKEN=tu_token PRODUCTION=true swift run EstadoParques
```

## GitHub Actions

El workflow se ejecuta cada 30 minutos. Configura estos secretos en el repositorio:

| Secreto | Descripción |
|---|---|
| `MASTODON_INSTANCE` | Dominio de la instancia (ej. `mastodon.social`) |
| `MASTODON_ACCESS_TOKEN` | Token de acceso con permiso `write:statuses` |

Y la variable `PRODUCTION` a `true`.

## Exención de responsabilidad

Utiliza datos públicos del Ayuntamiento de Madrid sin afiliación oficial.
