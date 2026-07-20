# AI Analysis Timeout Design

## Goal

Prevent the third workflow step from appearing frozen when DeepSeek takes too long to produce a structured legal analysis.

## Evidence and Root Cause

The live Gemini image request for the supplied 2.1 MB receipt completed successfully in 18.34 seconds. A simple DeepSeek request completed in 1.71 seconds, but the real structured analysis request to `deepseek-v4-pro` returned no bytes within a 45-second diagnostic deadline.

The application currently uses `URLSession.shared`, whose request timeout is 60 seconds, and `CaseWorkflowStore.retryOnce` retries every failure. A slow DeepSeek analysis can therefore block the third step for roughly 120 seconds after Gemini finishes before local fallback becomes visible.

The keys, endpoints, response schemas, and configured models all responded successfully in isolated diagnostics. Authentication and response decoding are not the cause.

## Considered Approaches

### 1. Typed 15-second deadline with immediate fallback — chosen

Give every DeepSeek request a 15-second request timeout. Preserve one retry for ordinary transient transport and provider errors, but identify timeout errors explicitly and never retry them. `CaseWorkflowStore` immediately generates its existing local analysis or document after a timeout.

This is the smallest change that caps the wait, preserves DeepSeek when it responds promptly, and keeps the current offline fallback behavior.

### 2. Replace `deepseek-v4-pro` with a faster model

This could reduce latency but makes correctness depend on external model availability and behavior. It does not protect the application from future slow responses or network stalls.

### 3. Run Gemini and DeepSeek concurrently

This could reduce total latency, but DeepSeek currently consumes the evidence summary produced by Gemini. Parallel execution would either remove that context or require a larger two-pass workflow redesign.

## Architecture

Add an explicit `timedOut` case to `AIProviderError`. `URLSessionHTTPTransport` maps `URLError.timedOut` to that case without reducing other network failures to a timeout. `DeepSeekTextClient` sets `URLRequest.timeoutInterval` to exactly 15 seconds for both case analysis and document generation.

Replace the unconditional retry helper with a timeout-aware retry policy:

- success returns immediately;
- `AIProviderError.timedOut` is rethrown immediately;
- all other first failures receive the existing single retry;
- a second failure is returned to the existing local fallback path.

The public UI and workflow states remain unchanged. When the timeout occurs, the existing local generator produces `caseAnalysis`, `aiState` becomes `.fallback`, `isAnalyzing` becomes false, and the third screen displays actionable content instead of the progress panel.

## Data Flow

1. Gemini analyzes the uploaded image using the existing evidence request.
2. The workflow creates the existing structured DeepSeek analysis request with Gemini evidence context.
3. DeepSeek receives a 15-second request deadline.
4. If DeepSeek succeeds, the workflow displays its analysis normally.
5. If DeepSeek times out, the workflow does not issue a second DeepSeek request.
6. The local text generator immediately creates the fallback analysis and unlocks `Подготовить документ`.
7. Document generation follows the same timeout policy so the fourth-step transition cannot repeat the two-minute wait.

## Error Handling

- A timeout uses the neutral existing fallback UI; provider names and implementation details remain hidden.
- Authentication, quota, invalid response, and generic transport errors retain one retry because they may be transient.
- Gemini keeps its current timeout behavior because the measured image request completes successfully and the reported stall occurs during DeepSeek structured generation.
- The application never discards the uploaded receipt, OCR fields, narrative, or reviewed values when fallback is used.

## Testing

- Verify `URLSessionHTTPTransport` converts `URLError.timedOut` into the typed timeout error.
- Verify both DeepSeek analysis and document requests carry `timeoutInterval == 15`.
- Verify a DeepSeek timeout causes exactly one provider attempt and produces local analysis.
- Preserve the existing test proving generic transport failures still receive one retry.
- Verify document generation also avoids retrying a timeout and produces local document sections.
- Run the complete unit and UI suites on iPhone 17 Pro Simulator.
- Manually run the receipt workflow and confirm the third step leaves the progress state after at most the Gemini duration plus 15 seconds.

## Success Criteria

- A slow DeepSeek request cannot keep a single analysis or document-generation attempt open longer than 15 seconds.
- A timeout is never retried.
- The third step displays local fallback content immediately after the timeout.
- The document button becomes enabled when fallback analysis exists.
- Non-timeout transient failures keep the existing one-retry behavior.
- No provider, timeout, local-processing, demo, or API-key labels are added to the user interface.
