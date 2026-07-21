# BetterCallSaul 8-Bit Saul Mascot

**Date:** 2026-07-19  
**Status:** Approved direction; implementation pending

## Goal

Add a warm, recognizable 8-bit Saul mascot that makes the legal workflow feel less intimidating without turning the product into a game or obscuring the document-focused interface. The same character identity must be used inside the application and on the application icon.

## Character direction

- The mascot is named `Сол`.
- He is a compact, friendly 8-bit lawyer character recognizable through a sandy side-parted comb-over, expressive eyebrows, confident smile, light suit, colorful shirt, bright striped tie, and slightly theatrical lawyer pose.
- The character should evoke Saul Goodman through silhouette, wardrobe, expression, and attitude rather than a photorealistic actor portrait.
- Pixel edges remain crisp at every rendered size. The application must use nearest-neighbor interpolation and avoid smoothing, 3D rendering, gradients, realistic skin texture, or soft painted edges.
- The palette stays compatible with the product: paper cream, charcoal, Saul yellow, warm skin tones, muted blue, and a restrained red tie accent.

## Asset set

Create four consistent transparent PNG states from one approved master character:

1. `saul-idle` — relaxed smile, one hand near the jacket lapel; used on Home.
2. `saul-thinking` — reviewing a small case file; used while evidence or a situation is processed.
3. `saul-talking` — open speaking expression and a small pointing gesture; used with contextual help copy.
4. `saul-celebrating` — broad smile and thumbs-up; used when a document is ready.

The four states must retain the same face, proportions, clothes, palette, pixel scale, and outline treatment. Each source asset uses generous padding and a transparent background with no baked-in speech bubble, shadow, text, or surrounding UI.

Create a separate `1024 × 1024` application icon using a close 8-bit portrait of the same Saul. The icon uses a cream background, a bold Saul-yellow field or border, charcoal outline work, no text, no transparency, and enough safe-area padding for iOS icon masking.

## SwiftUI integration

Introduce a reusable `SaulMascotView` with an explicit state enum: `idle`, `thinking`, `talking`, and `celebrating`. The component owns image selection, nearest-neighbor rendering, accessibility behavior, and restrained animation.

- Home: replace the current payphone illustration in the brand header with `idle` Saul.
- Evidence and analysis processing: show `thinking` Saul beside neutral status copy. He must not expose AI or provider terminology.
- Document completion: show `celebrating` Saul near the ready state without competing with the document and primary action.
- Contextual help: tapping Saul on Home reveals one short `talking` bubble. It is not a chatbot, does not open a new screen, and never blocks the main flow.

The first help lines are deterministic and product-safe:

- `Расскажите как было — я помогу собрать главное.`
- `Чеки и скриншоты сделают обращение сильнее.`
- `Перед отправкой всё можно проверить.`

Only one bubble is shown at a time. It dismisses on a second tap, when navigation begins, or when the screen disappears.

## Motion

Animation remains subtle and native:

- `idle`: a two-point vertical bob with a long pause between cycles.
- `thinking`: a slow one-degree side-to-side tilt.
- `talking`: one brief scale pulse while the bubble appears.
- `celebrating`: one short spring entrance and a small upward bounce; no infinite celebration loop.

Use SwiftUI transforms rather than video, GIF, extra animation frames, or third-party animation libraries. Respect `accessibilityReduceMotion`: when enabled, render the appropriate static pose with no repeated movement.

## Interaction and accessibility

- The Home mascot is a 44-point-minimum button with the accessibility label `Сол, помощник` and hint `Показывает короткую подсказку`.
- Processing and completion mascots are decorative when the adjacent text already communicates their meaning, so they are hidden from VoiceOver.
- The mascot never conveys required state by animation or color alone.
- If an image asset cannot load, the surrounding workflow and copy remain usable; no functional action depends on mascot rendering.

## Architecture and data flow

- Static PNG assets live in `Resources/Assets.xcassets` as individual image sets.
- `SaulMascotState` maps each semantic state to its asset name and animation behavior.
- Screens choose the semantic state; they do not implement pixel rendering or repeated animation logic themselves.
- Home owns the local help-bubble visibility and line rotation. No database, network call, AI call, analytics event, or persistent state is required.
- The existing legal workflow, provider orchestration, document generation, and navigation remain unchanged.

## Verification

- Unit tests verify every mascot state has a valid asset mapping and deterministic help copy.
- Source-surface tests verify no new AI/provider language is introduced.
- UI tests verify the Home mascot can reveal and dismiss a help bubble, and that document completion exposes the celebratory mascot identifier.
- The complete unit/UI suite must pass without live network requests.
- Simulator screenshots are inspected for Home, processing, document completion, and the installed application icon.
- Generated PNGs are checked for consistent dimensions, transparent corners for in-app sprites, opaque icon pixels, crisp nearest-neighbor rendering, and no accidental text or watermark.

## Non-goals

- No free-form mascot chatbot.
- No speech audio, lip-sync, virtual-pet care loop, currency, streak, or gamified legal outcome.
- No mascot overlay on every screen and no draggable global floating button.
- No replacement of legal status copy with character-only feedback.
