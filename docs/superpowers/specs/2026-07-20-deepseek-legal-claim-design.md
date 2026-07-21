# DeepSeek Legal Claim Design

## Goal

Make DeepSeek generate a complete, formal Russian-language claim or complaint under the law of the Republic of Kazakhstan instead of the current short list of facts and demands.

## Selected approach

Expand the structured document contract and the final document adapter. A prompt-only change is insufficient because the current JSON schema has no place for legal grounds or escalation language. Connecting the full backend RAG retrieval path is a separate feature and is outside this change.

## Document contract

`AIDocumentSections` gains:

- `legalGrounds: [String]` for applicable statutes and a short explanation of their relevance;
- `nonComplianceActions: [String]` for proportionate next steps if the recipient refuses or ignores the claim.

Existing fields continue to carry the recipient, subject, facts, demands, response deadline, attachments, and unresolved issues.

## DeepSeek drafting rules

The system prompt must:

- use the jurisdiction of the Republic of Kazakhstan and formal Russian;
- choose a claim for consumer disputes and a complaint/appeal when the selected category requires it;
- produce chronological facts, legal grounds, concrete demands, a response deadline, attachments, and lawful escalation steps;
- use only confirmed case facts and user answers;
- never invent a recipient, event, amount, date, contract number, or evidence;
- cite an exact statute/article only when the prompt provides a verified source or the model is confident the citation is current and applicable;
- put an uncertain citation or missing material fact into `unresolvedIssues` instead of presenting it as fact;
- apply the verified consumer baseline from Article 42-4 of Kazakhstan Law No. 274-IV: a consumer may submit a claim, the recipient must provide a reasoned written response within ten calendar days when disagreeing, and the consumer may escalate after refusal or silence;
- never apply consumer-law rules automatically to an administrative fine or another excluded field.

## Rendering

The generated body is ordered as:

1. factual circumstances;
2. legal grounds;
3. demands;
4. response deadline;
5. action following refusal or silence;
6. attachments.

Missing legal grounds remain visibly marked for review. No invented citation is silently inserted by the adapter.

## Testing

- Prompt coverage asserts the Kazakhstan jurisdiction, verified Article 42-4 baseline, structured legal fields, anti-hallucination rule, and category applicability guard.
- Client decoding asserts the expanded JSON contract.
- Adapter tests assert that every new section appears in the final claim body.
- The full iOS test suite must pass before commit and push.

