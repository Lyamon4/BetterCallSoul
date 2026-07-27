# Editable Profile Name Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist an editable profile name and use it everywhere the app addresses or identifies the user.

**Architecture:** Add an injected `UserDefaults`-backed observable store at the app root. Pass that store explicitly into the three consuming SwiftUI screens.

**Tech Stack:** Swift 6, SwiftUI, Observation, Foundation `UserDefaults`, XCTest, XCUITest.

## Global Constraints

- Default display name is `Алим`.
- Blank names are not saved.
- Leading and trailing whitespace is removed.
- UI tests must not mutate standard user defaults.

---

### Task 1: Profile Store

**Files:**
- Create: `ios/BetterCallSaul/Domain/UserProfileStore.swift`
- Create: `ios/BetterCallSaulTests/UserProfileStoreTests.swift`

**Interfaces:**
- Produces: `UserProfileStore.name`, `updateName(_:) -> Bool`.
- Consumes: injected `UserDefaults`.

- [ ] Write tests for default, trim, blank rejection, and reload persistence.
- [ ] Run focused tests and confirm they fail because the store is missing.
- [ ] Implement the minimal observable persistence store.
- [ ] Run focused tests and confirm they pass.

### Task 2: Profile Editing UI

**Files:**
- Modify: `ios/BetterCallSaul/Features/Profile/ProfileView.swift`
- Modify: `ios/BetterCallSaul/App/BetterCallSaulApp.swift`
- Modify: `ios/BetterCallSaul/App/AppRootView.swift`
- Modify: `ios/BetterCallSaulUITests/PrimaryFlowUITests.swift`

**Interfaces:**
- Consumes: `UserProfileStore`.
- Produces: `profileNameField`, `saveProfileNameButton`, and immediate observable updates.

- [ ] Add a UI test that changes the name and observes the new home greeting.
- [ ] Run the UI test and confirm the field/action are missing.
- [ ] Build the editorial profile form with validation and save feedback.
- [ ] Run the focused UI test and confirm it passes.

### Task 3: Name Consumers and Verification

**Files:**
- Modify: `ios/BetterCallSaul/Features/Home/HomeView.swift`
- Modify: `ios/BetterCallSaul/Features/Document/DocumentView.swift`

**Interfaces:**
- Consumes: `profile.name`.
- Produces: personalized greeting and sender name in preview/PDF.

- [ ] Replace hardcoded production name consumers with `profile.name`.
- [ ] Run the full unit and UI suites.
- [ ] Build, install, and launch the app in iPhone 17 Pro Simulator.
- [ ] Commit, push, open a PR, and merge into `main`.
