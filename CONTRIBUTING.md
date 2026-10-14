[Back to **README**](README.md)

# Contributing to openPCIE

## Found something?

Open an [Issue](https://github.com/chili-chips-ba/openPCIE/issues). For bugs, include how to reproduce it: a modified [co-sim](5.sim), a waveform, or logs.

## Want to change something?

1. Bigger change? Open an Issue first, so we agree on the approach.
2. Fork, branch off `main`, make the change.
3. Check: [`run-lint.sh`](4.build/hw_build.openXC7/run-lint.sh) shows no new findings, the [co-sim](5.sim) passes, the [openXC7 build](4.build/hw_build.openXC7) completes. For a cleanup, [`run-leq.sh`](4.build/hw_build.openXC7/run-leq.sh) proves nothing changed.
4. Open a Pull Request against `main`.

RTL changes go to [2.rtl](2.rtl). The AMD reference design stays as is.

Lint findings: fix them at the root; waive only as the last resort. The steps are in [`run-lint-waivers.txt`](4.build/hw_build.openXC7/run-lint-waivers.txt).

## License

Code is BSD-3-Clause, hardware is CC-BY-SA-4.0 ([REUSE.toml](REUSE.toml)). Your contribution takes the license of the files it goes into. New files need an SPDX header; `reuse lint` must pass.

## GenAI

Allowed, if:

- you understand and take responsibility for every line,
- no third-party copyrighted content gets in,
- you say in the Pull Request which tool and model you used, and for what.

Purely AI-generated work is not accepted. This follows [NLnet's GenAI policy](https://nlnet.nl/foundation/policies/generativeAI/), our funder.
