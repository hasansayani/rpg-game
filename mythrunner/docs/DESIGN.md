# Mythrunner — Game Design Document (prototype v0.1)

## 1. Pitch
An Alto's Odyssey–style side-scrolling runner across **30 realms of world mythology**. You ride a glowing sky-board through each culture's landscape. Lumi, a Navi-style spirit guide, tells short, true stories about that culture as you ride. At the end of each realm you face (or outrun) its guardian. **Learning is a byproduct of play, never a gate.**

## 2. Decisions locked with the product owner
| Topic | Decision |
|---|---|
| Platform / engine | iOS, Swift + SpriteKit, no third-party dependencies. Must stay portable to Godot 4 (see `PORTING_GODOT.md`). |
| Structure | 30 realms = 30 levels, one culture each, balanced by continent: famous + lesser-known + extinct civilizations. |
| Guardian encounter | Three modes behind a Settings toggle. **Default: Chase & Escape.** Gauntlet and Weak Points are optional, and "Realm's Choice" mixes all three. |
| Audience | An age gate on first launch tunes visuals, difficulty and the companion's language (see §5). |
| Companion | One guide, Lumi, used in every realm. |
| Learning | Lumi speaks in non-blocking bubbles, and every line is saved to the Codex. The results screen recaps the stories and teases missed ones. |

## 3. Core loop
1. Choose a realm on the map. A title card shows the culture, the place and the era.
2. **Run phase** (~25–35 s): tap to jump, hold in the air to backflip. A clean landing gives a speed boost.
   - Hazards: rocks and chasms. Chasms are only ever placed on flat or downhill ground.
   - Collect 3 relics. The first one unlocks the relic's story.
   - Lumi tells 3 stories at fixed points along the course.
3. **Guardian phase**, in the mode chosen in Settings:
   - *Chase & Escape*: the guardian pursues you. Flips keep you ahead. Escape after 2,600 pt.
   - *Survive the Gauntlet*: dodge low projectiles (jump) and high ones (stay grounded) for 20 s.
   - *Strike the Weak Points*: jump into 3 glowing targets while dodging.
4. **Results**: relics, flips, and stories heard vs. undiscovered. Then Next realm, Retry or Map.
5. **Codex**: every story collected, grouped by region, available to reread at any time.

## 4. Controls & feel
- **Single input.** Tap = jump (0.12 s input buffer + 0.08 s coyote time). Hold = higher jump, then flip.
- **Auto-level.** When not flipping, the board straightens itself in the air. A plain jump never crashes, but a half-finished flip does.
- **Crest launch.** Fast riders pop off hilltops naturally, like in Alto.
- **Slope physics.** Downhill accelerates and uphill slows. Drag returns you toward the base speed.
- **Max terrain slope** is clamped to 0.9 (~42°), so content changes can never create an unrideable hill.

## 5. Age tuning (`Core/AgeTuning.swift`)
| | Sprout (<10) | Explorer (10–13) | Legend (14+) |
|---|---|---|---|
| Speed | 0.82× | 1.0× | 1.12× |
| Hearts | 5 | 3 | 3 |
| Obstacles / chasms | 0.5× / 0.4× | 1× / 1× | 1.3× / 1.25× |
| Landing tolerance | 60° | 46° | 37° |
| Palette | +20% saturation, +8% brightness | baseline | −12% saturation, darker |
| Fog / vignette | light / none | medium | heavy (moody) |
| Guardians | big friendly eyes | glowing eyes | glowing eyes + lightning |
| Lumi's text | simplified `kid` variant, 1.25× size, 1.4× longer on screen | standard | standard |

## 6. Content: 30 realms
Each realm entry in `Resources/realms.json` includes:
- a palette and a scenery spec (far‑ridge style, landmarks, weather)
- 3 facts and 1 relic story, each with `text` and `kid` variants
- a guardian

Region balance: Europe 6 · Africa 6 · Asia 6 · Americas 6 · Middle East 3 · Oceania 3. 19 are tagged "hidden gem" (lesser-known), 10 are famous anchors, and 9 are ancient or extinct civilizations. 20 are living traditions.

| # | Realm | Culture | Region | Guardian | Tags | Living tradition / review |
|---|---|---|---|---|---|---|
| 1 | Olympus Heights | Ancient Greek | europe | Talos (giant) | famous, ancient |  |
| 2 | Sands of the Two Lands | Ancient Egyptian | africa | Apep (serpent) | famous, ancient |  |
| 3 | Nine Worlds Ridge | Norse | europe | Fenrir (beast) | famous, medieval |  |
| 4 | Torii of the Rising Sun | Japanese (Shinto) | asia | Yamata no Orochi (serpent) | famous | ✓ |
| 5 | Feathered Serpent Causeway | Aztec (Mexica) | americas | Cipactli (beast) | famous, ancient |  |
| 6 | Hills of Samhain | Celtic (Irish) | europe | Balor of the Evil Eye (giant) | famous, medieval |  |
| 7 | Riverlands of the Vedas | Hindu | asia | Vritra (serpent) | famous | ✓ |
| 8 | Gates of Uruk | Sumerian & Babylonian | middleEast | Humbaba (giant) | ancient |  |
| 9 | Crown of Ilé-Ifẹ̀ | Yoruba | africa | Olókun's Flood (wave) | hidden gem | ✓ |
| 10 | Fish of Māui | Māori | oceania | Taniwha of the River (serpent) | hidden gem | ✓ |
| 11 | Jade Mountain Path | Chinese | asia | Nian (beast) | famous | ✓ |
| 12 | Popol Vuh Canopy | Maya | americas | Seven Macaw (bird) | famous, ancient | ✓ |
| 13 | Birchwood of Koschei | Slavic | europe | Koschei the Deathless (spirit) | hidden gem, medieval |  |
| 14 | Valley of the Storm Serpent | Zulu | africa | Inkanyamba (storm) | hidden gem | ✓ |
| 15 | Sedna's Ice Sea | Inuit | americas | Qalupalik (spirit) | hidden gem | ✓ |
| 16 | Ferdowsi's Peaks | Persian | middleEast | The White Div (giant) | hidden gem, medieval | ✓ |
| 17 | Fire Islands | Hawaiian | oceania | Lava Surge (wave) | hidden gem | ✓ |
| 18 | Sky Roads of the Andes | Inca | americas | Amaru (serpent) | famous, ancient | ✓ |
| 19 | Land of the Kalevala | Finnish | europe | Louhi the Eagle (bird) | hidden gem |  |
| 20 | Anansi's Web Forest | Akan (Asante) | africa | Sasabonsam (spirit) | hidden gem | ✓ |
| 21 | Eternal Blue Sky Steppe | Mongolian | asia | The Mangus (giant) | hidden gem, medieval | ✓ |
| 22 | Lion Gate of Hattusa | Hittite | middleEast | Illuyanka (serpent) | hidden gem, ancient |  |
| 23 | Birdman Isle | Rapa Nui | oceania | The Birdman Race (bird) | hidden gem | ✓ |
| 24 | Hurricane Coast | Taíno | americas | Juracán (storm) | hidden gem | ✓ |
| 25 | Hill Towns of Etruria | Etruscan | europe | Chimera of Arezzo (beast) | hidden gem, ancient |  |
| 26 | Cliffs of Bandiagara | Dogon | africa | The Harmattan (storm) | hidden gem | ✓ |
| 27 | Kamuy Forest | Ainu | asia | Northern Blizzard (storm) | hidden gem | ✓ |
| 28 | Seven Monsters Jungle | Guaraní | americas | Teju Jagua (beast) | hidden gem | ✓ |
| 29 | Moon-Eater's Sea | Filipino (Visayan) | asia | Bakunawa (serpent) | hidden gem | ✓ |
| 30 | Painted Rocks of the Kalahari | San | africa | The All-Devourer (spirit) | hidden gem, ancient | ✓ |
### Cultural-sensitivity rules (enforced in data)
- **Never make a living tradition's deity the enemy.** For living cultures, the guardian is a folk creature, a natural *force* (flood, lava, storm, the Harmattan) or a *trial* (the taniwha, the Birdman race).
- Every living-culture realm carries a `review` note. These are shown in debug builds only, as a reminder to get **cultural consultant sign-off before launch**.
- The Codex labels living traditions: "people practice and tell these stories today."
- Aboriginal Australian stories were deliberately left out of v0.1. They need direct community consultation, and are a candidate for a later realm made in partnership.

## 7. Success criteria & KPIs

### Prototype acceptance (this build)
| Criterion | Target | How it's verified |
|---|---|---|
| Realms playable end-to-end | 30/30 | Automated: `testAllRealmsBandsAndModesAreBeatable` runs 270 combinations (30 realms × 3 bands × 3 modes) |
| Content completeness | 30 × (3 facts + relic + guardian) × 2 reading levels = 300 lines | `testLoreIsCompleteAndBubbleSized` |
| Bubble readability | ≤150 chars standard, ≤110 kid | Same test |
| Determinism | Same course every run and every platform | `testDeterministicAndPlayable` |
| Frame rate | 60 fps on iPhone 12, 120 fps on ProMotion | Manual: Settings → "Show FPS & draw calls" |
| Draw calls | < 40 during play | Same overlay |
| Cold launch | < 2 s | Xcode Instruments (App Launch) |
| App size | < 30 MB (no image assets; art is procedural) | Archive size |

### Player KPIs (for playtests / TestFlight)
| KPI | Target | Why |
|---|---|---|
| Realm 1 completion rate | ≥ 80% | Onboarding works |
| Day-1 / Day-7 retention | ≥ 40% / ≥ 15% | Comparable to casual runners |
| Avg realms per session | ≥ 2 | The loop is compelling |
| Codex opens per session | ≥ 1 | Players care about the stories |
| **Recall quiz** (3 questions after 5 realms) | ≥ 60% correct | The learning goal is real, not decorative |
| Lumi "annoyance" rating (1–5, lower is better) | ≤ 2 | The guide helps, not nags |
| Guardian mode split | Track it; adjust the default if > 40% switch away from Chase | Validates the default choice |

### Content quality gate (pre-launch)
- Every fact traced to a published source (museum, academic or UNESCO). The current text was written for the prototype and **needs a fact-check pass**.
- Every living-culture realm signed off by a cultural consultant.

## 8. Roadmap options (pick next)
1. **Art pass.** Hand-painted silhouettes per realm, replacing procedural landmarks. *Pro:* big visual jump. *Con:* asset cost.
2. **Audio.** Per-realm ambient music using regional instruments, plus Lumi chimes. *Pro:* huge for mood (Alto's secret sauce). *Con:* licensing and composition.
3. **Recall quiz + "Myth Cards".** An optional 1-question quiz between realms that unlocks collectible cards. *Pro:* measures the learning KPI directly. *Con:* risk of feeling like school.
4. **Zen mode.** Endless and hazard-free, with only the stories, like Alto's Zen Mode.
5. **More realms.** Slavic → Baltic, Polynesian → Samoan/Tongan, Khmer, Tibetan, Korean, Ethiopian, Malagasy, Aboriginal Australian (with partnership), Celtic → Welsh, Basque, and more. The data-driven format makes each new realm cost one JSON entry.
6. **Godot port.** Only if Android becomes a goal (see `PORTING_GODOT.md`).
