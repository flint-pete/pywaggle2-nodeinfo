# Changelog

All notable changes to `pywaggle2-nodeinfo`. Format loosely follows Keep a
Changelog; this project uses semantic versioning.

## [0.1.2] - 2026-10-02

- README wording for the single install path (`pluginctl-nodeinfo`). Docs only;
  no code change, so the consumers' vendored copy stays at v0.1.1.

## [0.1.1] - 2026-10-01

Documentation pass for student handoff. No behavior change.

### Changed
- `node_info_env.py`: docstring now links the public design doc
  (https://github.com/flint-pete/sage-design-planning/blob/master/pywaggle2-design.md) instead of a
  private path. Comment-only; mirrored byte-identically into
  `wes-nodeinfo-injection/pywaggle2/node_info_env.py`. The vendored copies in
  sage-yolo2 / sage-bioclip2 (v0.1.0) are behaviorally identical and need no
  re-vendor for this change.
- README: realistic example output (`mobility='unknown'` — no fleet manifest has
  the field yet); `python3 -m waggle.data.node_info_env` JSON check; new sections
  "When will my plugin see these vars?" (Tier 2 or explicit `envFrom`; all `None`
  under `pluginctl run`) and "How plugins use this today (vendoring)".
- `read_node_info()` named as the real function; `Plugin.get_node_info()` marked as
  the future upstream wrapper.
- Consumer references updated from `image-sampler2` to the current copies
  (media-sampler3 `nodemeta.py`, vendored `node_info.py` in sage-yolo2 and
  sage-bioclip2, the wes-nodeinfo-injection mirror and inline pod reader).
- DESIGN.md links the public pywaggle2 design doc.

### Moved
- H00F verification story and the live-GPS (TPV) observation moved to
  `docs/history/NOTES.md`; the contract and precedence rules stay in place.

## [0.1.0] - 2026-07-13

First tagged release — the pywaggle2-side node-identity reader, packaged as a
standalone repo for the Sage CI handoff.

### Added
- `waggle/data/node_info_env.py` — `read_node_info()` reader that turns the five
  WES-injected `WAGGLE_NODE_*` env vars into a clean `NodeInfo`, with sentinel →
  `None`/`"unknown"` normalization. Pure, stdlib-only, dependency-free. Production
  namespace `waggle/data/` so it drops straight into upstream pywaggle.
- `tests/test_node_info_env.py` — 25 unit tests: real values, all sentinels,
  range-based coord detection (catches `999` + garbage, passes `0.0`), the
  never-fabricate invariant, the mobility tri-state, node_id/vsn edge cases, and the
  `os.environ` default.
- `README.md`, `DESIGN.md`, `HANDOFF.md` — what it does, why (the missing-value
  contract + mobility tri-state + resolution precedence), and the CI-team handoff
  (wire contract, verification, what to land upstream).
- `Makefile` (self-bootstrapping venv + pytest), `VERSION`, `.gitignore`.

### Notes
- The reader is verified end-to-end against the real WES injection on H00F (identity
  → geotagged upload → Sage data API). The producing side ships as
  `wes-nodeinfo-injection` v1.0.0.
- Canonical source for the reader lives here; `wes-nodeinfo-injection` keeps a mirror
  copy for its own e2e test, and `image-sampler2` has an independent consumer using
  the identical contract — keep the three in sync if the contract changes.
