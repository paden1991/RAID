# RAID

Local chat filtering by confirmed guild, keywords and writing scripts.

**WoW Forever · Interface 16001 · 0.2.3-beta**

Release candidate / beta. Live-game acceptance is still required.


## WowUp installation and publishing

Select WoW Forever in WowUp, choose **Install from URL**, and enter `https://github.com/paden1991/RAID` (without `.git`). Use the attached `-forever.zip` from [GitHub Releases](https://github.com/paden1991/RAID/releases), not the automatic Source code ZIP. Current versions remain prereleases; use the Beta channel if your manager asks.

Future `v<version>` tags trigger `.github/workflows/release.yml`. Update the TOC version and reviewed `source-manifest.json` hashes, run `python tools/build_release.py`, commit, then push the matching version tag. The workflow verifies all source hashes and TOC entries, packages one addon folder, and publishes the ZIP, Forever metadata and SHA-256 checksum. A tag/version mismatch or missing runtime file stops publication.

## Installation

Copy the `RAID` folder into your WoW Forever `Interface/AddOns` directory, then restart or reload the client. Alternatively, run `python tools/build_local.py` to create an installable ZIP under `dist/`.

Open the addon with `/raidfilter`.

## Verification

```sh
python tools/build_local.py --verify-only
```

This checks the published runtime bytes against the reviewed source manifest. For repositories with external files, add `--local-addon` to verify the complete build. It is a source-integrity check, not live-game certification.

## Related addons

- [ProfPaden](https://github.com/paden1991/ProfPaden)
- [ProfPadenRoutes](https://github.com/paden1991/ProfPadenRoutes)
- [ProfPadenClams](https://github.com/paden1991/ProfPadenClams)
- [CounterCast](https://github.com/paden1991/CounterCast)
- [CounterCastProbe](https://github.com/paden1991/CounterCastProbe)

## Ownership and provenance

Public visibility does not assign a new open-source license. Existing third-party notices and applicable data licenses remain in force. Do not assume that excluded dependencies may be redistributed. No account SavedVariables, personal settings, raw research archives, credentials, or prior packaged releases are included.
