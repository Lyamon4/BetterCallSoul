# Gemini-only evidence analysis design

## Goal

Remove Apple Vision OCR from BetterCallSaul and make Gemini 2.5 Flash the
single analyzer for uploaded receipt images and PDF documents.

## Scope

- JPEG/PNG imports and rendered PDF evidence are sent directly to Gemini.
- Gemini returns the raw recognized text and the existing structured
  EvidenceAnalysis fields.
- DeepSeek continues to handle text-only case analysis and document generation.
- The Gemini embedding model and RAG quota are unchanged by this feature.
- No local OCR or keyword parser may inspect image pixels after this change.

## Architecture

EvidenceImporter remains responsible only for safe file normalization,
preview generation, MIME type selection, and the 10 MB payload boundary.
EvidenceView attaches the imported evidence and immediately calls a new
CaseWorkflowStore.analyzeAttachedEvidence() operation. That operation invokes
the injected EvidenceAnalyzing implementation, which is GeminiVisionClient in
the live container.

GeminiVisionClient continues to use the Gemini Interactions API with inline
base64 data, structured JSON output, and the configured model. The tracked
model value becomes gemini-2.5-flash. The API key is updated only in the
ignored ios/Config/Secrets.local.xcconfig file and must never be committed.

runAIAnalysis() reuses an existing evidenceAnalysis; it calls Gemini only when
evidence is attached but has not yet been analyzed. This prevents a second
image request when the user advances to the text-analysis step.

## Data flow

1. The user selects an image or PDF.
2. EvidenceImporter returns ImportedEvidence with original normalized bytes.
3. EvidenceView calls workflow.attachEvidence(_:).
4. EvidenceView awaits workflow.analyzeAttachedEvidence().
5. GeminiVisionClient sends the bytes as an image or document input.
6. Structured Gemini output updates editable fields through
   applyEvidenceAnalysis(_:).
7. Later, DeepSeek receives only text and reviewed fields.

## Failure behavior

- Gemini transport and provider errors are surfaced on the evidence screen.
- The attachment remains available so the user can retry.
- No Apple Vision or local OCR fallback is used.
- Existing local text generation fallback remains limited to downstream legal
  text generation; it does not analyze image pixels.
- Payloads larger than 10 MB continue to fail before network transmission.

## Configuration and quotas

gemini-3.5-flash is an official stable multimodal model and the existing key can
reach it; a live probe returned provider overload rather than a quota or
permission error. Google documents that exact project limits vary by usage tier
and are visible in Google AI Studio.

The requested evidence model is gemini-2.5-flash. Its image/PDF inference quota
is separate from the exhausted gemini-embedding-2 daily embedding quota.

## Verification

- Unit test direct evidence analysis applies Gemini output.
- Unit test subsequent case analysis does not upload evidence twice.
- Gemini client tests assert image/PDF inline payloads and configured 2.5 model.
- Source and Xcode project contain no VisionTextRecognizer or
  VNRecognizeTextRequest references.
- A live request with the new key confirms gemini-2.5-flash access.
- All iOS unit/UI tests pass before the app is installed and launched.
