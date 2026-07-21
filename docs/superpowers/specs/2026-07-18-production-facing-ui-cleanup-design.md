# BetterCallSaul Production-Facing UI Cleanup

## Goal

Make the application look and behave like a finished consumer legal service. AI providers remain an internal implementation detail. A user must never need to configure a provider or understand Gemini, DeepSeek, API keys, retry modes, or local fallbacks.

## User-facing language

- Remove all visible mentions of `AI`, `Gemini`, `DeepSeek`, providers, API keys, Keychain overrides, local mode, fallback mode, demo mode, and concept mode.
- Keep the existing plain-language journey: describe the problem, add evidence, review extracted facts, answer necessary questions, prepare a document, and export it.
- Replace technical progress copy with service language: `Проверяем документ` and `Разбираем ситуацию`.
- Do not show a fallback banner. If the internal fallback succeeds, show the resulting review screen normally. If every path fails, preserve entered data and show a neutral actionable error.
- Replace the provider-specific evidence disclosure with neutral consent copy: `Загружая документ, вы разрешаете обработать его для извлечения данных и подготовки обращения.`

## Bundled configuration

- Provider credentials remain bundled in `Secrets.xcconfig` and are loaded automatically at application startup.
- Remove the profile link, provider settings screen, masked key badges, secure key fields, and Keychain rotation UI.
- Remove runtime Keychain overrides so the installed application has one predictable bundled configuration.
- Missing or rejected credentials produce neutral service errors without provider names.

## Tools

- Show only capabilities that currently have a real working in-app path.
- Remove `Временный номер` and `Trial Card` until actual integrations exist.
- Remove all capability badges, including `РАБОТАЕТ`, `DEMO`, and `КОНЦЕПТ`.
- Keep the Saul-themed editorial callout because it is brand styling, not a technical/demo indicator.

## Profile

- Remove the `AI-провайдеры` navigation tile and all configuration UI.
- Keep a restrained real-user profile surface with the user name, language/region, privacy note, and app version presentation. Do not add controls that imply unavailable account or cloud functionality.

## Internal behavior

- Gemini image/PDF analysis and DeepSeek text/document generation remain unchanged internally.
- Retry, typed decoding, local fallback, PDF generation, and sharing remain unchanged.
- Internal Swift type names and provider tests may retain technical names because they are not presented to users.

## Verification

- UI tests assert that the main flow contains no provider, key, local, demo, or concept labels.
- Tools UI tests assert that only supported tools appear.
- Unit tests verify bundled configuration construction without Keychain overrides.
- The complete unit/UI suite runs with stubbed providers and makes no live requests.
- A simulator screenshot is inspected for the Home, analysis, tools, and profile screens.
