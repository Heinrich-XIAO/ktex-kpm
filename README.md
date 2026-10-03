# KTEX — KPM repository

A KPM (Kindle Package Manager) repository containing **KTEX**, a
handwriting-to-LaTeX pad for jailbroken Kindles.

Add it to a jailbroken Kindle once:

```sh
kpm add-repo https://tinyurl.com/23aqdzjz
```

Then install and update like any other package:

```sh
kpm install ktex
kpm upgrade          # picks up new versions
```

The short link is safe to use because artifact URLs in the index are absolute —
see below.

## Layout

```
manifest.json                              KPM repository index (v2)
packages/ktex/artifacts/ktex_0.1.0.kpkg    package artifact (absolute URL)
```

Artifact URLs are **absolute**, not relative to this manifest. KPM stores the
URL you pass to `kpm add-repo` and resolves relative artifact paths against it
(`src/install.c`), so a shortened add-repo URL would otherwise resolve artifacts
against the shortener's domain and 404. Absolute URLs are used verbatim, so
short links, mirrors and CDN URLs all keep working.

`manifest_version` is 2, which current KPM accepts (it rejects anything above 3).

Both published versions are kept in the index *and* kept on disk:
`raw.githubusercontent.com` caches `manifest.json` aggressively, so a Kindle can
be handed a stale index that references an older version — every listed version
must remain downloadable. KPM installs the highest listed version
(`ORDER BY version DESC` in `src/package.c`).

## Source

The package source, build script and end-to-end tests live in a separate
repository; see the KTEX source README for build instructions.