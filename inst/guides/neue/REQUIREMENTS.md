# Neue: requirements for new projects

These are requirements for any new Taiga project built on the **Neue** framework, derived from teal_neue
and BlockR. The key words MUST, SHOULD and MAY follow RFC 2119. The visual reference is
[`STYLEGUIDE.md`](STYLEGUIDE.md). The delivery reference is [`../DELIVERY_MODEL.md`](../DELIVERY_MODEL.md).
For when to choose Neue rather than Lumen, see [`../lumen/REQUIREMENTS.md` §0](../lumen/REQUIREMENTS.md#0-when-to-choose-lumen).

## 1. Product

| ID | Requirement | Evidence |
|---|---|---|
| NEU-P-01 | The product MUST keep its host framework recognisable (teal stays teal). Neue is a layer: switching it off (`options(<pkg>.style = FALSE)`) MUST give the plain host look with everything still working. | teal_neue, BlockR `*.style` option |
| NEU-P-02 | Every output (table, listing, graph, derived dataset) MUST offer its complete, runnable code ("Show R code"), computed on the current filtered data. | teal `Show R code`, TLG Catalog, BlockR Code pane |
| NEU-P-03 | Data provenance MUST be visible at all times: source, subject count and last-update time in the header, and rows · cols (plus the change) on every data-producing step. | `.tn-status`, BlockR block footers |
| NEU-P-04 | The home view MUST summarise the whole dataset before any filter ("study at a glance"), each widget linking to the module that goes into detail. | `R/overview.R` + `teal_neue.js` |
| NEU-P-05 | Populations and defaults MUST be correct per analysis (for example safety: `SAFFL == "Y"`, efficacy: `ITTFL == "Y"`), and data MUST pass a documented data contract before the app starts. | `validate_adam()`, `check_app_defaults()` |

## 2. Delivery

| ID | Requirement |
|---|---|
| NEU-D-01 | The project MUST specify and ship Shiny, Quarto and standalone HTML per the [delivery model](../DELIVERY_MODEL.md). For analysis tools the portable formats carry **results and code** (overview, TLG outputs, canvases), never live server computation. |
| NEU-D-02 | The Quarto format MUST be a report: chosen outputs as sections, each with its runnable code as chunks (NEU-P-02), and the overview as a raw-HTML block. |
| NEU-D-03 | The HTML format MUST be a self-contained, read-only snapshot that states the filters and data version it was made from. |
| NEU-D-04 | The README MUST contain a "Delivery formats" table (status, entry points, capability matrix). |

## 3. Visual foundations

| ID | Requirement | Reference |
|---|---|---|
| NEU-V-01 | Tokens MUST follow the five layers: primitives (`html:root`), light and dark semantics, a Bootstrap bridge (`--bs-*` from `--tn-*`), section tints, and user appearance attributes. Components MUST read semantic tokens only. | STYLEGUIDE §2.1 |
| NEU-V-02 | The product MUST NOT compile Sass at start-up or fetch third-party resources. Fonts (Inter, JetBrains Mono, OFL) ship in `inst/www/fonts`. | §1, §3 |
| NEU-V-03 | One accent (teal `#0e8f83` / `#2cc5b4` unless the product has its own), signal amber, danger, ok, and quiet section tints. No glass and no decorative gradients (one flagship exception at most, like BlockR's Tutorial button). | §2 |
| NEU-V-04 | Body text MUST be 14 px (`--tn-fs-md`) with a 7-step rem scale. Identifiers, datasets, variables, IDs and counts MUST be mono. | §3 |
| NEU-V-05 | Spacing from a 4 px base (`--tn-s1…s8`), controls at `--tn-control-h` (34 px), three soft elevation levels, ruled panels on a dot-grid canvas. | §4 |
| NEU-V-06 | Exactly one dark palette per product: ink-blue (long reading, white-paper plots) or lifted slate (colourful canvases). | §2.3 |
| NEU-V-07 | Plots MUST use the app theme for ink only. Data colours stay with the analysis package, no fonts are set in plot code, and plots stay white in dark mode. | §8 |

## 4. Appearance and density

| ID | Requirement |
|---|---|
| NEU-X-01 | Users MUST be able to set colour mode (light, dark, auto), text size (s, m, l, xl), density (compact, comfortable, roomy), accent, corners (soft, crisp), contrast (standard, high), canvas (dots, plain) and motion (on, off). |
| NEU-X-02 | Settings MUST be attributes on `<html>`, saved in `localStorage`, and applied by an inline head script **before first paint** (no flash). App-level defaults come from R options (`<pkg>.color_mode`, `<pkg>.motion`). |
| NEU-X-03 | All component sizes MUST derive from the tokens the settings change (`--tn-fs-*`, `--tn-s*`, `--tn-control-h`, `--tn-cell`, `--tn-r*`). |

## 5. Navigation and productivity

| ID | Requirement |
|---|---|
| NEU-N-01 | A command bar (`Ctrl/Cmd+K`, `/`) MUST reach every module, every catalogued output and every action by fuzzy search, with scopes (All, Where to?, outputs, actions). |
| NEU-N-02 | Every view MUST have a deep link (`#/section/module/output`), browser history support and a "copy link" action (`L`). |
| NEU-N-03 | A breadcrumb MUST show where the user is (group › module › output). |
| NEU-N-04 | Single-key shortcuts for frequent actions (`H`, `[`/`]`, `T`, `A`, `D`, `F`, `\`, `C`, `P`, `L`) and a shortcut sheet (`?`). Keys MUST NOT fire while typing in inputs. |
| NEU-N-05 | Outputs MUST have tools on hover *and* by keyboard: expand, pin for comparison (swipe, side by side, difference), copy, download (PNG / CSV / copy for Excel). |

## 6. Accessibility

| ID | Requirement |
|---|---|
| NEU-A-01 | WCAG 2.2 AA. `--tn-ink-4` (2.41–2.64:1 in light) MUST NOT carry information. `--tn-ink-3` on the canvas only for ≥ 14 px semibold or large text. |
| NEU-A-02 | Filled-accent buttons MUST reach 4.5:1 for their labels, or use semibold labels ≥ 14 px with a documented exception (white on `#0e8f83` is 3.98:1). The high-contrast setting MUST lift every ink level to ≥ 4.5:1. |
| NEU-A-03 | Visible `:focus-visible` on every control. Dialogs trap focus and close on `Esc`. |
| NEU-A-04 | `prefers-reduced-motion` and the motion setting stop every non-essential animation (`.tn-still`). |
| NEU-A-05 | Canvas editors (BlockR) MUST be operable without drag: click-to-add, keyboard delete, duplicate, undo and redo. Every block and panel MUST have an explanation ("What is this?"). |

## 7. Performance

| ID | Requirement |
|---|---|
| NEU-F-01 | Start-up MUST be cached (session memory → disk → fresh build) and invalidated when code or data change. A relaunch in the same R session SHOULD be instant. |
| NEU-F-02 | Expensive outputs MUST be cached per output until filters change. One failing output MUST NOT affect the others. |
| NEU-F-03 | Block-by-block evaluation MUST re-run only what changed (BlockR `blockr_run()` cache). |

## 8. Marketing assets

| ID | Requirement |
|---|---|
| NEU-K-01 | Feature screenshots as in LUM-K-01 (script-made, 1440 × 900 @2×, `docs/features/manifest.json` with provenance), showing light and dark, the command bar and at least one real output. |
| NEU-K-02 | Screenshots taken on a test bench (not the full app) MUST say so: provenance `bench` in the manifest, and a sentence under the README gallery. |
| NEU-K-03 | A promotional video MAY be produced with the QuantSkill video utility (see LUM-K-03). |

## 9. Engineering and verification

| ID | Requirement |
|---|---|
| NEU-E-01 | Code → blocks → code round trips (BlockR) and output reproduction (TLG Catalog) MUST be tested for every catalogued output. |
| NEU-E-02 | Data invariants MUST be tested on several datasets (bundled, synthetic draws, a parquet round trip). |
| NEU-E-03 | CI runs `tools/extract_tokens.py` and `tools/contrast_audit.py`. The token layers of sibling Neue apps are diffed, so that divergence (like BlockR's dark palette) is deliberate and documented. |
| NEU-E-04 | Headless smoke tests of all three delivery targets (DLV-30). |

## 10. Conformance of the current Neue apps

| Requirement | teal_neue | BlockR |
|---|---|---|
| NEU-P-01 layer, style switch | ✓ `teal_neue.style` | ✓ `blockr.style` |
| NEU-P-02 runnable code | ✓ Show R code, TLG code dialog | ✓ Code pane (R and SAS), Show R code |
| NEU-P-03 provenance | ✓ status pill | ✓ status pill + block footers |
| NEU-P-04 study at a glance | ✓ | ✗ (canvas is the home page) |
| NEU-D-01 triple delivery | ✗ Shiny only (plan in DELIVERY_MODEL §5.1) | ✗ Shiny only (plan in DELIVERY_MODEL §5.1) |
| NEU-V-01 token layers | ✓ 598 custom properties | ✓ 627 (tn + bk) |
| NEU-V-06 one dark palette | ✓ ink-blue | ✓ lifted slate |
| NEU-X-01/02 appearance | ✓ | ✓ |
| NEU-N-01…05 navigation | ✓ | ✓ (canvas keys, command bar) |
| NEU-A-01 ink-4 usage | ◐ audit per screen needed | ◐ audit per screen needed |
| NEU-A-02 accent button contrast | ◐ 3.98:1 | ◐ 3.98:1 |
| NEU-A-04 reduced motion | ✓ | ✓ |
| NEU-K-01/02 screenshots | ✓ (bench, disclosed) | ✓ (bench, disclosed) |

## 11. Acceptance checklist for a new Neue project

- [ ] Layered over the host theme via `--bs-*`; style switch off gives the plain host (NEU-P-01, V-01, V-02).
- [ ] Start from [`neue-tokens.css`](../../css/neue-tokens.css); components use semantic tokens only.
- [ ] Runnable code for every output; provenance in the header and on every step (NEU-P-02, P-03).
- [ ] Home summary before filters, linking into modules (NEU-P-04).
- [ ] Appearance settings applied before first paint (NEU-X-01 to X-03).
- [ ] Command bar, deep links, breadcrumb, shortcuts, hover and keyboard tools (NEU-N-01 to N-05).
- [ ] Contrast audit, ink-4 rule, focus-visible, reduced motion (NEU-A-01 to A-04).
- [ ] Shiny, Quarto report and HTML snapshot, with a README "Delivery formats" table (NEU-D-01 to D-04).
- [ ] Screenshots with provenance; bench disclosure if applicable (NEU-K-01, K-02).
