# smart-gallery-mac-sync

Copies new photos from Apple Photos on this Mac into `smart-gallery/imports/incoming`, so the
smart-gallery backend can upload and analyze them. Photos taken on an iPhone reach this Mac
through iCloud Photos, then this job picks them up every 5 minutes.

```
iPhone → iCloud → Photos (this Mac)
                     ↓  every 5 min: launchd → bin/photosync-runner → sync.sh → osxphotos
              imports/incoming/<uuid>.jpeg
                     ↓  backend PhotoDiscoveryJob (every 5 min)
              upload to R2 → ML analysis → tags + embedding
```

This folder must live inside the `smart-gallery` folder, next to `imports/`.

## How it works

- **`sync.sh`** runs [osxphotos](https://github.com/RhetTbull/osxphotos) to export photos added
  after the first run. Photos are exported as JPEG (the edited version if a photo was edited),
  named by Photos' unique ID, into `state/staging/`, then moved into `imports/incoming/` so the
  backend never sees a half-written file. Videos and the video part of Live Photos are skipped.
- **`state/`** holds what the sync remembers (not in git):
  - `since`: the start time written on the first run; older photos are never synced
  - `export.db`: osxphotos' record of photos already exported, so nothing is sent twice
- **`runner/photosync-runner.swift`** is a tiny launcher that runs `sync.sh`. launchd runs this
  instead of `/bin/bash`, so Full Disk Access only needs to be granted to this one program.
- **`com.kee.smart-gallery.mac-sync.plist`** is the launchd job: every 300 seconds, plus once when
  it's loaded. Output goes to `logs/sync.log`.

## Setup (one time)

1. **Install osxphotos** into a virtual environment:
   ```
   python3.13 -m venv .venv
   .venv/bin/pip install -r requirements.txt
   ```
2. **Build the runner:**
   ```
   make build
   ```
3. **Grant Full Disk Access to the runner:** System Settings → Privacy & Security →
   **Full Disk Access** → **+** → press `Cmd+Shift+G`, enter the full path to
   `bin/photosync-runner`, click Open, and make sure its switch is on.
   This is **Full Disk Access**, not the "Photos" permission; only Full Disk Access stops
   macOS from asking every run.
4. **Install the launchd job:**
   ```
   make install
   ```
   This copies the plist into `~/Library/LaunchAgents/` and starts the job (it runs once right away).

## Everyday commands

| Command | What it does |
|---|---|
| `make status` | Shows run count and `last exit code` (0 = success) |
| `make logs` | Follows `logs/sync.log` live; `Ctrl+C` to stop watching |
| `make uninstall` | Stops the job and removes it from `~/Library/LaunchAgents/` |
| `./sync.sh` | Runs one sync by hand (needs Full Disk Access for your terminal app) |

## Troubleshooting

**"… would like to access data from other apps" popup on every run.** The app named in the popup
needs **Full Disk Access** (not the Photos permission). For the background job that's
`bin/photosync-runner`; for manual runs it's your terminal app. Quit and reopen a terminal app after
changing its access.

**`make install` fails with "Permission denied".** `~/Library/LaunchAgents` may be owned by
`root` (some installers create it that way). Give it back to your user, then install again:
```
sudo chown "$(whoami)":staff ~/Library/LaunchAgents
```

**Popup or "Operation not permitted" after rebuilding the runner.** macOS identifies the runner by
its exact build, so a rebuild needs Full Disk Access granted again: remove `photosync-runner` from
the list and add it back. `make build` only recompiles when the Swift file changed.

**Changed the plist?** Run `make install` again to copy and reload it.

**Start over from "now".** Delete `state/since` (and `state/export.db` to forget what was exported);
the next run records a new start time.
