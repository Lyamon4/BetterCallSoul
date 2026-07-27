# Editable Profile Name Design

## Goal

Allow the user to edit their name in Profile, persist it between app launches, and use the same value in the home greeting, document preview, and exported PDF.

## Behavior

- The default name remains `Алим` for an existing fresh installation.
- Profile contains a clearly labeled name field and a “Сохранить имя” action.
- Leading and trailing whitespace is removed on save.
- An empty or whitespace-only name is rejected without replacing the current value.
- The saved name updates the UI immediately and persists in `UserDefaults`.
- UI-testing launches use an isolated storage suite so automated edits never change the real user profile.

## Architecture

`UserProfileStore` is a main-actor observable object and the single source of truth for the user name. It accepts an injected `UserDefaults`, which keeps persistence testable and isolates UI tests.

`BetterCallSaulApp` owns the store and passes it through `AppRootView` to `HomeView`, `ProfileView`, and `DocumentView`. `DocumentView` supplies `profile.name` to the existing document draft pipeline, so the same value reaches preview and PDF without duplicating persistence logic.

## Testing

- Unit tests cover default value, trimming, rejection of blank input, and reload persistence.
- UI test covers editing the profile and seeing the updated greeting.
- Existing document/PDF tests continue to verify sender rendering.
