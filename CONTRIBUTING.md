# Contributing

Thanks for your interest in the open-source **Neuromancer** Godot 4 remake. This doc
explains how the project is laid out, how to get a working build, and how to contribute
without stepping on the legal third rail that abandonware remakes have to respect.

## TL;DR

- The repo ships **code only** — never commit the original game or anything extracted
  from it.
- You supply your own original `neuro.exe` + `neuro1.dat` + `neuro2.dat`, run the
  extractor once, and Godot loads the resulting PNG/JSON.
- Work is phased into milestones **M0–M5** (see [BACKLOG.md](BACKLOG.md)); each milestone
  is meant to be independently playable.

## The legal stance (please read before contributing assets)

"Abandonware" is a community label, not a legal category. The original code, art, music,
and the *Neuromancer* name/story are still owned by their respective rights holders. So:

- **Never commit** `*.dat`, `*.exe`, `*.com`, or any image/text/audio extracted from
  them. `.gitignore` already blocks these; don't override it.
- The extracted originals are for **local development and parity-checking only**.
- Distributable releases (milestone **M4+**) replace every extracted asset with
  newly-authored, freely-licensed art and music. New assets you contribute must be your
  own work (or compatibly licensed) and you agree to release them under this repo's
  [MIT License](LICENSE).

This is the same "bring your own game files" model ScummVM uses.

## Getting a working build

You need **Godot 4.3+** and **Python 3** (standard library only — no pip installs).

1. Obtain your own original game files (`neuro.exe`, `neuro1.dat`, `neuro2.dat`) and put
   them somewhere outside the repo (or in the repo root — they're git-ignored).
2. Extract the assets:
   ```bash
   cd tools/extract_dat
   python3 extract.py --exe /path/neuro.exe --dat1 /path/neuro1.dat --dat2 /path/neuro2.dat --out ../../assets
   ```
   This writes PNGs into `assets/sprites/` + `assets/backgrounds/`, the palette into
   `assets/palettes/`, and text into `assets/text/`. See
   [`tools/extract_dat/README.md`](tools/extract_dat/README.md) for format details.
3. Open the project in Godot (`project.godot`) and run.

## Repository layout

```
tools/extract_dat/   One-time asset extractor (Python). Ports the .DAT decoder.
assets/              Extracted originals (git-ignored). PNG + JSON. Regenerate locally.
data/                Hand-authored game definitions — rooms, NPCs, cyberspace sites (.tres)
scenes/              Godot scenes: RealWorld/, Cyberspace/, UI/
src/                 GDScript
  core/    GameState.gd (autoload world state), SaveSystem, Clock
  world/   RoomController, NpcController, DialogEngine
  cyber/   MatrixNav, IceCombat, SkillSoftware
  econ/    Inventory, Credits, BodyShop
```

**State lives in one place.** `src/core/GameState.gd` is an autoload singleton holding the
canonical, save-serializable world state (player, inventory, skills, story flags, the
in-world clock). Rooms, shops, and cyberspace sites read/write through it so that saving
is a single `to_dict()`/`from_dict()` round-trip. When you add a new persistent value, add
it to `GameState` rather than scattering it across scenes.

## How the work is organized (milestones)

| | Milestone | Goal |
|-|-----------|------|
| M0 | Scaffold & asset pipeline | **done** — extractor + repo skeleton |
| M1 | Real-world engine | Chiba City: movement, dialog, PAX, inventory |
| M2 | Economy & progression | credits, shops, body shop, skills/decks |
| M3 | Cyberspace & ICE combat | matrix navigation, turn-based ICE |
| M4 | Endgame & owned-art swap | win condition + replace extracted art |
| M5 | Polish & release | saves, input, web/desktop/mobile exports |

When in doubt about correctness (dialog flow, ICE rules, the endgame graph), the
[Javamancer](https://github.com/maehem/javamancer) port is the most complete reference —
compare behavior against it.

## Backlog & issues

This repo keeps [BACKLOG.md](BACKLOG.md) as a second view of the GitHub/Codeberg **Issues**
tab — every backlog item should have a matching issue and vice versa. If you pick up an
item, claim its issue; if you propose new work, add both a `- [ ]` line and an issue.

## Code conventions

- Match the surrounding GDScript style; keep `GameState` the single source of truth.
- Game *content* (rooms, dialog, items) goes in `data/` resources, not hardcoded in
  scripts, so it can be edited without code changes.
- Keep `tools/extract_dat/` dependency-free (stdlib Python only).
- Markdown docs end with the project footer below.

## Credits

This remake stands on the reverse-engineering work of **Henadzi Matuts** (Reuromancer)
and **Mark J. Koch / @maehem** (Javamancer). Full attribution in [CREDITS.md](CREDITS.md).

---

*Proudly Made in Nebraska. Go Big Red! 🌽 <https://xkcd.com/2347/>*
