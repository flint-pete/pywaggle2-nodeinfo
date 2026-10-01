# HANDOFF — pywaggle2-nodeinfo (for the Sage CI team)

The consumer half of the node-identity work. `wes-nodeinfo-injection` (v1.0.0)
delivers five identity env vars into scheduler-launched plugin pods (its Tier 2
patched scheduler; `pluginctl run` pods don't get them); **this** is the small
pywaggle2-side reader that turns them into a clean `NodeInfo` for plugin authors.
Hand this repo to whoever lands node-info in upstream pywaggle.

## What we're asking for

Land `waggle/data/node_info_env.py` (the reader here) into upstream pywaggle,
surfaced behind a first-class accessor — `Plugin.get_node_info()` — mirroring
`waggle.data.vision.Camera` / `.audio.Microphone`. The reader is complete, pure,
dependency-free (stdlib only), and tested; it should drop into `waggle/data/` with
no changes.

## The wire contract (must match the producer)

WES injects these into plugin pods (once the Tier 2 scheduler patch is merged). The
reader depends on exactly this
contract; `wes-nodeinfo-injection` produces exactly this. Keep them in lock-step.

| Env var | Real value | Sentinel if unavailable | Reader normalizes to |
|---|---|---|---|
| `WAGGLE_NODE_VSN` | e.g. `W09E` | `0` (and `""`/unset) | `vsn=None`, `vsn_is_placeholder=True` |
| `WAGGLE_NODE_ID` | e.g. `000048B0…` | unset | `node_id=None` |
| `WAGGLE_NODE_GPS_LAT` | e.g. `41.8681` | `999` | `lat=None` |
| `WAGGLE_NODE_GPS_LON` | e.g. `-87.6134` | `999` | `lon=None` |
| `WAGGLE_NODE_MOBILITY` | `static`\|`mobile` | unset | `mobility="unknown"` |

Normalization rules the reader enforces (see `DESIGN.md` for the why):
- **Coordinates by range, never by literal.** `|lat|>90` / `|lon|>180` → `None`.
  Catches the `999` sentinel and any garbage; `0.0` (equator/prime meridian) is a
  real value and passes through.
- **Never fabricate.** Unknown location → `None`, so callers OMIT EXIF GPS rather
  than write bogus coords. This is the invariant the whole design protects.
- **Mobility is tri-state, never `None`.** `"unknown"` is a real conservative state,
  distinct from `static`/`mobile`; an unrecognized value coerces to `"unknown"`.
- **Explicit pod env wins.** A plugin's own `Env` var of the same name overrides the
  injected value (mirrors k8s `Env`-over-`EnvFrom` precedence the scheduler relies
  on) — the reader just reads the resolved environment, so this falls out for free.

## What's verified

- **25 unit tests** (`make test`, pure stdlib + pytest): real values, every
  sentinel, range-boundary coords, the never-fabricate invariant, the mobility
  tri-state, node_id/vsn edge cases, and `os.environ` default.
- **End-to-end against the real WES injection:** verified live (H00F, and Tier 1
  again on H041 during the media-stack install). The producing side is
  `wes-nodeinfo-injection` v1.0.x (two upstream patches). The original H00F
  verification story is in [docs/history/NOTES.md](docs/history/NOTES.md).

## What the CI team owns

1. **Land the reader** in upstream pywaggle at `waggle/data/node_info_env.py` and
   expose `Plugin.get_node_info()` (plus convenience shims `get_vsn()`,
   `get_location()` if desired). Straight copy — no edits needed.
2. **Merge the producer.** `wes-nodeinfo-injection`'s two patches
   (`update-stack.sh` + `edge-scheduler`) — see that repo's HANDOFF. Without them
   the reader returns all-sentinel (`vsn=None`, etc.) but never errors, so landing
   the reader first is safe.
3. **Add the `mobility` manifest field** (`static`|`mobile`, default `static`) to
   `node-manifest-v2.json`. Until it exists the reader returns `"unknown"` — correct
   and conservative, but mobility-aware logic stays idle until the field lands.
4. **(Future, out of scope here) the live-GPS tier.** This reader is the Tier-1
   *static* identity path (from env). A Tier-2 live-GPS path wrapping the existing
   `wes-gps-server` gpsd is designed (`DESIGN.md` §live-gps) but not built here; it
   is complementary — for mobile nodes — and should read this same env for the
   static tier.

## Keep in sync

This repo (`waggle/data/node_info_env.py`) is canonical. Copies that must change
with it if the contract changes:

- `wes-nodeinfo-injection/pywaggle2/node_info_env.py` — byte-identical mirror (its
  e2e test); check with `diff -q`.
- `wes-nodeinfo-injection/node-test/test-plugin-pod.yaml` — condensed inline
  reader; semantically equivalent, not byte-identical.
- `media-sampler3/nodemeta.py` (`_runtime_identity()`) — independent
  re-implementation of the same sentinel contract.
- `sage-yolo2/node_info.py` and `sage-bioclip2/node_info.py` — vendored copies
  (v0.1.0 @ `4f3e589`); see `sage-yolo2/VENDORED.md` for the body diff command.
