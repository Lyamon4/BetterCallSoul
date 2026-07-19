# Category-Specific Evidence Flow Design

## Goal

Make every entry category feel like a distinct legal workflow while preserving one reusable SwiftUI flow and the existing DeepSeek/Gemini pipeline.

## Scope

This change covers the evidence screen and the structured fields created when a case starts. Navigation, visual styling, AI provider order, document generation, and the number of workflow steps remain unchanged.

## Architecture

Use one `EvidenceView` driven by typed presentation data owned by `CaseType`. Do not create five separate screens and do not generate interface copy with AI.

Add two domain types:

- `CaseTypePresentation`: screen title, explanatory copy, narrative label, narrative placeholder, upload title, upload hint, and ordered field descriptors.
- `CaseFieldKind`: stable semantic identity for a field (`counterparty`, `amount`, `date`, `reference`, or `detail`).

Each `ExtractedField` keeps its visible `label` and also carries a `CaseFieldKind`. Business logic reads important values by kind rather than relying on one Russian label such as `Компания`. This allows `Орган`, `Сервис`, `Продавец`, and `Поставщик` to look different while all still map to the counterparty used by document and AI requests.

## Category Content

### Unauthorized charge

- Title: `Оспорьте\nсписание`
- Explanation: `Укажите, кто и когда списал деньги — подготовим требование о возврате.`
- Narrative label: `Как произошло списание`
- Narrative placeholder: `Например: не узнаю операцию, услугу не получил, деньги списали дважды…`
- Upload title: `Добавьте подтверждение списания`
- Upload hint: `Скриншот операции, чек или банковская выписка`
- Fields, in order: `Компания или сервис` (`counterparty`), `Сумма` (`amount`), `Дата` (`date`), `Способ оплаты` (`detail`)

### Fine

- Title: `Обжалуйте\nштраф`
- Explanation: `Проверьте постановление и объясните, почему штраф нужно отменить.`
- Narrative label: `Почему штраф несправедлив`
- Narrative placeholder: `Например: знак был закрыт, автомобилем управлял другой человек…`
- Upload title: `Добавьте постановление`
- Upload hint: `Фото или PDF постановления, уведомления и подтверждающих материалов`
- Fields, in order: `Орган` (`counterparty`), `Номер постановления` (`reference`), `Сумма` (`amount`), `Дата` (`date`)

### Subscription cancellation

- Title: `Отмените\nподписку`
- Explanation: `Укажите сервис и спорное списание — подготовим отмену и запрос на возврат.`
- Narrative label: `Что произошло с подпиской`
- Narrative placeholder: `Например: отменил подписку, но деньги снова списали…`
- Upload title: `Добавьте подтверждение подписки`
- Upload hint: `Скриншот списания, условий подписки или переписки с сервисом`
- Fields, in order: `Сервис` (`counterparty`), `Сумма` (`amount`), `Дата списания` (`date`), `Дата отмены` (`detail`)

### Product problem

- Title: `Решите проблему\nс товаром`
- Explanation: `Опишите недостаток товара и желаемый результат: возврат, замену или ремонт.`
- Narrative label: `Что не так с товаром`
- Narrative placeholder: `Например: товар сломался через три дня, продавец отказал в возврате…`
- Upload title: `Добавьте чек и фото товара`
- Upload hint: `Чек, фотографии недостатка, гарантия или переписка с продавцом`
- Fields, in order: `Продавец` (`counterparty`), `Товар` (`detail`), `Стоимость` (`amount`), `Дата покупки` (`date`)

### Incorrect bill

- Title: `Добейтесь\nперерасчёта`
- Explanation: `Покажите спорный счёт и укажите, какие начисления считаете неверными.`
- Narrative label: `Что неверно в счёте`
- Narrative placeholder: `Например: начислили лишнюю услугу или применили неверный тариф…`
- Upload title: `Добавьте спорный счёт`
- Upload hint: `Фото или PDF счёта, детализация и предыдущие квитанции`
- Fields, in order: `Поставщик` (`counterparty`), `Период` (`detail`), `Сумма` (`amount`), `Номер счёта` (`reference`)

## Data Flow

1. `HomeView.beginCase(_:)` passes the selected `CaseType` to `CaseWorkflowStore.start(type:)`.
2. The store creates the ordered empty fields from `type.presentation.fields`.
3. `EvidenceView` renders all copy and upload guidance from `workflow.currentCase.type.presentation`.
4. Local OCR fills semantic field kinds it can recognize (`counterparty`, `amount`, and `date`) and leaves category-specific fields available for manual review.
5. Gemini evidence results update matching semantic fields without replacing the category-specific field list.
6. The reviewed field dictionary sent to DeepSeek uses the visible category-specific labels. The case type remains a separate structured value in the request.
7. Document generation obtains recipient and amount through semantic field kinds, so category-specific labels do not break existing documents.

## Interaction and Visual Rules

- Preserve the existing warm monochrome BetterCallSaul visual system, typography, spacing, animation, and bottom navigation.
- Keep one evidence screen; only its content changes.
- Show the narrative placeholder only while the text editor is empty and make it non-interactive.
- Keep the upload control format menu and file support unchanged.
- Do not add AI, provider, local-processing, demo, or API-key labels to the interface.

## Error Handling

- OCR or evidence-analysis failures keep the selected category and its fields intact.
- Missing extracted values stay editable and marked for review.
- Category-specific fields that cannot be inferred from OCR remain empty instead of receiving guessed values.
- Existing neutral import and processing error messages remain unchanged.

## Testing

- Unit-test that all five case types have distinct presentation copy.
- Unit-test the exact ordered field labels and semantic kinds for every category.
- Unit-test that `CaseWorkflowStore.start(type:)` creates the selected category's fields.
- Unit-test that extraction and Gemini evidence merging preserve category-specific fields.
- Add UI assertions proving at least two categories display different titles, narrative labels, and upload guidance.
- Run the complete unit and UI suites on iPhone 17 Pro Simulator before committing the implementation.

## Success Criteria

- Opening any category immediately displays copy and fields specific to that category.
- No two categories share the complete same content configuration.
- Switching categories resets the previous case data and shows the newly selected configuration.
- OCR, Gemini analysis, DeepSeek text analysis, and document generation continue using the correct category.
- All automated tests pass and the application launches in the iOS Simulator.
