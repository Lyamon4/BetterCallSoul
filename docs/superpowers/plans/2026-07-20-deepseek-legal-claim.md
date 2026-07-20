# DeepSeek Legal Claim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate and render a complete Kazakhstan-law claim with legal grounds, response deadline, escalation steps, and attachments.

**Architecture:** Keep the direct DeepSeek structured-output flow, expand `AIDocumentSections`, strengthen the category-aware document system prompt, and render the additional fields through `AIDocumentAdapter`. Missing or uncertain legal information remains reviewable instead of being invented.

**Tech Stack:** Swift 6, SwiftUI, Codable JSON, XCTest, DeepSeek Chat Completions API.

## Global Constraints

- Jurisdiction is the Republic of Kazakhstan.
- User facts, dates, amounts, recipient details, and evidence must never be invented.
- Exact legal citations must be current and applicable; uncertainty must be disclosed in `unresolvedIssues`.
- Article 42-4 of Law No. 274-IV is the verified consumer-claim baseline as of 20 July 2026.
- Administrative fines must not automatically inherit consumer-claim rules.

---

### Task 1: Specify the complete legal document prompt

**Files:**
- Modify: `ios/BetterCallSaulTests/CasePromptCoverageTests.swift`
- Modify: `ios/BetterCallSaul/AI/DeepSeek/DeepSeekPrompts.swift`
- Modify: `ios/BetterCallSaul/AI/DeepSeek/DeepSeekTextClient.swift`

**Interfaces:**
- Consumes: `CaseType`, `AIDocumentRequest`
- Produces: `DeepSeekPrompts.documentSystem(for: CaseType) -> String`

- [ ] **Step 1: Write the failing prompt test**

Assert that the generated prompt contains `Республика Казахстан`, `статьи 42-4`, `десяти календарных дней`, `legalGrounds`, `nonComplianceActions`, an exact-citation safety rule, and a fine-category applicability guard.

- [ ] **Step 2: Verify RED**

Run:

```bash
xcodebuild -project ios/BetterCallSaul.xcodeproj -scheme BetterCallSaul -destination 'platform=iOS Simulator,id=8FEAC48D-83DB-4ED3-9870-D48969787A2D' -only-testing:BetterCallSaulTests/CasePromptCoverageTests test
```

Expected: failure because the current prompt omits complete-claim requirements.

- [ ] **Step 3: Implement the category-aware system prompt**

Change the prompt signature to accept `CaseType`, include the verified consumer baseline and anti-hallucination rules, define the expanded JSON schema, and pass the request category from `DeepSeekTextClient.generateDocument`.

- [ ] **Step 4: Verify GREEN**

Run the same focused test and expect all `CasePromptCoverageTests` to pass.

### Task 2: Expand and render the legal document contract

**Files:**
- Modify: `ios/BetterCallSaul/AI/Domain/AIModels.swift`
- Modify: `ios/BetterCallSaul/AI/Domain/AIDocumentAdapter.swift`
- Modify: `ios/BetterCallSaulTests/AIDocumentAdapterTests.swift`
- Modify: `ios/BetterCallSaulTests/DeepSeekTextClientTests.swift`
- Modify: initializers in fallback and workflow test fixtures.

**Interfaces:**
- Produces: `AIDocumentSections.legalGrounds: [String]`
- Produces: `AIDocumentSections.nonComplianceActions: [String]`

- [ ] **Step 1: Write failing decoding and adapter tests**

Provide legal grounds and escalation actions in the DeepSeek JSON fixture and assert that both sections, the response deadline, and attachment description appear in `DocumentDraft.body`.

- [ ] **Step 2: Verify RED**

Run focused `DeepSeekTextClientTests` and `AIDocumentAdapterTests`; expect missing-member or missing-section failures.

- [ ] **Step 3: Add fields and body sections**

Add both Codable fields, update all compile-time fixtures, and render the ordered sections with a ten-calendar-day sentence when `responseDays == 10`.

- [ ] **Step 4: Verify GREEN and regression suite**

Run focused tests, then the full iOS suite; expect zero failures.

- [ ] **Step 5: Commit and push**

```bash
git add ios docs/superpowers
git commit -m "feat: generate complete legal claims with DeepSeek"
git push origin codex/ai-provider-flow
```

