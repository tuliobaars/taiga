# Lumen: requirements for new projects

These are requirements for any new Taiga project built on the **Lumen** framework. They are derived from
QuantSkill, lumenJourney, DirectoR and RockShiny: what those apps do well becomes a requirement, and what
they lack becomes a gap (§10). The key words MUST, SHOULD and MAY follow RFC 2119. The visual reference
is [`STYLEGUIDE.md`](STYLEGUIDE.md). The delivery reference is [`../DELIVERY_MODEL.md`](../DELIVERY_MODEL.md).

## 0. When to choose Lumen

Choose **Lumen** when the product *presents*: results to a non-technical audience, a narrative, a
guided flow (assessment, story, player), or a creative studio where the output is the star. Choose
**Neue** ([`../neue/REQUIREMENTS.md`](../neue/REQUIREMENTS.md)) when people *work* in the product for hours
with dense data, many modules and reproducible outputs.

| Signal | Lumen | Neue |
|---|---|---|
| Primary reader | Stakeholders, candidates, players, clients | Analysts, programmers, statisticians |
| Session shape | Minutes, guided, linear or story | Hours, self-directed, non-linear |
| Screen density | Low to medium: one idea per view | High: many controls and outputs per view |
| Visual voice | Cinematic: deep canvas, glass, gradients, motion | Instrument: ruled panels, one accent, mono figures |

## 1. Product and content

| ID | Requirement | Evidence |
|---|---|---|
| LUM-P-01 | The product MUST have a single headline promise, shown as display type on its first screen (for example "Skills, measured." or "Your app deserves a launch film."). | QuantSkill hero, DirectoR library, story hero |
| LUM-P-02 | Every number shown to a non-technical reader MUST be explained in plain language next to it, and MUST end on its true value (count-ups included). | Story "At a glance", QuantSkill results |
| LUM-P-03 | Claims in the UI, README and marketing material MUST be supported by the code. Illustrative content MUST be labelled as such ("Fictitious study", "illustrative" charts). | Story badge "FICTITIOUS STUDY"; QuantSkill `media/README.md` |
| LUM-P-04 | A guided flow SHOULD be resumable (resume code, saved state) when it takes more than a few minutes. | QuantSkill resume codes, snapshots |

## 2. Delivery

| ID | Requirement |
|---|---|
| LUM-D-01 | The project MUST ship Shiny, Quarto and standalone HTML from one front end, meeting DLV-01 to DLV-32 of the [delivery model](../DELIVERY_MODEL.md). |
| LUM-D-02 | The standalone HTML MUST be a first-class deliverable: shareable by e-mail, offline, with the full look (ambient light, glass, motion). |
| LUM-D-03 | The README MUST contain a "Delivery formats" table: entry points and capability matrix. |
| LUM-D-04 | Long-form story products SHOULD also print (print stylesheet) or export to PDF (`export_story_pdf()` precedent). |

## 3. Visual foundations

| ID | Requirement | Reference |
|---|---|---|
| LUM-V-01 | Styles MUST live under one root class with CSS custom properties for every colour, radius, shadow, easing and layout constant (`.qs { --bg … }`, `.lumen-story { --ls-* }`). Components MUST NOT use raw hex values for themeable colours. | STYLEGUIDE §2 |
| LUM-V-02 | The product MUST ship a light ("daylight" or "paper") and a dark ("cinema") theme, unless it is a studio or stage tool that is dark by nature (DirectoR, RockShiny). The default MUST suit the first screen's job (story: cinema; assessment: daylight). | §2.1 |
| LUM-V-03 | Primary text MUST be ≥ 15:1 against the canvas. Secondary text MUST be ≥ 4.5:1 on every surface it is used on. Tertiary text MAY be 3:1 and MUST then be large or non-essential. | §2.4, `inst/extdata/tokens/contrast.md` |
| LUM-V-04 | Filled buttons MUST have label contrast ≥ 4.5:1, or labels ≥ 18.7 px bold when the accent only reaches 3:1. | §2.4 |
| LUM-V-05 | There MUST be exactly one accent (plus, optionally, one gradient) for actions and focus. Semantic colours (good, warn, bad) MUST NOT be used as brand colour. Domain palettes (arms, strings, areas) MUST live in code constants. | §2.2 |
| LUM-V-06 | Display type MUST use tight tracking (−.035 to −.05em), weight 700–780 and line-height ≤ 1.05, with `clamp()` sizing. Gradient text MUST be limited to key words. | §3 |
| LUM-V-07 | Glass (translucent ~72 %, blur 10–22 px, saturate 140–180 %, hairline border) MUST be reserved for surfaces that float over layered or moving content: nav after scroll, docks, HUDs, sheets and cards over ambient light. There MUST be a `@supports not (backdrop-filter…)` solid fallback. | §4.3 |
| LUM-V-08 | Ambient light (blobs, glows, bokeh, grain) MUST be fixed, non-interactive, slow (≥ 20 s loops), dimmable (focus mode) and switchable for capture and print. | §2.3, §6.3 |
| LUM-V-09 | Fonts MUST ship with the product or come from the system stack: no web-font CDN. Numerals in stats and timers MUST be tabular. | §3 |
| LUM-V-10 | Radii MUST come from a 4-step scale plus pill. One button shape per app (pill or rounded rectangle). | §4.1 |

## 4. Motion

| ID | Requirement |
|---|---|
| LUM-M-01 | Motion MUST use the shared curves: `cubic-bezier(.2,.8,.2,1)` (default) and a spring (`cubic-bezier(.34,1.56,.64,1)`) for confirmations only. |
| LUM-M-02 | Every animation MUST have a reduced-motion state under `@media (prefers-reduced-motion: reduce)`: no ambient drift, no parallax, instant count-ups, and cross-fades instead of movement. |
| LUM-M-03 | Animations MUST be CSS or Web Animations (seekable), and randomness MUST be injectable, so that a deterministic recorder can capture them (see `QuantSkill/dev/video/recorder.py`). |
| LUM-M-04 | Scroll-driven storytelling MUST keep every step readable without scrolling animation (static fallback, print). |

## 5. Components

A Lumen project MUST provide, from the shared anatomy in STYLEGUIDE §7:

| ID | Component | Must have |
|---|---|---|
| LUM-C-01 | Glass top navigation | Brand mark, section links with active indicator, mode chip (Shiny / Quarto / HTML), theme toggle. |
| LUM-C-02 | Hero | Display headline with gradient key words, lede (`clamp(18–24px)`), primary and ghost CTA. |
| LUM-C-03 | Buttons | Primary (accent or gradient + glow), ghost, white-on-dark, icon; sizes lg/md/sm; loading; disabled at ≤ .4 opacity. |
| LUM-C-04 | Chips and pills | Neutral and semantic variants; status dot. |
| LUM-C-05 | Cards | Solid card and glass card, with header icon tile. Big-number tile with a mini chart. |
| LUM-C-06 | Choice controls | Segmented control, toggle cards, choice cards with visual preview, switch. |
| LUM-C-07 | Overlays | Sheet or modal on a blurred scrim, toast, empty state, progress dock or overlay for long jobs. |
| LUM-C-08 | Data story | At least one narrative visual that shows the unit of analysis (a dot per patient, a tile per skill area, a note per beat). |

## 6. Accessibility

| ID | Requirement |
|---|---|
| LUM-A-01 | WCAG 2.2 AA for text and UI contrast (LUM-V-03, LUM-V-04), in every theme. |
| LUM-A-02 | Visible `:focus-visible` rings (accent, 3 px, offset 2 px as in QuantSkill) on every interactive element. |
| LUM-A-03 | Every action MUST be reachable by keyboard. Custom controls MUST carry roles and states (`aria-pressed`, `role="switch"`, `aria-expanded`). |
| LUM-A-04 | Colour MUST NOT be the only carrier of meaning (good/bad also have icons or words; dot grids have legends). |
| LUM-A-05 | Reduced motion (LUM-M-02) and, for long-form content, print (LUM-D-04). |

## 7. Performance

| ID | Requirement |
|---|---|
| LUM-F-01 | No more than two stacked `backdrop-filter` layers at any point. Heavy blurs MUST be switchable off (capture, low-power). |
| LUM-F-02 | Main interactions MUST stay at 60 fps on a laptop. Browser-side recomputation of a full view SHOULD take < 250 ms (the story rebuilds 1,500 patients in about 0.2 s). |
| LUM-F-03 | The standalone HTML MUST open without network access. Its size SHOULD stay under 2 MB plus data. |

## 8. Marketing assets

| ID | Requirement |
|---|---|
| LUM-K-01 | Feature screenshots MUST be produced by a script from the built product (not mock-ups), at 1440 × 900 CSS px and 2× DPR, JPEG quality 90 with 4:4:4 chroma, in `docs/features/`. A `manifest.json` MUST record title, caption, provenance (`live` or `bench`), source and theme. Light and dark MUST both appear. |
| LUM-K-02 | The README MUST embed a gallery of the feature screenshots, with captions. |
| LUM-K-03 | A promotional video SHOULD be produced with the QuantSkill video utility (`QuantSkill/dev/video`: deterministic recorder, stage engine, synthesised score, mux). Teaser: 30 s, 1920×1080, 60 fps, H.264, AAC, −14 LUFS, poster. Launch: 60 s with voice-over, −16 LUFS, burned-in captions and `.srt`. The DirectoR teaser is built this way (`tools/video/directoR/`). |
| LUM-K-04 | Synthetic voices, simulated people and illustrative charts in marketing material MUST be disclosed in `media/README.md`. |

## 9. Engineering and verification

| ID | Requirement |
|---|---|
| LUM-E-01 | One build script produces all targets (DLV-01). Generated files are never edited. |
| LUM-E-02 | Logic shared between R and JS MUST have parity tests (DLV-31). |
| LUM-E-03 | CI runs `tools/extract_tokens.py` and `tools/contrast_audit.py` on the stylesheet and fails on new contrast failures for text 1 or text 2. |
| LUM-E-04 | Headless smoke tests of all three targets (DLV-30) and of the screenshot script (it must finish without page errors). |

## 10. Conformance of the current Lumen apps

✓ meets · ◐ partly · ✗ not yet. Evidence in `inst/extdata/tokens/*.json`, `contrast.md` and the code.

| Requirement | QuantSkill | lumenJourney (story) | DirectoR | RockShiny |
|---|---|---|---|---|
| LUM-D-01 triple delivery | ✓ | ✓ | ✗ Shiny only | ✗ Shiny only |
| LUM-V-01 tokenised, namespaced | ✓ 75 vars under `.qs` | ✓ 75 vars under `.lumen-story` | ◐ 26 `:root` vars, page-global classes (`.card`, `.chip`) | ◐ 9 vars, rest hard-coded; bslib theme in R |
| LUM-V-02 light + dark | ✓ | ✓ (cinema + paper) | ✓ dark by nature | ✓ dark by nature |
| LUM-V-03 text contrast | ◐ text 2 on `--bg-3` 4.30 | ◐ paper text 3 2.98–3.37 | ◐ `--dim` 4.00 on small labels | ✓ |
| LUM-V-04 button label contrast | ◐ dark accent 3.65 | ✓ | ◐ gradient mid 3.96 | ✓ dark ink on amber |
| LUM-V-07 glass + fallback | ◐ no `@supports` fallback | ✓ | ◐ no fallback | ◐ no fallback |
| LUM-M-02 reduced motion | ✓ | ✓ | ✗ none | ✗ none |
| LUM-A-02 focus-visible | ✓ | ✓ | ✗ none in `director.css` | ◐ highway only |
| LUM-K-01 screenshots | ✓ `docs/features/` (live) | ✓ (live) | ✓ (bench) | ✓ (bench) |
| LUM-K-03 promo video | ✓ `media/` | – | ✓ `media/DirectoR_teaser_30s.mp4` | – |

## 11. Acceptance checklist for a new Lumen project

- [ ] Headline promise on the first screen; claims traceable to code (LUM-P-01, P-03).
- [ ] `run_app()`, `export_quarto()`, `export_html()` with the same options; capability matrix in the README (LUM-D-01 to D-03).
- [ ] Token sheet under one root class, starting from [`lumen-tokens.css`](../../css/lumen-tokens.css); no raw hex in components (LUM-V-01).
- [ ] Light and dark themes, no flash of the wrong theme (LUM-V-02, DLV-07).
- [ ] Contrast audit passes for text 1, text 2 and button labels in every theme (LUM-V-03, V-04).
- [ ] Glass only on floating surfaces, with an `@supports` fallback; ambient light switchable (LUM-V-07, V-08).
- [ ] Reduced-motion and focus-visible styles; keyboard path for every action (LUM-M-02, A-02, A-03).
- [ ] Screenshot script plus `docs/features/manifest.json`; README gallery (LUM-K-01, K-02).
- [ ] Teaser (and optionally launch film) from the QuantSkill video utility, with disclosures (LUM-K-03, K-04).
