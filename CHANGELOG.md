# Changelog

All notable changes to `pywaggle2-nodeinfo`. Format loosely follows Keep a
Changelog; this project uses semantic versioning.

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
