# 🏝️ Island

A minimal, personal Dynamic Island for macOS — only the features I actually use.

Built for a MacBook Air (M4, macOS Tahoe). Native Swift, no Xcode required.

## Status

Early WIP, but already useful. A transparent panel sits on the notch, blends in
at rest, and expands on hover into a tabbed UI.

### Features
- ✅ 📅 **Calendar** — month grid, today highlighted
- ✅ 🌤️ **Weather** — current conditions + 5-day forecast (Open-Meteo), pick your city
- ✅ 🎵 **Music** — Apple Music now-playing + transport controls
- ⏳ 🗂️ **Drag & drop shelf** — a clipboard for files (planned)

## Build & run

Requires the Swift toolchain (comes with Xcode Command Line Tools — no full
Xcode needed).

```sh
./run.sh          # build + launch
./build.sh        # build the .app bundle only
```

A small icon appears in the menu bar; use it to quit.

## License

MIT — see [LICENSE](LICENSE).
