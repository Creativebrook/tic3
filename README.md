# TIC³

Premium 3D tic-tac-toe for Android, built with Godot 4.

## Current V1

- 3×3×3, 4×4×4 and 5×5×5 boards.
- All straight winning lines in 3D: in-plane, across layers and full spatial diagonals.
- Local Player vs Player.
- Player vs Computer with Casual / Smart / Expert AI.
- Independent chess-style player clocks. In CPU mode only the human thinking time counts toward the record.
- Local highscores per board size and difficulty, ordered by best time and then moves.
- 3D glass-board rendering, metallic/emissive X/O pieces, shadows and glow.
- Exploded/cube-like stack toggle and per-layer focus.
- Rotatable camera with constrained angles and pinch/wheel zoom.
- Animated winning line and haptics.

## Winning-line counts

The generic line generator produces:

- 3×3×3: 49 lines
- 4×4×4: 76 lines
- 5×5×5: 109 lines

## Run locally

1. Install Godot 4.3+.
2. Import `project.godot`.
3. Run the project.

The project targets Godot's mobile renderer for the Android build.

## Android test build via GitHub Actions

Every push to `main` runs `.github/workflows/android-debug.yml` and produces an installable **debug APK** as the `tic3-android-debug` workflow artifact. This is the preferred path for device testing without installing the Godot editor locally.

Install with ADB after downloading the artifact:

```powershell
adb install -r tic3-debug.apk
```

## Manual Android export

In Godot:

1. Editor → Manage Export Templates → install templates.
2. Editor Settings → Export → Android: configure Java SDK and Android SDK.
3. Project → Export → use the Android Debug preset.
4. Export APK for local testing or configure a release preset/AAB for Play Store.

## Next production pass

Recommended before Play Store release:

- Add sound design.
- Add replay timeline.
- Add onboarding animation showing a cross-layer diagonal.
- Add pause/resume lifecycle handling for timers.
- Add Android back-button confirmation during an active match.
- Add release keystore + signed AAB pipeline.
- Device-test 3×3, 4×4 and 5×5 camera framing on several aspect ratios.
- Profile Expert AI on mid-range Android hardware and tune time budgets.
