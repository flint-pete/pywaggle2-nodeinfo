# pywaggle2-nodeinfo

The pywaggle2-side **node-identity reader** — the small piece of the future
pywaggle2 that lets a running plugin learn its own node identity and location
(VSN, node_id, GPS lat/lon, mobility) from the environment WES injects into every
plugin pod.

This repo is scoped to exactly that node-info contribution: the reader, its tests,
its design, and a handoff for the CI team. It is the **consumer** end of the
`wes-nodeinfo-injection` change; the two are designed together.

## What it does

`read_node_info()` reads five env vars that WES projects into every plugin pod (via
the `wes-identity` ConfigMap, `EnvFrom`) and returns a clean `NodeInfo`:

```python
from waggle.data.node_info_env import read_node_info

ni = read_node_info()
# NodeInfo(vsn='H00F', node_id='00004cbb4701d16c',
#          lat=41.7179852752395, lon=-87.98271513806043,
#          mobility='static', vsn_is_placeholder=False)
```

| Env var | Real value | Sentinel when absent | `NodeInfo` field |
|---|---|---|---|
| `WAGGLE_NODE_VSN` | `H00F` | `0` | `vsn` → `None` |
| `WAGGLE_NODE_ID` | `00004cbb…` | unset | `node_id` → `None` |
| `WAGGLE_NODE_GPS_LAT` | `41.71…` | `999` (range-detected) | `lat` → `None` |
| `WAGGLE_NODE_GPS_LON` | `-87.98…` | `999` | `lon` → `None` |
| `WAGGLE_NODE_MOBILITY` | `static`\|`mobile` | unset | `mobility` → `"unknown"` |

The whole point is **sentinel normalization**: plugin authors never see `0` / `999`
/ `""` — only real values or `None`. The load-bearing rule is **never fabricate a
coordinate**: when location is genuinely unknown, `lat`/`lon` are `None` so a caller
building an EXIF geotag OMITS the tag rather than writing bogus coords. Coordinate
sentinels are detected by *range* (`|lat|>90`, `|lon|>180`), which catches the `999`
sentinel and any garbage, while `0.0` (a real coordinate) passes through.

`mobility` is a tri-state that never returns `None` — `"unknown"` is a real,
conservative state (an old manifest with no mobility field, or WES injection
absent), distinct from `"static"`/`"mobile"`.

## Layout

```
waggle/data/node_info_env.py   the reader (production namespace: lands at waggle/data/ upstream)
tests/test_node_info_env.py    25 unit tests (sentinels, range detection, tri-state, override)
DESIGN.md                      why it exists + the resolution/precedence contract
HANDOFF.md                     for the CI team: what to land, the wire contract, how it's verified
```

## Test it

```bash
make test    # self-bootstrapping venv + pytest; 25 tests, pure stdlib reader
```

## Status

The reader is verified end-to-end against the real WES injection: on H00F the same
reader logic resolved real identity/GPS from the injected env, and a plugin
(`image-sampler2`) consumed it into a geotagged upload visible in the Sage data API.
The producing WES side ships as `wes-nodeinfo-injection` v1.0.0. See `HANDOFF.md`
for what the CI team owns (landing this in upstream pywaggle behind
`Plugin.get_node_info()`, plus the `mobility` manifest field).
