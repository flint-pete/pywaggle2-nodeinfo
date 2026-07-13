# HANDOFF — pywaggle2-nodeinfo (for the Sage CI team)

The consumer half of the node-identity work. `wes-nodeinfo-injection` (v1.0.0)
delivers five identity env vars into every plugin pod; **this** is the small
pywaggle2-side reader that turns them into a clean `NodeInfo` for plugin authors.
Hand this repo to whoever lands node-info in upstream pywaggle.

## What we're asking for

Land `waggle/data/node_info_env.py` (the reader here) into upstream pywaggle,
surfaced behind a first-class accessor — `Plugin.get_node_info()` — mirroring
`waggle.data.vision.Camera` / `.audio.Microphone`. The reader is complete, pure,
dependency-free (stdlib only), and tested; it should drop into `waggle/data/` with
no changes.

## The wire contract (must match the producer)

WES injects these into every plugin pod. The reader depends on exactly this
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
- **End-to-end against the real WES injection (H00F):** the same reader logic
  resolved real identity/GPS from the injected env, and `image-sampler2` consumed it
  into a geotagged upload that appears in the public Sage data API
  (`meta.vsn=H00F, node_id=00004cbb4701d16c`, EXIF carrying H00F's real coords).
  The producing side is `wes-nodeinfo-injection` v1.0.0 (two upstream patches,
  verified live).

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

`image-sampler2`'s `nodemeta._runtime_identity()` is an independent consumer that
uses the **identical** sentinel contract (verified). `wes-nodeinfo-injection` keeps
a mirror copy of this reader for its own e2e test. If the contract changes, update
all three together.
