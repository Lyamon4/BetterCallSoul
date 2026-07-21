# Gemini-only Evidence Analysis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Make Gemini 2.5 Flash the only image/PDF analyzer and remove Apple Vision OCR from the iOS target.

**Architecture:** EvidenceView attaches normalized evidence and immediately asks CaseWorkflowStore to analyze it through the injected EvidenceAnalyzing service. The live service is GeminiVisionClient; completed analysis is reused by downstream DeepSeek text analysis so the binary attachment is uploaded only once.

**Tech Stack:** SwiftUI, Swift concurrency, XCTest, Gemini Interactions API, Xcode 26, iOS 26 Simulator.

## Global Constraints

- GEMINI_MODEL is gemini-2.5-flash in tracked and local xcconfig files.
- The populated API key exists only in ignored Secrets.local.xcconfig.
- No Vision framework import, VNRecognizeTextRequest, or VisionTextRecognizer remains.
- Images and PDFs retain the existing 10 MB request limit.
- DeepSeek remains text-only.
- All implementation is performed inline without subagents.

---

### Task 1: Specify the single-upload workflow with failing tests

**Files:**
- Modify: ios/BetterCallSaulTests/AIWorkflowTests.swift

**Interfaces:**
- Consumes: CaseWorkflowStore.attachEvidence(_:) and WorkflowEvidenceStub.
- Produces: desired async API analyzeAttachedEvidence() and single-upload behavior.

- [ ] Add testAnalyzeAttachedEvidenceUsesGeminiAndAppliesEditableFields. Attach fixture evidence, await analyzeAttachedEvidence(), and assert counterparty, amount, evidence summary, active provider, and one analyzer attempt.
- [ ] Add testRunAIAnalysisReusesExistingEvidenceAnalysis. Pre-analyze evidence, run downstream analysis, and assert the analyzer attempt count remains one while the legal analyzer runs once.
- [ ] Run the two tests with xcodebuild and confirm compilation fails because analyzeAttachedEvidence() is missing.

### Task 2: Implement Gemini-only workflow orchestration

**Files:**
- Modify: ios/BetterCallSaul/Domain/CaseWorkflowStore.swift
- Modify: ios/BetterCallSaul/Features/Evidence/EvidenceView.swift

**Interfaces:**
- Produces: @MainActor func analyzeAttachedEvidence() async throws.
- Behavior: retry one non-timeout failure, apply EvidenceAnalysis, set activeProvider to Gemini, and avoid duplicate analysis.

- [ ] Add analyzeAttachedEvidence() with a guard for attached payload and the existing retry helper.
- [ ] Refactor runAIAnalysis() to invoke analyzeAttachedEvidence() only when evidenceAnalysis is nil.
- [ ] Replace EvidenceView.recognize(_:) with attachEvidence followed by analyzeAttachedEvidence().
- [ ] Remove ReceiptFieldParser and all local OCR calls from the import path.
- [ ] Run the focused AIWorkflowTests and confirm both new tests pass.

### Task 3: Remove Apple Vision from source and Xcode

**Files:**
- Delete: ios/BetterCallSaul/Services/VisionTextRecognizer.swift
- Modify: ios/BetterCallSaul.xcodeproj/project.pbxproj

**Interfaces:**
- Produces: build graph with no VisionTextRecognizer source reference.

- [ ] Delete VisionTextRecognizer.swift.
- [ ] Remove its PBXFileReference, PBXBuildFile, group entry, and Sources build phase entry.
- [ ] Search the repository for Vision, VNRecognizeTextRequest, and VisionTextRecognizer and confirm no production reference remains.
- [ ] Build the BetterCallSaul scheme and confirm it compiles.

### Task 4: Switch configuration to Gemini 2.5 Flash

**Files:**
- Modify: ios/Config/Secrets.xcconfig
- Modify: ios/Config/Secrets.local.xcconfig.example
- Modify locally only: ios/Config/Secrets.local.xcconfig
- Modify: ios/BetterCallSaulTests/GeminiVisionClientTests.swift

**Interfaces:**
- Consumes: Info.plist GeminiModel build setting.
- Produces: gemini-2.5-flash for image/PDF analysis.

- [ ] Update Gemini client fixtures to gemini-2.5-flash and assert the encoded request model.
- [ ] Run the focused client test and observe failure while it still expects the old model behavior.
- [ ] Change tracked model defaults to gemini-2.5-flash.
- [ ] Update the ignored local key and model without exposing the key in output or Git.
- [ ] Call the Gemini API with one tiny request and report only status/model/quota metadata.

### Task 5: Verify and publish

**Files:**
- Verify all modified files and the ignored local secret.

**Interfaces:**
- Produces: tested commit on codex/ai-provider-flow and launched simulator build.

- [ ] Run all iOS unit and UI tests on the booted iPhone 17 Pro Simulator.
- [ ] Verify git diff contains no populated provider key.
- [ ] Commit implementation and push codex/ai-provider-flow.
- [ ] Build, install, launch BetterCallSaul, and capture a simulator screenshot.
