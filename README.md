# pywaggle2-nodeinfo

The pywaggle2-side **node-identity reader** — the small piece of the future
pywaggle2 that lets a running plugin learn its own node identity and location
(VSN, node_id, GPS lat/lon, mobility) from the environment WES injects into the
plugin pod.

This repo is scoped to exactly that node-info contribution: the reader, its tests,
its design, and a handoff for the CI team. It is the **consumer** end of the
`wes-nodeinfo-injection` change; the two are designed together.

## What it does

`read_node_info()` reads five env vars that WES projects into plugin pods (via the
`wes-identity` ConfigMap, `EnvFrom` — see "When will my plugin see these vars?"
below for exactly which pods) and returns a clean `NodeInfo`:

```python
from waggle.data.node_info_env import read_node_info

ni = read_node_info()
# NodeInfo(vsn='H00F', node_id='00004cbb4701d16c',
#          lat=41.7179852752395, lon=-87.98271513806043,
#          mobility='unknown', vsn_is_placeholder=False)
```

`mobility='unknown'` is what you will actually see today: no fleet
`node-manifest-v2.json` carries a mobility field yet, so WES has nothing to inject
and the reader reports the conservative `"unknown"`. `static`/`mobile` will appear
once the manifest field lands (see `HANDOFF.md`).

`read_node_info()` is the real function today. `Plugin.get_node_info()` (mentioned
in `DESIGN.md`/`HANDOFF.md`) is the proposed upstream pywaggle wrapper around it —
it does not exist yet.

### Command-line check

The module has a `__main__` entrypoint that prints the resolved `NodeInfo` as JSON —
handy for checking what a pod (or your shell) actually sees:

```bash
cd pywaggle2-nodeinfo
python3 -m waggle.data.node_info_env
# {"vsn": null, "node_id": null, "lat": null, "lon": null, "mobility": "unknown", "vsn_is_placeholder": true}
WAGGLE_NODE_VSN=H041 python3 -m waggle.data.node_info_env
# {"vsn": "H041", "node_id": null, "lat": null, "lon": null, "mobility": "unknown", "vsn_is_placeholder": false}
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

## When will my plugin see these vars?

Only when the plugin pod actually receives the `wes-identity` ConfigMap as env.
That happens in exactly two ways:

1. **Tier 2 of `wes-nodeinfo-injection`** — a patched edge-scheduler adds
   `envFrom: wes-identity` to every pod *it* schedules (jobs submitted to SES).
2. **An explicit `envFrom` / `env`** in a pod spec you write yourself.

**Under `pluginctl run` you get all `None` (and `mobility="unknown"`).**
`pluginctl` builds the pod on the client side, so the patched scheduler never touches
it. That is why the media stack passes identity another way: media-sampler3 is
launched with `--vsn`, and the consumers read identity from each frame's EXIF
(with env as fallback / cross-check). Beehive attaches the node's VSN to published
data downstream regardless.

Tier 1 alone (just the ConfigMap) changes nothing a running plugin can see.

> Naming clash: in `wes-nodeinfo-injection`, *Tier 1* = the `wes-identity`
> ConfigMap and *Tier 2* = the patched scheduler. In this repo's `DESIGN.md`,
> *Tier-1* = static identity from env (this reader) and *Tier-2* = a future live-GPS
> (gpsd) path. Same words, different axes. See
[`wes-nodeinfo-injection`](https://github.com/flint-pete/wes-nodeinfo-injection) for
the tiers, and the hub install guide
[INSTALLING-MEDIA-SAMPLER3.md](https://github.com/flint-pete/media-sampler3/blob/master/INSTALLING-MEDIA-SAMPLER3.md) (Step 3) and
[docs/HOW-IT-WORKS.md](https://github.com/flint-pete/media-sampler3/blob/master/docs/HOW-IT-WORKS.md) for how it fits together.

## How plugins use this today (vendoring)

pywaggle2 is not pip-installable yet, so plugins **copy** the reader instead of
importing this package:

| Where | What | Relation to `waggle/data/node_info_env.py` |
|---|---|---|
| [sage-yolo2](https://github.com/flint-pete/sage-yolo2) `node_info.py` | vendored copy (v0.1.0 @ `4f3e589`) | body byte-identical; see [VENDORED.md](https://github.com/flint-pete/sage-yolo2/blob/master/VENDORED.md) |
| [sage-bioclip2](https://github.com/flint-pete/sage-bioclip2) `node_info.py` | vendored copy (v0.1.0 @ `4f3e589`) | body byte-identical; see its `VENDORED.md` |
| [media-sampler3](https://github.com/flint-pete/media-sampler3) `nodemeta.py` | independent re-implementation (`_runtime_identity()`) | same sentinel contract, different code |
| [wes-nodeinfo-injection](https://github.com/flint-pete/wes-nodeinfo-injection) `pywaggle2/node_info_env.py` | mirror for its e2e test | byte-identical |
| wes-nodeinfo-injection `node-test/test-plugin-pod.yaml` | condensed inline reader in a test pod | semantically equivalent, not byte-identical |

Vendored copies sit at the plugin's repo root as `node_info.py` (not under
`waggle/`, which would shadow the installed pywaggle) and are imported as:

```python
from node_info import read_node_info
```

This repo is the canonical source. If the contract changes, update every copy above.

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

The reader is verified against the real WES injection (Tier 1 resolved H041's real
VSN + GPS during the media-stack install — see the hub guide's "What was verified").
The producing WES side ships as `wes-nodeinfo-injection` v1.0.x. Current consumers
are listed in "How plugins use this today" above. See `HANDOFF.md` for what the CI
team owns (landing this in upstream pywaggle behind `Plugin.get_node_info()`, plus
the `mobility` manifest field). Earlier verification history:
[docs/history/NOTES.md](docs/history/NOTES.md).
