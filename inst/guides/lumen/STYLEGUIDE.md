# Lumen: styleguide

**Lumen** is the Taiga framework for *showcase* products: cinematic, high-contrast, glass-driven
interfaces that present results to people, tell a story, or run a studio. This guide is extracted from
the four Lumen codebases. It describes what they actually do, with the values they actually use, and
turns that into rules for future projects.

| App | What it is | Canonical stylesheet(s) | Default theme |
|---|---|---|---|
| **QuantSkill** 2.3.0 | Adaptive skills assessment (Shiny · Quarto · HTML) | `srcjs/css/quantskill.css` | Daylight (light), true-black dark |
| **lumenJourney** 0.3.0 | Clinical study story (Shiny · Quarto · HTML · PDF) + a teal app | `inst/story/lumen-story.css` | Cinema (dark), paper light |
| **DirectoR** 0.1.3 | Studio that directs launch films for apps | `inst/app/www/director.css` (+ `inst/engine/stage/stage.css`) | Studio dark only |
| **RockShiny** 0.1.0 | Note-highway music player | `inst/app/app.css`, `inst/highway/highway.css` | Stage dark only |

Numbers in this guide come from `tools/extract_tokens.py` (→ `inst/extdata/tokens/*.json`, `summary.md`; in R: `taiga_extracted()`)
and `tools/contrast_audit.py` (→ `inst/extdata/tokens/contrast.md`; in R: `taiga_contrast_audit()`). Re-run them after the apps change.
A starter token sheet for new projects is in [`lumen-tokens.css`](../../css/lumen-tokens.css).

---

## 1. Principles

1. **Cinematic.** Every app has a *set*: a deep canvas (`#000`, `#07070a` or `#0b0d13`) or an off-white
   one (`#fbfbfd`, paper `#f8f7f3`). Ambient light comes from slow radial glows, and a headline is set in
   display type with a gradient on the key words. Each screen composes like a frame of a film.
2. **High contrast where it counts.** Primary text sits at 15:1 to 19:1 against the canvas in every
   Lumen theme. Hierarchy comes from size, weight and tracking. Muted greys are kept for secondary text.
3. **Glass for everything that floats.** Navigation, docks, HUDs, cards over content and sheets are
   translucent (about 72 % opaque), blurred (10–22 px) and saturated (140–180 %), with a hairline
   border. Content that sits *in* the page stays solid.
4. **One accent, one gradient.** Each app owns one saturated accent, and optionally one gradient,
   used for primary actions, focus and highlighted words. Semantic colours (good, warn, bad) never double
   as brand colour.
5. **Motion tells the story.** Entrances rise, numbers count up, scroll drives narrative (journey
   steps, radar morphs), and springy feedback confirms actions. Motion always has a still fallback.
6. **Self-contained.** Every Lumen front end is a dependency-free bundle: no CDN, no framework, and fonts
   inlined or from the system. This is what allows the triple-format delivery
   ([`../DELIVERY_MODEL.md`](../DELIVERY_MODEL.md)).

### Gallery

| | |
|---|---|
| ![QuantSkill landing](../../../../QuantSkill/docs/features/01-landing.jpg) QuantSkill: daylight glass hero | ![Study story hero](../../../../lumenJourney/docs/features/01-hero.jpg) lumenJourney: cinema hero |
| ![DirectoR library](../../../../DirectoR/docs/features/01-library.jpg) DirectoR: studio dark | ![RockShiny highway](../../../../RockShiny/docs/features/01-highway.jpg) RockShiny: stage dark |
| ![QuantSkill dark](../../../../QuantSkill/docs/features/02-landing-dark.jpg) True-black dark theme | ![Study story journey](../../../../lumenJourney/docs/features/03-journey.jpg) Scroll-driven storytelling |

---

## 2. Colour

### 2.1 Canvases and surfaces

Lumen has two *daylight* palettes (Apple-like neutrals) and three *night* palettes (cinema, studio and
stage).

| Role | QuantSkill light | QuantSkill dark | Story dark (default) | Story paper (light) | DirectoR studio | RockShiny stage |
|---|---|---|---|---|---|---|
| Canvas | `#fbfbfd` | `#000` | `#000000` | `#f8f7f3` | `#07070a` | `#0b0d13` → radial `#1a2035` |
| Canvas 2 | `#f5f5f7` | `#0f0f11` | `#101012` | `#f2f0ea` | `#0c0c11` | `rgba(16,19,27,.85)` (sidebar) |
| Canvas 3 / fill | `#ececf0` | `#1b1b1e` | `#161618` | `#fffefb` | `#111118` | `#141824` (inputs) |
| Card (solid) | `#ffffff` | `#1c1c1e` | `#1c1c1e` | `#fffefb` | gradient `rgba(255,255,255,.045→.02)` | `#151a27` |
| Card (glass) | `rgba(255,255,255,.72)` | `rgba(28,28,30,.72)` | `rgba(22,22,23,.72)` | `rgba(248,247,243,.8)` | `rgba(8,8,11,.72)` (rail) | `rgba(14,17,26,.72)` (HUD) |
| Hairline | `rgba(0,0,0,.08)` | `rgba(255,255,255,.10)` | `rgba(255,255,255,.10)` | `rgba(45,40,28,.10)` | `rgba(255,255,255,.075)` | `rgba(255,255,255,.09)` |
| Text 1 | `#1d1d1f` | `#f5f5f7` | `#f5f5f7` | `#1c1b18` | `#f4f4f6` | `#eef0f6` / `#e8eaf1` |
| Text 2 | `#6e6e73` | `#a1a1a6` | `#a1a1a6` | `#5d5b55` | `#a1a1ad` | `#9aa3b8` |
| Text 3 | `#86868b` | `#6e6e73` | `#86868b` | `#8e8b84` | `#6e6e7a` | `rgba(232,234,241,.45)` |

DirectoR layers *white at low alpha* over its canvas (`--panel .032 / .055 / .085`,
`--line .075 / .13 / .2`) instead of fixed greys. Use that approach for dark-only studio tools, because
surfaces stay consistent over the ambient glows.

### 2.2 Accent, gradient, semantic

| App | Accent | Gradient (type, logo, primary button) | Good / Warn / Bad |
|---|---|---|---|
| QuantSkill | `#0071e3` (dark `#0a84ff`), second `#7c3aed` | blue → violet → pink (`#2563eb → #7c3aed → #db2777`), per-area category colours (`--cat`) | `#1f9d55` / `#d97706` / `#e5484d` (dark `#32d74b` / `#ffb340` / `#ff6961`) |
| lumenJourney | `#0071e3` (dark `#2997ff`, paper `#0a62c9`) | hero title blue → violet; bokeh `10,132,255` · `191,90,242` · `255,55,95` · `94,92,230` · `100,210,255` · `255,159,10` · `48,209,88` | `#1a9e49` / – / `#e0362c` (dark `#32d74b` / `#ff453a`) |
| DirectoR | `#a855f7` (Bootstrap primary) | `--grad: linear-gradient(120deg, #6366f1 0%, #a855f7 48%, #ec4899 100%)`, plus `--a4 #f59e0b` | `#34d399` / `#fbbf24` / `#f87171` |
| RockShiny | `#f5a524` (amber; text on it `#1a1206`) | logo `#ffc46b → #f08a00` | `#4ade80` / `#facc15` / `#ef4444` |

**Instrument colours (RockShiny).** Strings are `#e8203a` (E), `#f2d40c` (A), `#1f9cf0` (D),
`#f5891d` (G), `#22c55e` (B) and `#b04ee6` (e), fixed in `renderer.js` (`STRING_COLORS`). Domain
colours like these live in code, not in the UI token sheet, and never change with the theme.

### 2.3 Ambient light

- **Blobs** (QuantSkill `.qs-blob`): three 60 vmax circles (`#2563eb`, `#a855f7`, `#f97316`),
  `filter: blur(90px)`, opacity .22 (.30 dark), drifting over 26, 30 and 34 s alternate loops.
  They dim to .12 in focus mode.
- **Glows** (DirectoR `body.dr::before`): three radial gradients (indigo .16, purple .13, pink .09)
  drifting over 30 s.
- **Bokeh** (story `.ls-bokeh`): twelve coloured dots (RGB triplets above) that rise in and drift.
- **Grain**: an SVG `feTurbulence` overlay at 3.5 % opacity (`.qs-grain`).
- **Stage** (RockShiny): one fixed radial gradient (`#1a2035 → #0b0d13`), with no animation so the
  highway stays readable.

Ambient layers are `position: fixed`, `pointer-events: none`, `z-index: -1` or `0`, and must be
switched off or frozen for screenshots and video capture (QuantSkill's recorder replaces blurs with
look-alike masks; see §6.3).

### 2.4 Contrast rules (from `inst/extdata/tokens/contrast.md`)

| Pair | Ratio | Rule |
|---|---|---|
| Text 1 on canvas (all themes) | 15.6 – 19.3 | Body text, headings: always. |
| Text 2 on canvas | 4.9 – 8.2 (QuantSkill light on `--bg-3`: **4.30**) | Secondary text. Not on `--bg-3` fills for small text. |
| Text 3 on canvas | 3.1 – 4.1 (story paper: **3.17**; DirectoR `--dim`: **4.00**) | Large text (≥ 24 px, or ≥ 18.7 px bold), captions next to a stronger label, placeholders. Never the only carrier of information. |
| White on QuantSkill dark accent `#0a84ff` | **3.65** | Large or bold button labels only (the 17 px, 550 weight `.is-lg` buttons). |
| White on DirectoR `--a1` / `--a2` | 4.47 / **3.96** | The gradient button needs ≥ 15 px semibold (it uses 13.5–15 px, 600): keep labels short and bold. |

New projects **must** keep text 3 for large or decorative text only, and check every accent they use for
filled buttons against white (≥ 4.5:1 for 14 px labels).

---

## 3. Typography

| | QuantSkill | lumenJourney | DirectoR | RockShiny |
|---|---|---|---|---|
| UI family | `-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Inter", "Segoe UI", Roboto, "Helvetica Neue", Arial` | same stack (dark); paper theme: `"Helvetica Neue LT Pro"…"Helvetica Neue", Helvetica` | `"Inter"` (self-hosted woff2, 100–900), `font-feature-settings: 'cv11','ss01','ss03'` | `Inter, system-ui, …` (bslib `font_collection`) |
| Mono | `ui-monospace, "SF Mono", SFMono-Regular, Menlo, Consolas, "Liberation Mono"` | – | `"SF Mono", "JetBrains Mono", Menlo, Consolas` | `ui-monospace, SFMono-Regular, Menlo` |
| Base size | 17 px, line-height 1.47, tracking −.011em | 17 px, line-height 1.47, tracking −.012em | 14 px, line-height 1.45, tracking −.006em | `.9rem` |
| Display | `clamp(52px, 9.2vw, 112px)`, weight 700, lh .98, tracking **−.045em** | hero `clamp(44px, 8.4vw, 104px)`, −.045em | hero `clamp(40px, 5.6vw, 76px)`, weight **780**, −.05em | brand 1.15 rem, 800 |
| H1 / H2 | `clamp(36px, 5vw, 56px)` / `clamp(32px, 4.6vw, 56px)`, −.035em | section title `clamp(40px, 6vw, 72px)`, −.04em | page head 28 px, 750, −.035em | card title 16 px, 750 |
| Lede | `clamp(18px, 2vw, 22px)`, lh 1.42 | `clamp(19px, 2.2vw, 24px)`, lh 1.4 | 17 px (`.sublead`) | – |
| Eyebrow / caps | `.qs-eyebrow` 13 px, 600, +.02em, sentence case | `.ls-kicker` 12 px caps, 600, +.06em (paper theme: eyebrows 13 px caps, 500, +.14em) | eyebrow = pill with a gradient "NEW" badge (11 px, 650); step labels 11 px caps, 700, +.08em | brand sub `.72rem` caps, +.12em |

Rules:

- **Display type is tight and heavy.** Use −.035em to −.05em tracking and weight 700–780, with
  line-height ≤ 1.05. Set the key words in the gradient (`background-clip: text`), never the whole line.
- **Weights in use** (by frequency): 600, 650, 700 and 750 for UI; 500–550 for buttons; 400 for body.
  The story's paper theme is the exception. It is editorial, not cinematic: hero title 200, titles and
  leads 300, stat numbers 200 with lining tabular numerals.
- **Numbers.** `font-variant-numeric: tabular-nums` for stats, timers and scores (`.ls-stat-num`,
  `.ls-tile-big`).
- **Fonts never come from a CDN.** DirectoR ships Inter, QuantSkill relies on the system stack, and
  QuantSkill's video pipeline inlines Inter as base64.

---

## 4. Shape, elevation and glass

### 4.1 Radii

| Token | QuantSkill | lumenJourney | DirectoR | RockShiny |
|---|---|---|---|---|
| XL (sheets, hero cards) | `--r-xl 34px` | `--ls-radius 28px` (paper 22) | – | 18 px |
| L (cards) | `--r-l 26px` | 22–24 px | `--r 16px` | 14–16 px |
| M (controls, tiles) | `--r-m 18px` | 14 px | `--r2 12px` | 12 px |
| S (chips, inputs) | `--r-s 12px` | 8–10 px | `--r3 10px`, buttons 11 px | 10 px / `.55rem` |
| Pill | `999px` (buttons, chips, nav links) | `999px` | `999px` (chips) | `999px` |

Buttons are **pills** in QuantSkill and the story, and **rounded rectangles** (11 px) in DirectoR.
Choose one per app. Never mix the two for the same action level.

### 4.2 Shadows

- Daylight (QuantSkill): `--shadow-1: 0 1px 2px rgba(0,0,0,.04), 0 8px 24px rgba(0,0,0,.06)`,
  `--shadow-2: 0 2px 6px rgba(0,0,0,.05), 0 30px 70px rgba(0,0,0,.13)`.
- Night: the same geometry at .4–.6 alpha. DirectoR
  `--shadow: 0 24px 60px -24px rgba(0,0,0,.7), 0 1px 0 rgba(255,255,255,.04) inset` (an inner
  top highlight makes dark cards read as glass).
- **Coloured glow for primary actions**: `0 10px 28px -10px rgba(168,85,247,.85)` (DirectoR) or
  `0 6px 20px -6px color-mix(in srgb, var(--accent) 70%, transparent)` (QuantSkill). The glow
  grows on hover.

### 4.3 The glass recipe

```css
.glass {
  background: var(--card);                            /* ~72% opaque surface colour */
  backdrop-filter: blur(20px) saturate(170%);         /* 10-22px blur, 140-180% saturate */
  -webkit-backdrop-filter: blur(20px) saturate(170%);
  border: 1px solid var(--line);                      /* hairline, 8-10% */
  box-shadow: var(--shadow-1);
}
@supports not ((backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px))) {
  .glass { background: var(--card-solid); }           /* lumenJourney ships this fallback */
}
```

| Where glass is used | Blur / saturate |
|---|---|
| Sticky nav after scroll (QuantSkill `.is-scrolled .qs-nav`, story `.ls-nav`) | `saturate(180%) blur(20px)` |
| Quiz top bar and answer dock (QuantSkill) | `blur(20px) saturate(170%)` |
| Cards over ambient light (`.qs-card`, `.qs-results-overall`) | `blur(20px) saturate(160%)` |
| Studio rail and top bar (DirectoR) | `blur(20px)`, `blur(18px)` |
| Highway HUD: song card, section pill, transport (RockShiny) | `blur(10px) saturate(140%)` |
| Modals and scrims | `blur(6–8px)` over `rgba(0,0,0,.35)` |

Counts from the stylesheets: QuantSkill 18 and lumenJourney 18 `backdrop-filter` declarations,
DirectoR 8, RockShiny 4. **Glass is a signature, not a texture**: only surfaces that float over
moving or layered content get it.

---

## 5. Motion

| Token | Value | Use |
|---|---|---|
| `--ease` (`--ls-ease`) | `cubic-bezier(.2, .8, .2, 1)` | Default for everything. Used 27× in QuantSkill, 48× in the story, 2× plus variants in DirectoR. |
| `--spring` | `cubic-bezier(.34, 1.56, .64, 1)` | Confirmations: buttons, icons, badges, logo hover (32× in QuantSkill). |
| DirectoR spring | `cubic-bezier(.2, .9, .3, 1.4)` | Logo and choice-card pop. |
| Fast | `.2s` – `.25s` | Hover, colour, background. |
| Medium | `.3s` – `.55s` | Entrances (`qs-view-in`, `pgIn` .45 s), sheets. |
| Slow | `.7s` – `1.1s` | Hero rise (`ls-rise` 1.1 s), count-ups (900 ms cubic out). |
| Ambient | 26 – 34 s alternate | Blobs and glows. |

Signature animations: `qs-view-in` / `pgIn` (rise 10–16 px and fade); view transitions
(`::view-transition-old/new(qs-main)`); count-up numbers; scroll-driven story steps (the journey's
dot grid re-sorts per step); `qs-correct`, `qs-shake` and `qs-medal` feedback; confetti for
achievements; the studio's transition demos (`trFade`, `trWipe`, `trIris`…).

Rules:

- **Every animation has a still state.** QuantSkill and the story implement
  `@media (prefers-reduced-motion: reduce)`. DirectoR and RockShiny do not yet (see requirements).
- **Capture-friendly.** Animations are CSS or Web Animations so a recorder can pause and seek them
  (QuantSkill's `recorder.py` freezes every animation on start and advances it frame by frame), and
  `Math.random` is only used where a seeded replacement is acceptable.

---

## 6. Layout

| | QuantSkill | lumenJourney | DirectoR | RockShiny |
|---|---|---|---|---|
| Frame | Centered column `--maxw 1120px`, sticky 52 px nav | Full-bleed sections, sticky 52 px nav, floating filter pill | App shell: 84 px rail, 64 px top bar, scrolling page (`.pg` max 1680 px) | bslib `page_sidebar` (340 px), full-height highway card |
| Breakpoints | 720, 980 px | 480, 520, 720, 820, 900, 1020 px | 1100 px | (fluid canvas) |
| Density | Airy: 26 px card padding, 50 px large buttons | Airy: 28 px radius tiles, 56 px stat spacing | Medium: 38 px buttons, 16–18 px card padding | Compact sidebar (`.9rem`), immersive stage |

### 6.1 Z-order (observed)

Ambient −1 → content → sticky nav 50 → overlays 60–100 → toasts 200–300 → capture layers 100001+.

### 6.2 Print

The story ships 11 print rules (a journal-style article) and QuantSkill 2 (its PDF report is generated
separately). Long-form Lumen pages **should** print cleanly: ambient light and glass off, solid
surfaces, page breaks between sections.

### 6.3 Capture

Screenshots and videos are first-class deliverables of a Lumen app (QuantSkill and DirectoR exist
partly to make them). Keep heavy effects switchable: QuantSkill's recorder injects `CAPTURE_CSS`
(blobs unblurred, grain hidden, card blurs removed) so frames render fast and identically.

---

## 7. Components

### 7.1 Inventory

| Family | QuantSkill (`.qs-*`, 114 roots) | lumenJourney (`.ls-*`, 118 roots) | DirectoR (`body.dr`) | RockShiny (`.rs-*`) |
|---|---|---|---|---|
| Navigation | `nav`, `nav-link` (active: 16 px underline), `mode-chip`, `menu-sheet` | `ls-nav`, section links, `ls-pill-btn`, `ls-badge` ("Fictitious study") | `dr-rail` + `dr-nav` (glowing gradient bar on active), `dr-top` (crumb, title input, chips) | bslib navbar brand, `rs-shortcuts` |
| Hero | `qs-display` + gradient, `qs-orbit` (12 category tiles), CTA pair | `ls-hero-title` (gradient), count-up `ls-stats`, area chips | `.hero` + `.omni` (link field with inline CTA), `.dropzone`, segmented options, 5-step `.how` | album-art song card |
| Buttons | `qs-btn` (`is-primary`, `is-ghost`, `is-white`, `is-lg/sm`, `is-loading`), `qs-icon-btn` | `ls-pill-btn` (`ls-accent`), `ls-icon-btn` | `dr-btn` (`primary` gradient, `ghost`, `white`, `danger`, `lg/sm/xs`, `icon`) | Bootstrap `.btn-outline-primary`, transport buttons |
| Selection | `qs-seg`, `qs-pick` (toggle cards), `qs-rate` (0–10 self-rating), `qs-stake` (confidence) | `ls-seg`, `ls-chip`, `ls-select`, `ls-switch`, `ls-range` | `dr-choices` (cards with a visual preview, or segmented), `dr-switch`, `dr-color` | accordion panels, `form-switch`, sliders |
| Cards | `qs-card` (glass), `qs-bento` (tilt on pointer, `--rx/--ry/--mx/--my`), `qs-qcard` | `ls-card`, `ls-tile` (big numbers), `ls-verdict`, `ls-insight` | `.card` (`.hd`/`.bd`, icon tile, `.glow` gradient border), `.film` poster cards, `.empty`, `.note` | `rs-hw-card` (glass HUD), `rs-stage` card |
| Data viz | radar (predicted vs measured), heatmap, scatter, KPI ring, XP, badges | dot grid (one dot per patient), age pyramid, flags, KM curves with censor marks, forest, AE bars, Sankey, gauge, sparklines | EQ bars (music moods), waveform, transition demos | 3-D highway (canvas or DOM/SVG), fretboard, keyboard and harp lanes, section timeline |
| Overlays | `qs-modal`, `qs-toast`, `qs-confetti`, offline banner | `ls-sheet` (setup, patient record), `ls-tip`, `ls-toast`, `ls-drawer` | `#dr-dock` (progress ring, log), `#dr-toasts`, `#dr-auto` (autopilot), preview player iframe | countdown, results card, banner |

### 7.2 Anatomy of the shared patterns

- **Primary button.** A pill (or 11 px radius) 40–50 px tall with a 15–17 px, 550–600 label, filled with
  the accent or gradient, a coloured glow shadow, and a trailing icon that nudges +3 px on hover.
  `:active` scales to .96–.97.
- **Glass HUD card.** Absolute inside a stage, 14 px from the edges: 12 px radius, `--glass`, blur
  10 px, `inset 0 0 0 1px var(--line)`. Title 16 px/750, meta 12 px muted, tags as 999 px chips.
- **Choice card** (DirectoR `dr-choices.cards`). A grid with `--min` column width, each card holding a
  visual (`.vis`), a title (`.t`) and a subline (`.s`). Active: gradient-tinted background, a purple
  inset ring and a check badge.
- **Chip.** 26 px (QuantSkill) or 4 × 10 px padding (DirectoR), 999 px radius, 12–12.5 px/550–600.
  Variants `accent`, `good`, `warn`, `bad` tint the border and a 6–12 % background.
- **Big number tile.** Tabular numerals, display tracking, a unit in muted small type, and a mini chart
  (bar, dots or sparkline) underneath.

---

## 8. App dialects

- **QuantSkill: Daylight glass.** Light by default, Apple-like neutrals, drifting blobs, glass cards,
  pills, per-area category colours, gamification (XP, streaks, badges, confetti), view transitions.
  True-black dark theme.
- **lumenJourney: Cinema story.** Dark by default (`data-theme="dark"`), full-bleed chapters, gradient
  hero, count-ups, one-dot-per-patient storytelling, a floating glass filter pill. The *paper* light
  theme (`#f8f7f3`, Helvetica Neue, hairline shadows `--ls-hair`) is the print-like editorial variant.
- **DirectoR: Studio dark.** Dark only, Inter, white-alpha panels, an indigo → purple → pink gradient
  for brand and primary actions, a left rail with glowing active state, rich choice cards with live
  visual previews.
- **RockShiny: Stage dark.** A bslib theme (`bg #0b0d13`, `fg #e8eaf1`, `primary #f5a524`) around an
  immersive canvas. Chrome is quiet, the stage is loud (instrument colours), and the HUD floats as
  glass on the stage.

| ![Story glance](../../../../lumenJourney/docs/features/02-glance.jpg) | ![Story paper](../../../../lumenJourney/docs/features/10-light-efficacy.jpg) | ![DirectoR story](../../../../DirectoR/docs/features/04-story.jpg) | ![RockShiny loop](../../../../RockShiny/docs/features/03-practice-loop.jpg) |
|---|---|---|---|
| Glass tiles, big numbers | Paper theme | Studio: cards + live preview | Stage: HUD + loop |

---

## 9. Do and don't

| Do | Don't |
|---|---|
| Start from a deep or off-white canvas and add one ambient layer. | Put glass on content that does not float. |
| Put the gradient on 1–3 key words of a display line. | Gradient whole paragraphs, buttons *and* headings on one screen. |
| Keep text 1 for anything the reader must read. | Use text 3 (3–4:1) for body copy or data labels. |
| Give every animation a reduced-motion still. | Tie meaning to motion alone (counting numbers end on the true value). |
| Ship fonts and assets inside the bundle. | Load fonts, icons or scripts from a CDN. |
| Make heavy effects switchable for capture and print. | Let `backdrop-filter` stack more than two layers deep. |
| Use domain colours (strings, arms, areas) from code constants. | Reuse semantic red and green as brand colours. |
