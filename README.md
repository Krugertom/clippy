# Clippy 📎

A blazingly fast, Liquid Glass clipboard manager for macOS 26 (Tahoe), built with native SwiftUI + AppKit.

## Install

```bash
./build.sh install    # builds, installs to /Applications, launches
./build.sh run        # dev: build + run from ./build
```

Press **⌘1** to toggle the bar at the bottom of your screen. A paperclip icon also lives in the menu bar. On first launch from /Applications, Clippy registers itself to start at login (toggle in settings).

## Features

- **Liquid Glass bar** — true behind-window glass via `NSGlassEffectView` on a transparent, non-activating panel. It never steals focus from the app you're in.
- **Everything captured** — text, links, images (any aspect ratio, never distorted), and files, with the source app's name + icon in each card header.
- **Tags = saved clipboard** — create colored tags with the **+** button, right-click any card to save it to a tag. Tagged clips survive retention pruning and "Clear History".
- **Search everything** — click the magnifier or just start typing; searches content, app names, file paths, and types.
- **Drag out** — drag any card straight into another app (text, links, images, files). With a shift-click multi-selection, the drag carries the combined content.
- **Settings** — the **⋯** button (top right): history retention (1 hour → forever), max items, clear history.

## Keyboard

| Key | Action |
| --- | --- |
| ⌘1 | Toggle Clippy |
| ← → | Select card |
| ↩ / ⌘C | Copy selected (pastes into your app if enabled) |
| ⌘X | Copy selected + delete from history |
| ⌘⌫ | Delete selected |
| ⇧-click | Multi-select cards; combine into one copy |
| Any letter | Start searching |
| Esc | Clear search / close |

## Storage

History lives in `~/Library/Application Support/Clippy/` — `store.json` plus `images/` and `thumbs/`. Delete the folder to reset.
