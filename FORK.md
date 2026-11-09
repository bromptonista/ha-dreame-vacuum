# About this fork

This is [Tasshack/dreame-vacuum](https://github.com/Tasshack/dreame-vacuum) with one file removed:
`custom_components/dreame_vacuum/frontend.py`.

That file is the client for the paid **Dreame Vacuum Card**. It is obfuscated, it posts to
`api.tasshack.com`, and it registers the card's Lovelace resource. Upstream already imports it
optionally ("so that it can be easily stripped"), so without it:

- every vacuum, sensor, switch, select, button and map camera works as upstream ships them;
- the config flow skips the licence-key page;
- nothing in the integration calls `api.tasshack.com`.

Nothing else differs. `git diff <tag> <tag>-nocard1 -- custom_components` shows that deletion and
nothing more.

## Releases

Each upstream release `vX.Y.Z` becomes `vX.Y.Z-nocard1` here, with the same flat
`dreame_vacuum.zip` asset HACS expects. The `Sync upstream release` workflow does this daily:

1. merges the latest upstream release tag (never upstream `master`, never a rebase);
2. resolves the one expected conflict — upstream editing `frontend.py` — by deleting it again;
3. refuses to release if any other file conflicts, if `__init__.py` stops importing `frontend`
   inside its `ModuleNotFoundError` guard, if any module imports `frontend` unconditionally, or if
   `manifest.json` does not carry the upstream version;
4. tags, builds the zip and publishes the release.

A failed run releases nothing; the previous release stays current. Merge that upstream tag by hand,
then run the workflow again. If an upstream release changes `.github/workflows/`, the
workflow's token cannot push it — that one has to be merged by hand too.

GitHub disables scheduled workflows on a public repository after 60 days without activity. If
releases stop arriving, re-enable the workflow on the Actions tab.

## Installing

- **HACS:** add `https://github.com/bromptonista/ha-dreame-vacuum` as a custom repository of type
  Integration.
- **Manually:** unzip `dreame_vacuum.zip` from a release into
  `config/custom_components/dreame_vacuum/`.

Do not use the `install` script in this repository. It is upstream's and downloads upstream's
release, card and all.

Setup and supported devices are as upstream documents them at
[dv.tasshack.com](https://dv.tasshack.com).
