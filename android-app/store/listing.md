# Play Console — listing copy and form answers

Paste-ready. Default language **O'zbek (uz)**, with Russian and English translations.

---

## Assets in this folder

| File | Play field | Spec |
|---|---|---|
| `play-icon-512.png` | App icon | 512×512 PNG, no alpha ✅ |
| `feature-graphic.png` | Feature graphic | 1024×500 PNG ✅ |
| `screenshots/` | Phone screenshots | min 2, max 8. Generate with `../tools/capture-screenshots.sh <name>` from a signed-in device. |

Suggested screenshot set: Ilovalar hub · Chat mid-answer · Presentation result ·
Referat editor · DTM · Realtime voice overlay.

---

## Store listing

### App name
```
Salom AI
```

### Short description — uz (80 char max)
```
O‘zbekcha sun’iy intellekt: chat, taqdimot, referat, DTM va ovozli suhbat.
```
*(73 characters)*

### Short description — ru
```
Узбекский ИИ: чат, презентации, рефераты, ДТМ и голосовой помощник.
```

### Short description — en
```
Uzbek AI assistant: chat, presentations, essays, DTM prep and voice.
```

### Full description — uz
```
Salom AI — o‘zbek tilida gaplashadigan sun’iy intellekt yordamchisi. Savol bering,
tayyor ish oling: taqdimot, referat, ariza, xat va tahlil — hammasi o‘zbekcha.

NIMALAR QILA OLADI

• Chat — o‘zbek tilida savol-javob, matn yozish va tahrirlash
• Taqdimot — mavzuni yozing, tayyor PPTX slaydlarni yuklab oling
• Referat — tuzilgan, manbali referatni bir necha daqiqada oling
• DTM — test savollari, tushuntirishlar va tayyorgarlik rejasi
• Ish hujjatlari — ariza, tavsifnoma, hisobot va rasmiy xatlar
• Ovozli suhbat — real vaqtda o‘zbekcha gaplashing
• Rasm yaratish — matndan rasm
• Fayl tahlili — hujjat va rasmlarni yuklang, mazmunini so‘rang

NEGA SALOM AI

• O‘zbek tili uchun maxsus sozlangan — lotin va kirill yozuvlari
• Rus va ingliz tillari ham qo‘llab-quvvatlanadi
• Telegram, veb va iOS’dagi hisobingiz bilan bir xil — bir hisob, hamma joyda

Hisobingizga Google, Apple yoki Telegram orqali kiring.

Maxfiylik siyosati: https://salom-ai.uz/privacy-policy
Foydalanish shartlari: https://salom-ai.uz/terms-of-service
```

### Full description — ru
```
Salom AI — помощник на базе искусственного интеллекта, говорящий по-узбекски.
Задайте вопрос и получите готовый результат: презентацию, реферат, заявление,
письмо или анализ.

ВОЗМОЖНОСТИ

• Чат — вопросы и ответы, написание и редактирование текста
• Презентации — опишите тему, скачайте готовые слайды PPTX
• Рефераты — структурированный реферат с источниками за минуты
• ДТМ — тестовые вопросы, объяснения и план подготовки
• Рабочие документы — заявления, характеристики, отчёты, официальные письма
• Голосовой режим — разговор в реальном времени
• Генерация изображений по описанию
• Анализ файлов — загрузите документ или фото и спросите о содержании

ПОЧЕМУ SALOM AI

• Специально настроен для узбекского языка — латиница и кириллица
• Поддерживает также русский и английский
• Один аккаунт в Telegram, вебе и на iOS

Вход через Google, Apple или Telegram.

Политика конфиденциальности: https://salom-ai.uz/privacy-policy
Условия использования: https://salom-ai.uz/terms-of-service
```

### Full description — en
```
Salom AI is an AI assistant that speaks Uzbek. Ask a question, get finished work:
presentations, essays, applications, letters and analysis.

WHAT IT DOES

• Chat — questions, answers, writing and editing in Uzbek
• Presentations — describe a topic, download ready PPTX slides
• Essays (referat) — structured, sourced drafts in minutes
• DTM — practice questions, explanations and a study plan
• Work documents — applications, references, reports, formal letters
• Voice — real-time spoken conversation in Uzbek
• Image generation from a text prompt
• File analysis — upload a document or photo and ask about it

WHY SALOM AI

• Tuned specifically for Uzbek — both Latin and Cyrillic script
• Russian and English supported too
• One account across Telegram, web and iOS

Sign in with Google, Apple or Telegram.

Privacy policy: https://salom-ai.uz/privacy-policy
Terms of service: https://salom-ai.uz/terms-of-service
```

---

## App content — form answers

| Question | Answer |
|---|---|
| Privacy policy URL | `https://salom-ai.uz/privacy-policy` |
| Ads | **No** — `web/src/lib/ads.ts` has `YANDEX_ENABLED = false` (site pending YAN re-moderation). **Change to Yes if that flips before launch.** |
| App access | **Some functionality is restricted.** Reviewers cannot receive an Uzbek SMS or drive your Telegram bot — provide a working Google account, or confirm the dev-bypass number still works on the backend. |
| Content rating | Complete the questionnaire: user-generated AI text/images, no violence, no gambling. Expect Everyone / Teen. |
| Target audience | **13+** |
| News app | No |
| Government app | No |
| Financial features | No |
| Data safety | See below |

### Data safety

Collected and linked to the user:

| Type | Purpose | Notes |
|---|---|---|
| Name, email address | Account management | From Google/Apple/Telegram sign-in |
| Phone number | Account management | Telegram phone→bot→code login |
| Photos / files | App functionality | User-uploaded attachments for analysis |
| Audio | App functionality | Realtime voice; transcribed, used to answer |
| App interactions | Analytics, App functionality | Product analytics |
| Purchase history | App functionality | Subscription state |

Declare: **encrypted in transit** (HTTPS/WSS throughout) and **users can request
deletion**.

> **Account deletion URL is required.** The in-app path exists
> (`web/src/pages/Settings.tsx:534` → `DELETE /account`), but Play also wants a
> *publicly reachable* URL explaining how to request deletion. `/settings` is behind
> auth, so either add a short public page or a deletion section in
> `/privacy-policy` and point Play at it. **This is the one store-form item that
> needs a small web change.**

---

## Release notes template

```
uz: Android uchun birinchi versiya. Chat, taqdimot, referat, DTM va ovozli suhbat.
ru: Первая версия для Android. Чат, презентации, рефераты, ДТМ и голосовой режим.
en: First Android release. Chat, presentations, essays, DTM and voice.
```

---

## Countries

Uzbekistan first. Add the diaspora (Russia, Kazakhstan, Turkey, South Korea, USA)
once the first rollout is stable — the app is language-, not geo-, targeted.
