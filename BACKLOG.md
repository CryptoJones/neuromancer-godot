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
- [x] `CONTRIBUTING.md` / project-structure doc for outside contributors

## M1 — Real-world engine (Chiba City vertical slice) ([#1](../../issues/1))
- [x] Runtime asset loader (`Assets.gd`, `Image.load` — no import pipeline)
- [x] Room graph + data format (`data/rooms/chiba.json`); movement (buttons + WASD/arrows)
- [x] Rooms render extracted backgrounds + real `.BIH` prose (Chatsubo, Body Shop, Justice…)
- [x] `DialogEngine` + first NPC conversation (Ratz, data-driven)
- [x] Real-world clock + status HUD; `SaveSystem` JSON round-trip
- [x] Title → name-entry → explore loop; headless smoke test + visual tour
- [x] Owned HD art swap (FLUX.2 plates), crisp-text (MSDF) + pixelated-plate render (canvas_items)
- [x] **Faithful full map: 56 rooms** ported from Javamancer `RoomMap` (real names + real exits); room prose from `R*.BIH`
- [x] Inventory UI (gear/software/skills screen)
- [x] PAX terminal — **owned** news + BBS (`data/pax/*.json`), our writing in the original's tone; ships standalone (no BYO). Booths R1/R7/R8/R12/R41
- [x] **Owned room descriptions** — all 56 rooms (`data/rooms/descriptions.json`), our prose; drops the original-text dependency (Chromebook reads them from a clean clone)
- [ ] Web export build + verify end-to-end

> **REMASTER fidelity rule:** the game must match the 1988 original (rooms, dialogue,
> shops, items, prices, logic) — only the art/presentation is modernised. Earlier
> *invented* content (improvised map, Deane/Shin dialogue, made-up item/shop tables)
> is being replaced with the originals from Javamancer + the extracted text.
>
> **Standalone model (2026-06-30):** keep the GAME identical to the original (rooms,
> map, quests, mechanics, shop stock, prices, ICE, win graph) — those are facts you
> stay faithful to; but AUTHOR OUR OWN PROSE for everything displayed (room
> descriptions, NPC dialogue, news, BBS). Copyrighted text is never shipped, so the
> game runs with NO original `.DAT` files. (PAX done; room descriptions + dialogue next.)

## M2 — Economy & progression ([#2](../../issues/2))
- [x] Economy ENGINE: `Catalog.gd` + Shop / Inventory / Organ-Bank menu UI (buy/sell, half-price resale)
- [x] **Real Body Shop** (R4): 20 authentic body parts + prices + CON costs (`data/bodyparts.json` from `BodyPart.java`); constitution on the real 0–2000 scale; sell + buy-back
- [x] **Real hardware shops**: the 20 authentic cyberdecks + prices (`Blue Light Spec.` 1000 … `Cyberspace VII` 56000), Crazy Edo's (R40, 8 decks) + Asano's (R44, 17), from `*DeckItem.java` + `ItemCatalog`
- [ ] Real **warez/software** tables + prices (Larry's R12, Metro Holografix R32) + **skills** vendor + prices (Microsofts)
- [ ] Deck cyberspace-capable flag (Edo's decks are non-cyberspace; Asano's higher decks are) + per-deck RAM/specs
- [ ] Wire shops to their real rooms (Shin's R25, Crazy Edo's R40, Asano's R44, Microsofts, Body Shop R4)
- [ ] Real NPC dialogue trees (Ratz, Julius Deane, Shin, …) from the original
- [ ] Banks (Bank of Berne / Gemeinschaft), skill *use* / levelling, cyberspace economy

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
