# pywaggle2-nodeinfo — history notes

Narrative and verification history moved out of the main docs (README, DESIGN,
HANDOFF) so those describe only the current contract. Nothing here is required to
use the reader. For how all six media-stack components evolved, see the hub's
[DESIGN-PATH.md](https://github.com/flint-pete/media-sampler3/blob/master/DESIGN-PATH.md).

## Original end-to-end verification on H00F (v0.1.0, Jul 2026)

*(moved from HANDOFF.md "What's verified" and README "Status")*

Against the real WES injection on H00F, the same reader logic resolved real
identity/GPS from the injected env, and `image-sampler2` (the producer at the time,
since superseded by media-sampler3) consumed it into a geotagged upload that
appears in the public Sage data API (`meta.vsn=H00F, node_id=00004cbb4701d16c`,
EXIF carrying H00F's real coords). The producing side was `wes-nodeinfo-injection`
v1.0.0 (two upstream patches, verified live). At that time the "keep in sync" set
was three files: this reader, the wes-nodeinfo-injection mirror, and
`image-sampler2`'s `nodemeta._runtime_identity()` (identical sentinel contract).

## The live-GPS (TPV) observation behind the Tier-2 rules

*(moved from DESIGN.md "Live-GPS tier")*

A live TPV stream was read from `wes-gps-server` (gpsd on :2947) on a static pole
node. It showed that a fixed node with a real GPS receiver emits a live,
slightly-jittering fix — receiver noise, not motion. That observation validated two
things: (1) deployment-mobility and GPS-fix-liveness are orthogonal axes, and (2)
for a `static` node the surveyed manifest coordinate is authoritative and the live
jitter should be ignored. Because gpsd holds the serial device exclusively, the
design became a library socket wrapper rather than per-plugin device reads.
