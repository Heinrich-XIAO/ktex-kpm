# KTEX — KPM repository

A KPM (Kindle Package Manager) repository containing **KTEX**, a
handwriting-to-LaTeX pad for jailbroken Kindles.

Add it to a jailbroken Kindle once:

```sh
kpm add-repo https://raw.githubusercontent.com/Heinrich-XIAO/ktex-kpm/main/manifest.json
```

Then install and update like any other package:

```sh
kpm install ktex
kpm upgrade          # picks up new versions
```

## Layout

```
manifest.json                              KPM repository index (v2)
packages/ktex/artifacts/ktex_0.1.0.kpkg    package artifact (relative URL)
```

Artifact URLs are relative to this manifest, matching the layout used by the
official KMC repository. `manifest_version` is 2, which current KPM accepts
(it rejects anything above 3).

## Source

The package source, build script and end-to-end tests live in a separate
repository; see the KTEX source README for build instructions.