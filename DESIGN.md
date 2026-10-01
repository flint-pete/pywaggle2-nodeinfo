# DESIGN — pywaggle2 node identity & location

Why this reader exists and the contract it implements. This is the node-identity
slice of the broader pywaggle2 design; the full design doc (acquisition ladder,
etc.) is [pywaggle2-design.md](https://github.com/flint-pete/sage-design-planning/blob/master/pywaggle2-design.md)
(§2.2.3 is the missing-value contract). It is not needed to understand or land this
piece.

## The problem

A running Waggle plugin cannot learn its own **VSN** (e.g. `H00F`) or **GPS
lat/lon**. Verified against pywaggle 0.56 (no location/identity API), the plugin
docs (only publish/subscribe/upload/timeit), and a live pod (only
`WAGGLE_PLUGIN_*`/`WAGGLE_APP_ID` env, and mounts of just
`/run/waggle/{uploads,data-config.json}`). The authoritative
`node-manifest-v2.json` + `/etc/waggle/vsn`/`node-id` are node-HOST paths NOT
mounted into pods — so host-run spikes appear to work and then fail in the pod.

Node identity IS attached downstream by Beehive via message routing, so upload
attribution is correct without the plugin knowing. But the plugin still cannot build
a self-describing filename, embed a real EXIF geotag, or geo-filter ML results, and
non-Python / data-plane consumers of the bare file have no node context.

## The API this reader backs

A first-class accessor, mirroring `waggle.data.vision.Camera`:

```python
info = Plugin.get_node_info()
# -> NodeInfo(vsn, node_id, lat, lon, mobility, vsn_is_placeholder)
```

`Plugin.get_node_info()` is the proposed upstream wrapper and does not exist yet.
Today plugins call the function underneath it, `read_node_info()`, directly.

This repo implements the **Tier-1 static** path: read node identity + surveyed
coordinates from the env WES injects. (A Tier-2 live-GPS path for mobile nodes is
designed separately and is complementary — see "Live-GPS tier" below.)

## The missing-value contract (why sentinels → None)

WES cannot always supply every field (a fresh/unsurveyed node, an old manifest, WES
injection absent). The reader turns every "not really known" case into `None` (or
`"unknown"` for mobility) so **plugin authors only ever handle real values or a
clean absence** — never a magic number.

- **VSN** — sentinel `"0"` (and `""`/missing) → `None`, and `vsn_is_placeholder`
  becomes `True`. `"0"` is the documented placeholder a not-yet-provisioned node
  reports; a real (test) vsn like `V999` is NOT a sentinel and passes through.
- **node_id** — `""`/missing → `None`.
- **lat/lon — detected by RANGE, not by literal.** `|lat|>90` or `|lon|>180` → `None`.
  This catches the `999` sentinel *and* any corrupt/garbage value, and is more
  robust than matching a magic literal. Critically, `0.0` is a real coordinate
  (equator / prime meridian) and must pass through — so range detection, not
  "falsy", is the correct test.
- **The never-fabricate invariant.** When location is genuinely unknown the reader
  returns `None`, and callers OMIT the EXIF GPS tag rather than write fake coords.
  A wrong coordinate is worse than an absent one: it silently mislocates data. This
  is the single most important rule in the whole contract.

## Mobility: a tri-state, never None

`NodeInfo.mobility` is `"static" | "mobile" | "unknown"`.

Rationale: a plugin needs to know whether re-polling location is EVER worthwhile. A
**static** node's coordinates never change → resolve once at startup, never again. A
**mobile** node (vehicle/drone-mounted) may move → a plugin MAY re-poll on a cadence
its science dictates.

Why tri-state and not `is_mobile: bool`: `"unknown"` is a real, common state (an old
manifest with no mobility field, or WES injection unavailable). It must drive
CONSERVATIVE behavior, not be silently coerced to a wrong default. An unrecognized
mobility string also coerces to `"unknown"` rather than passing through.

Semantics: `"mobile"` means the node's location is not fixed — it can change WITHOUT
significant human intervention (vehicle/drone), as opposed to a pole/enclosure mount
that needs a deliberate reinstall to move. It says nothing about instantaneous
motion (a mobile node parked for days is still `mobile`). The flag governs whether
re-polling is ever warranted; the plugin owns the cadence.

## Precedence when a live-GPS tier is added (future)

This reader is the static tier. The full resolution precedence, driven by the
`mobility` axis (implemented once a Tier-2 live-GPS wrapper lands):

- `mobile` → try gpsd live fix; else injected/manifest coords; else `None`.
- `static` → the surveyed manifest/injected coordinate is authoritative; do NOT
  consult gpsd even if it serves a fix (that live jitter is noise for a fixed
  asset).
- `unknown` → conservative: prefer manifest/injected coords; try gpsd only
  best-effort if coords are absent; never error.

### Live-GPS tier (designed, not built here)

WES already runs `wes-gps-server` (gpsd on :2947). Rules for the future tier:

- Deployment mobility and GPS-fix liveness are **orthogonal**: a fixed node with a
  real receiver still emits a live, slightly jittering fix (receiver noise, not
  motion).
- For a `static` node the surveyed manifest coordinate is authoritative; ignore the
  live jitter.
- gpsd holds the serial device exclusively, so the design is a library **socket
  wrapper**, not per-plugin device reads — knowledge that belongs in pywaggle2.
- This tier fills only the *location* half of `NodeInfo`; identity
  (`vsn`/`node_id`) always comes from the env/manifest.

(The live gpsd observation these rules came from is in
[docs/history/NOTES.md](docs/history/NOTES.md).)

## Producer / verification

The env this reader consumes is produced by `wes-nodeinfo-injection` (v1.0.0): two
upstream patches add GPS+mobility to the `wes-identity` ConfigMap and project it
into pods via `EnvFrom` (Tier 2, patched scheduler) — pods launched with
`pluginctl run` do not get it; see README "When will my plugin see these vars?".
The full chain — inject → read → geotag → upload → Sage data API — was verified
end-to-end on H00F (history: [docs/history/NOTES.md](docs/history/NOTES.md)).
