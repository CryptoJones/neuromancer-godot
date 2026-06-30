# extract_dat — Neuromancer (1988) asset extractor

A one-time tool that unpacks the original Interplay *Neuromancer* (DOS, 1988)
`.DAT` archives into PNG images + JSON for the Godot remake.

> **Bring your own game files.** This tool ships **no** copyrighted data. You
> must supply your own `neuro.exe`, `neuro1.dat`, and `neuro2.dat` from a copy
> of the original game. Extracted assets are written into the (git-ignored)
> `assets/` folders and must not be committed.

## Usage

```bash
# From this directory, with the original files two levels up (defaults):
python3 extract.py

# Or point at your own files / output dir:
python3 extract.py \
  --exe  /path/to/neuro.exe \
  --dat1 /path/to/neuro1.dat \
  --dat2 /path/to/neuro2.dat \
  --out  ../../assets

# Also parse + cross-check the EXE resource directory:
python3 extract.py --validate-exe
```

No dependencies — Python 3 standard library only. PNGs are written with a tiny
built-in `zlib`+`struct` writer (Pillow is not required).

## What it produces

| Input type | Output |
|------------|--------|
| `.PIC` background | `assets/backgrounds/<NAME>.png` (304×112, 16-colour) |
| `.IMH` sprite/screen | `assets/sprites/<NAME>.png` (sub-images stacked vertically) |
| `.BIH` / `.TXH` | readable strings collected into `assets/text/game_text.json` |
| palette | `assets/palettes/ega16.json` |
| `.ANH` | validated (decompresses) but not rendered |
| `.BIN` / `.NMC` / `.SAV` | skipped (code / config / saves) |

## Format notes (how the decode works)

The directory is `struct { char name[14]; uint32 offset; uint32 size; }` records
in the EXE, one table per `.DAT` file. Each resource is a Huffman-compressed blob:

1. **Huffman** — 4-byte LE decompressed length, a bit-packed tree, then the
   bitstream. For `.PIC`/`.IMH` the Huffman stream starts at **`offset + 32`**
   (a 32-byte header precedes it); for `.BIH`/`.ANH`/`.TXH` it starts at `offset`.
2. **RLE** — `b > 0x7F` → literal run of `0x100 - b` bytes; else run of `b + 1`
   copies of the next byte.
3. **Scanline XOR** — each row is XORed with the row above it.
4. **Pixels** — the result is 4bpp packed (two 16-colour pixels per byte).
   `.PIC` images are a fixed 152×112 bytes → 304×112 pixels. `.IMH` images carry
   per-sub-image `dx,dy,width,height` headers (width in bytes).

## Credits

The `.DAT` format and its decompression were reverse-engineered by others; this
script is a faithful Python **port** of their work (both MIT-licensed):

- **Henadzi Matuts** — [Reuromancer](https://github.com/HenadziMatuts/Reuromancer)
  and the ["Reversing the Neuromancer"](https://henadzimatuts.github.io/2018/03/30/reversing-the-neuromancer-part-1.html)
  blog series. Primary source for the Huffman+RLE+XOR decode, the `+32` PIC/IMH
  offset, the 152×112 PIC geometry, and the resource directory.
- **Mark J. Koch (@maehem)** — [Javamancer](https://github.com/maehem/javamancer).
  Reference for the 4bpp palette mapping.
- Original game © 1988 Interplay Productions.

This port is released under the MIT License.

*Proudly Made in Nebraska. Go Big Red! 🌽 <https://xkcd.com/2347/>*
