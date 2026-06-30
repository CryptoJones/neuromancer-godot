# Credits & Attribution

This remake stands on a great deal of prior work. Thank you to everyone below.

## Reverse engineering & reference ports

### Henadzi Matuts — *Reuromancer* + "Reversing the Neuromancer"
- Project: <https://github.com/HenadziMatuts/Reuromancer> (MIT License)
- Blog series: <https://henadzimatuts.github.io/2018/03/30/reversing-the-neuromancer-part-1.html>
- **What we use it for:** the documented `NEURO1.DAT` / `NEURO2.DAT` archive layout
  (resource tables embedded in `NEURO.EXE`), the two-stage `.IMH` image decompression
  (custom LZ-like pass + per-scanline delta/RLE), the 256-color VGA palette handling, and
  the `ResourceBrowser` exporter as a fallback asset-extraction path.

### maehem — *Javamancer*
- Project: <https://github.com/maehem/javamancer> (MIT License)
- **What we use it for:** a near-complete, winnable reference implementation of the full
  game. We consult it for dialog trees, cyberspace navigation, turn-based ICE combat
  rules, the economy, and the endgame/story-flag graph.

Both projects are MIT-licensed. Where we adapt their code, we retain their copyright and
license notices in the adapted files.

## Original game

**Neuromancer** (Interplay Productions, 1988), based on the novel *Neuromancer* by
**William Gibson** (1984).

- Design: Bruce Balfour, Brian Fargo, Troy A. Miles, Michael A. Stackpole
- Publisher/Developer: Interplay Productions

The original game, executable, data files, and all assets contained within them remain
the property of their respective rights holders. This project redistributes **none** of
them; players supply their own original data files to run the asset-extraction tooling.

## This remake

- Code & new assets: Aaron K. Clark (CryptoJones), 2026 — [MIT](LICENSE).

---

*Proudly Made in Nebraska. Go Big Red! 🌽 <https://xkcd.com/2347/>*
