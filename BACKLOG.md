# Backlog

Second view of the **Issues** tab — every item here should have a matching issue (and
vice versa). Repo is live: GitHub is canonical
(<https://github.com/CryptoJones/neuromancer-godot>), Codeberg is the mirror
(<https://codeberg.org/CryptoJones/neuromancer-godot>). Milestones are tracked as epic
issues #1–#5; file finer-grained issues as tasks are picked up and link them here.

## M0 — Scaffold & asset pipeline
- [x] Scaffold repo (dirs, LICENSE, README, CREDITS, BACKLOG, .gitignore, project.godot)
- [x] Port the `.DAT` resource-directory reader from `NEURO.EXE` (165 resources)
- [x] Implement the Huffman + RLE + scanline-XOR decode + 16-colour EGA palette
- [x] `.IMH` sprite/screen decode → PNG (28 images: TITLE, ENDGAME, cyberspace, AI faces…)
- [x] `.PIC` background decode → PNG (55 room backgrounds, 304×112)
- [x] Extract text resources (`.BIH`/`.TXH`) → `assets/text/game_text.json` (55 resources)
- [x] Verify decode: 144/144 resources decode, 0 failures, spot-checked vs original
- [ ] `.ANH` animation reassembly (decompresses; frame layout not yet rendered) — defer to M1
- [ ] `CONTRIBUTING.md` / project-structure doc for outside contributors

## M1 — Real-world engine (Chiba City vertical slice) ([#1](../../issues/1))
- [ ] `RoomController` + room data format; player movement between rooms
- [ ] `DialogEngine` reading extracted dialog; first NPC conversations
- [ ] PAX terminal (messages + news board)
- [ ] Basic inventory + real-world clock
- [ ] Chiba opening playable end-to-end on web export

## M2 — Economy & progression ([#2](../../issues/2))
- [ ] Credits, banks, chips; body shop (sell organs); pawn shops
- [ ] Skill chips & software shop; deck purchase/upgrade
- [ ] Skill system (Cyberspace I–VII, ICE Breaking, Hardware/Software Repair, …)
- [ ] Full real-world map traversal (Chiba → Night City → …)

## M3 — Cyberspace & ICE combat ([#3](../../issues/3))
- [ ] `MatrixNav` grid navigation + `Database` screens
- [ ] `IceCombat` turn-based engine; ICE types; skill-software effects; flatlining
- [ ] AI/construct interactions; data-fortress puzzles

## M4 — Endgame & owned-art swap ([#4](../../issues/4))
- [ ] Full story-flag graph to the finale + win scene
- [ ] Replace extracted assets with newly-authored, owned art/music (distributable build)

## M5 — Polish & release ([#5](../../issues/5))
- [ ] Save/load parity; settings; controller/touch input
- [ ] Web + desktop + mobile exports; itch.io / GitHub Pages release

---

*Proudly Made in Nebraska. Go Big Red! 🌽 <https://xkcd.com/2347/>*
