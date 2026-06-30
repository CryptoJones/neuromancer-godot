<p align="center"><em>Proudly Made in Nebraska. Go Big Red! 🌽 <a href="https://xkcd.com/2347/">https://xkcd.com/2347/</a></em></p>

# Neuromancer (Godot 4 Remake)

A faithful, open-source remake of **Neuromancer** — the 1988 Interplay cyberpunk
adventure based on William Gibson's novel — rebuilt in **Godot 4** and exportable to
web, desktop, and mobile.

> **Status:** 🚧 Early development (Milestone M0 — asset pipeline & scaffold).

## What this is

The original game shipped as a DOS executable plus two proprietary compressed archives
(`NEURO1.DAT`, `NEURO2.DAT`). This project:

1. **Extracts** the original sprites, backgrounds, and text from those archives using a
   documented decoder (see *Standing on the shoulders of* below) — for prototyping.
2. **Reimplements** the game logic (real world, economy, cyberspace, ICE combat,
   endgame) from scratch in GDScript.
3. **Swaps in** newly-authored, freely-licensed art and music in later milestones so the
   finished game can be distributed standalone.

## ⚖️ This repo ships code only

We do **not** redistribute the original game or any copyrighted assets. To run the
asset-extraction step you must supply **your own** legally-obtained `NEURO1.DAT` and
`NEURO2.DAT` (the "bring your own game files" model, like ScummVM). See
[`tools/extract_dat/README.md`](tools/extract_dat/README.md).

## Standing on the shoulders of 🙏

This remake would not be possible without the reverse-engineering and porting work of:

- **[Henadzi Matuts](https://github.com/HenadziMatuts)** — author of
  **[Reuromancer](https://github.com/HenadziMatuts/Reuromancer)** (MIT) and the
  ["Reversing the Neuromancer"](https://henadzimatuts.github.io/2018/03/30/reversing-the-neuromancer-part-1.html)
  blog series, which document the `.DAT` archive format, the two-stage image
  decompression, and the VGA sprite/palette encoding.
- **[maehem](https://github.com/maehem)** — author of
  **[Javamancer](https://github.com/maehem/javamancer)** (MIT), a near-complete and
  *winnable* Java port that is our reference for dialog flow, cyberspace navigation, and
  turn-based ICE combat.
- **Interplay Productions** and the original 1988 team — Bruce Balfour, Brian Fargo,
  Troy A. Miles, and Michael A. Stackpole — and **William Gibson**, whose novel started
  it all.

Full attribution in [CREDITS.md](CREDITS.md). Both upstream projects are MIT-licensed;
where we adapt their code we preserve their notices.

## Roadmap

See [BACKLOG.md](BACKLOG.md). Briefly: **M0** asset pipeline → **M1** real-world engine
(Chiba City) → **M2** economy & skills → **M3** cyberspace & ICE combat → **M4** endgame
+ owned-art swap → **M5** polish & multi-platform release.

## License

[MIT](LICENSE) for our code. The original game and its assets are **not** covered — see
the note at the bottom of the license and in CREDITS.md.

---

*Proudly Made in Nebraska. Go Big Red! 🌽 <https://xkcd.com/2347/>*
