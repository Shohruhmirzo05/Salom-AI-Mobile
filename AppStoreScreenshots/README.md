# Salom AI — App Store screenshot campaign

This folder contains a new native-iOS App Store screenshot campaign built from
real Salom AI Simulator screens. The final product UI is preserved pixel-for-pixel;
generated imagery is used only as the surrounding marketing background.

## Deliverables

- `final/top-10/` — selected App Store upload set, already ordered
- `final/candidates/` — all 15 finished candidates
- `final/contact-sheet.png` — visual overview of all candidates
- `raw/` — original 1320 × 2868 native captures plus the Xcode Simulator
  hardware-bezel source
- `generated/` — generated background assets
- `prompts/app-store-shot-prompts.md` — reusable structured prompts
- `compose_app_store.js` — deterministic compositor
- `capture_native_screens.sh` — repeatable Simulator capture script

Every final image is:

- 1284 × 2778 pixels (Apple 6.7-inch portrait format)
- RGB PNG with no alpha channel
- based on the native app rather than a recreated interface
- mounted inside the actual iPhone 17 Pro Max hardware bezel captured from
  Apple’s installed Xcode Simulator, including its real Dynamic Island and
  physical side-button treatment
- straight, fully visible Apple hardware — no Android-style, generic, tilted,
  cropped, or AI-invented device shell

## Recommended upload order

1. **O‘zbekcha AI. Har kuni yoningizda.** — broad Uzbek-first product promise
2. **Rasm yuboring. Natijani ayting.** — multi-image editing workflow
3. **Ish uchun tayyor matnlar** — proposals, reports and formal writing
4. **Bitta ilova. O‘nlab vositalar.** — product breadth
5. **DTMga har kuni tayyorlaning** — high-intent student use case
6. **Taqdimot — bir necha daqiqada** — PPTX/PDF generator
7. **Referat va insho tayyor** — document generator
8. **Hujjatlar siz uchun ishlasin** — business documents
9. **Gapiring. Salom AI tinglaydi.** — native Uzbek voice conversation
10. **Davlat xizmatlarini oson toping** — Uzbekistan-specific official guidance

Candidates 11–15 are ideal for persona-specific Custom Product Pages or future
Product Page Optimization tests: salary, teacher, document explainer,
marketplace seller and family budget.

## Design rationale

- The hero image combines the recognizable Salom AI character with a real
  native chat result and a broad promise that works across student, work and
  everyday-life audiences.
- Dark screens provide strong App Store contrast; selective light screens make
  document-heavy workflows easier to scan.
- Headlines are short and benefit-led. Product evidence occupies most of each
  frame.
- Every device remains straight and fully visible so the native screen is easy
  to inspect and the Apple hardware treatment stays consistent across the set.
- The set avoids onboarding, login and splash screens because they do not prove
  product value.

## Source references

- Apple screenshot specifications:
  https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- Apple product page guidance:
  https://developer.apple.com/app-store/product-page/
- Apple review guidance for accurate metadata:
  https://developer.apple.com/app-store/review/guidelines/
- Apple Product Page Optimization:
  https://developer.apple.com/app-store/product-page-optimization/
- Apple marketing identity guidance:
  https://developer.apple.com/app-store/marketing/guidelines/
- Sensor Tower screenshot sequencing case study:
  https://sensortower.com/blog/case-study-how-a-slash-b-testing-can-improve-your-apps-conversion-rates
- SplitMetrics screenshot experiment case:
  https://splitmetrics.com/cases/prisma-optimizes-app-store-images/
