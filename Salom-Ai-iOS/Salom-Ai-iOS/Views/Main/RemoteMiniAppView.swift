import SwiftUI

enum NativeMiniAppKind: String {
    case officialGuide
    case calculator
    case assistant
}

struct NativeMiniAppSource: Identifiable {
    let id = UUID()
    let title: IlovalarView.Copy
    let url: URL
    let lastVerified: String
}

struct RemoteMiniApp: Identifiable {
    let id: String
    let kind: NativeMiniAppKind
    let title: IlovalarView.Copy
    let subtitle: IlovalarView.Copy
    let description: IlovalarView.Copy
    let benefit: IlovalarView.Copy
    let prompt: IlovalarView.Copy
    let tags: [IlovalarView.Copy]
    let sources: [NativeMiniAppSource]
    let imageKey: String
    let systemImage: String
    let colors: [Color]
    let paywallContext: PaywallContextID

    static let catalog: [RemoteMiniApp] = [
        .init(
            id: "document-explainer", kind: .assistant,
            title: copy("Hujjatni tushuntirish", "Объяснить документ", "Explain a document"),
            subtitle: copy("PDF va rasmdagi matn — sodda tilda", "PDF и фото — простыми словами", "PDF and photos in plain language"),
            description: copy("Rasm yoki fayldagi murakkab matnni sodda tilda tushuning.", "Поймите сложный текст из фото или файла простыми словами.", "Understand complex text in a photo or file in plain language."),
            benefit: copy("Bandlar, muddatlar va xavfli joylar — qisqa xulosa bilan.", "Пункты, сроки и риски — с кратким выводом.", "Clauses, dates and risks—with a concise summary."),
            prompt: copy("Bu hujjatni oddiy tilda tushuntiring. Muhim bandlar, muddatlar, to‘lovlar, majburiyatlar va men e’tibor berishim kerak bo‘lgan xavflarni alohida ro‘yxat qiling. Hujjatni biriktiraman.", "Объясните этот документ простыми словами. Отдельно перечислите важные пункты, сроки, платежи, обязательства и риски. Я приложу документ.", "Explain this document in plain language. List important clauses, dates, payments, obligations and risks separately. I will attach the document."),
            tags: [copy("PDF va rasm", "PDF и фото", "PDF & photo"), copy("Sodda izoh", "Простое объяснение", "Plain language")],
            sources: [], imageKey: "document-explainer", systemImage: "doc.text.magnifyingglass",
            colors: [.cyan, .indigo], paywallContext: .documentExplainerPro
        ),
        .init(
            id: "government-guide", kind: .officialGuide,
            title: copy("Davlat xizmatlari yo‘riqchisi", "Навигатор госуслуг", "Government services guide"),
            subtitle: copy("MyGov, hujjatlar va qadamlar", "MyGov, документы и шаги", "MyGov, documents and steps"),
            description: copy("Kerakli MyGov xizmatini, hujjatlarni va keyingi qadamni toping.", "Найдите услугу MyGov, документы и следующий шаг.", "Find the right MyGov service, required documents and next step."),
            benefit: copy("Faqat rasmiy havolalar. Ariza rasmiy portalda yuboriladi.", "Только официальные ссылки. Заявление подаётся на официальном портале.", "Official links only. Applications are submitted on the official portal."),
            prompt: copy("Menga O‘zbekistondagi kerakli davlat xizmatini topishga yordam bering. Vaziyatimni so‘rang, so‘ng faqat rasmiy my.gov.uz yoki gov.uz manbasiga tayangan holda hujjatlar, muddat, narx va aniq qadamlarni tushuntiring.", "Помогите найти нужную государственную услугу в Узбекистане. Уточните ситуацию, затем объясните документы, срок, цену и шаги, используя только my.gov.uz или gov.uz.", "Help me find the right government service in Uzbekistan. Ask about my situation, then explain documents, timing, price and steps using only my.gov.uz or gov.uz."),
            tags: [copy("Rasmiy", "Официально", "Official"), copy("MyGov", "MyGov", "MyGov")],
            sources: [
                source("MyGov mashhur xizmatlari", "Популярные услуги MyGov", "MyGov popular services", "https://my.gov.uz/uz/popular"),
                source("MyGov xizmatlar xaritasi", "Карта услуг MyGov", "MyGov service map", "https://my.gov.uz/uz/siteMap"),
            ], imageKey: "government-guide", systemImage: "building.columns.fill",
            colors: [.cyan, .blue], paywallContext: .governmentGuidePro
        ),
        .init(
            id: "tax-self-employed", kind: .officialGuide,
            title: copy("Soliq va o‘zini o‘zi band qilish", "Налоги и самозанятость", "Tax & self-employment"),
            subtitle: copy("Rasmiy yo‘l va hisob", "Официальный путь и расчёт", "Official path and estimate"),
            description: copy("O‘zini o‘zi band qilish, soliq va ro‘yxatdan o‘tish bo‘yicha aniq yo‘l.", "Понятный путь по самозанятости, налогам и регистрации.", "A clear path for self-employment, taxes and registration."),
            benefit: copy("Daromadni hisoblang, holatingizga mos rasmiy qadamlarni oling.", "Рассчитайте доход и получите официальные шаги для своей ситуации.", "Estimate income and get official steps for your situation."),
            prompt: copy("O‘zbekistonda o‘zini o‘zi band qilish va soliqlar bo‘yicha menga yo‘l-yo‘riq bering. Faoliyatim, oylik tushumim va hozirgi maqomimni so‘rang. Javobda amaldagi sanani va rasmiy manbani ko‘rsating; bu professional soliq maslahati emasligini ayting.", "Дайте мне инструкцию по самозанятости и налогам в Узбекистане. Спросите о деятельности, месячном доходе и текущем статусе. Укажите дату и официальный источник; отметьте, что это не профессиональная налоговая консультация.", "Guide me through self-employment and taxes in Uzbekistan. Ask about my activity, monthly revenue and current status. Cite the effective date and official source, and state that this is not professional tax advice."),
            tags: [copy("Soliq", "Налоги", "Tax"), copy("Ro‘yxatdan o‘tish", "Регистрация", "Registration")],
            sources: [
                source("O‘zini o‘zi band qilish xizmati", "Регистрация самозанятых", "Self-employment registration", "https://my.gov.uz/uz/service/491"),
                source("2026-yil soliq stavkalari", "Налоговые ставки 2026 года", "2026 tax rates", "https://gov.uz/oz/urganch/news/view/138410"),
            ], imageKey: "tax-self-employed", systemImage: "percent",
            colors: [.green, .teal], paywallContext: .taxPlannerPro
        ),
        .init(
            id: "salary-employment", kind: .calculator,
            title: copy("Ish haqi va mehnat", "Зарплата и труд", "Salary & employment"),
            subtitle: copy("Brutto-netto va mehnat staji", "Брутто-нетто и стаж", "Gross-net and work history"),
            description: copy("Brutto-netto hisob, ish staji va ma’lumotnomalar bo‘yicha yo‘l.", "Расчёт брутто-нетто, стаж и справки.", "Gross-to-net estimate, work history and certificates."),
            benefit: copy("Taxminiy sof maoshni ko‘ring va kerakli rasmiy xizmatni oching.", "Узнайте примерную чистую зарплату и откройте официальную услугу.", "See estimated net salary and open the right official service."),
            prompt: copy("O‘zbekistondagi ish haqi va mehnat masalasida yordam bering. Brutto maoshim, ish turi va muammomni so‘rang. Amaldagi stavka va rasmiy manbaga tayangan holda taxminiy hisob va qadamlarni ko‘rsating.", "Помогите по зарплате и трудовым вопросам в Узбекистане. Спросите брутто-зарплату, тип занятости и проблему. Дайте примерный расчёт и шаги по актуальной ставке и официальным источникам.", "Help with salary and employment matters in Uzbekistan. Ask for gross salary, employment type and issue. Give an estimate and steps using current rates and official sources."),
            tags: [copy("Maosh", "Зарплата", "Salary"), copy("Mehnat staji", "Трудовой стаж", "Work history")],
            sources: [
                source("Mehnat daftarchasidan ko‘chirma", "Выписка из трудовой книжки", "Employment record extract", "https://my.gov.uz/service/496"),
                source("Ish haqi ma’lumotnomasi", "Справка о зарплате", "Salary certificate", "https://my.gov.uz/uz/service/263"),
                source("Mehnat tarixini tuzatish", "Исправление трудовой истории", "Correct employment history", "https://my.gov.uz/uz/service/859"),
            ], imageKey: "salary-employment", systemImage: "banknote.fill",
            colors: [.blue, .cyan], paywallContext: .salaryPlannerPro
        ),
        .init(
            id: "vehicle-assistant", kind: .calculator,
            title: copy("Avtomobil yordamchisi", "Автопомощник", "Vehicle assistant"),
            subtitle: copy("Safar xarajati va rasmiy xizmatlar", "Расход поездки и автоуслуги", "Trip cost and services"),
            description: copy("Safar xarajati, ishonchnoma va avtomobil xizmatlari bir joyda.", "Расход поездки, доверенность и автоуслуги в одном месте.", "Trip cost, power of attorney and vehicle services in one place."),
            benefit: copy("Yoqilg‘i xarajatini hisoblang va rasmiy xizmatga to‘g‘ri o‘ting.", "Рассчитайте топливо и перейдите к нужной официальной услуге.", "Calculate fuel cost and reach the correct official service."),
            prompt: copy("O‘zbekistonda avtomobil bo‘yicha masalamni hal qilishga yordam bering. Safar hisobi, elektron ishonchnoma yoki boshqa xizmat ekanini aniqlang va faqat rasmiy manbaga havola bering.", "Помогите решить вопрос с автомобилем в Узбекистане. Уточните: расчёт поездки, электронная доверенность или другая услуга, и дайте ссылку только на официальный источник.", "Help solve my vehicle-related task in Uzbekistan. Determine whether I need a trip estimate, electronic power of attorney or another service, and link only to an official source."),
            tags: [copy("Yoqilg‘i", "Топливо", "Fuel"), copy("Ishonchnoma", "Доверенность", "Power of attorney")],
            sources: [source("Elektron ishonchnoma", "Электронная доверенность", "Electronic power of attorney", "https://my.gov.uz/uz/service/get/640")],
            imageKey: "vehicle-assistant", systemImage: "car.fill",
            colors: [.indigo, .blue], paywallContext: .vehicleAssistantPro
        ),
        .init(
            id: "money-planner", kind: .calculator,
            title: copy("Oila byudjeti", "Семейный бюджет", "Family budget"),
            subtitle: copy("Xarajat, qarz va jamg‘arma", "Расходы, долги и накопления", "Expenses, debt and savings"),
            description: copy("Daromad, xarajat, qarz va jamg‘armani sodda rejalashtiring.", "Просто планируйте доходы, расходы, долги и накопления.", "Plan income, expenses, debt and savings simply."),
            benefit: copy("Oy oxiridagi qoldiq va real jamg‘arma rejasini ko‘ring.", "Увидьте остаток месяца и реалистичный план накоплений.", "See your month-end balance and a realistic savings plan."),
            prompt: copy("Oylik oilaviy byudjetimni tuzishga yordam bering. Daromad, majburiy xarajat, qarz to‘lovi va maqsadimni so‘rang. O‘zbekiston so‘mida sodda jadval va xavfsiz, real reja tuzing.", "Помогите составить семейный бюджет на месяц. Спросите доход, обязательные расходы, платежи по долгам и цель. Составьте простую таблицу в сумах и реалистичный безопасный план.", "Help me build a monthly family budget. Ask for income, essential expenses, debt payments and goal. Create a simple UZS table and a realistic, safe plan."),
            tags: [copy("Byudjet", "Бюджет", "Budget"), copy("Jamg‘arma", "Накопления", "Savings")],
            sources: [], imageKey: "money-planner", systemImage: "chart.pie.fill",
            colors: [.orange, .yellow], paywallContext: .moneyPlannerPro
        ),
        assistant(
            id: "job-assistant", title: ("Ish topish yordamchisi", "Помощник по поиску работы", "Job search assistant"),
            subtitle: ("CV, vakansiya va suhbat", "Резюме, вакансия и интервью", "CV, vacancy and interview"),
            description: ("CV, vakansiya tahlili va suhbatga tayyorgarlik.", "Резюме, разбор вакансии и подготовка к интервью.", "CV, vacancy analysis and interview practice."),
            benefit: ("Vakansiyaga mos, aniq va rost CV yarating.", "Создайте точное и честное резюме под вакансию.", "Create an accurate, honest CV tailored to a vacancy."),
            prompt: ("O‘zbekistonda ish topishimga yordam bering. Lavozim, tajriba, ko‘nikmalar va vakansiya matnini so‘rang. Menga mos CV, qisqa cover letter va suhbat savollarini tayyorlang. Tajribamni uydirmang.", "Помогите найти работу в Узбекистане. Спросите должность, опыт, навыки и текст вакансии. Подготовьте резюме, короткое сопроводительное письмо и вопросы для интервью. Не выдумывайте мой опыт.", "Help me find a job in Uzbekistan. Ask for the role, experience, skills and vacancy text. Prepare a tailored CV, short cover letter and interview questions. Do not invent experience."),
            tags: [("CV", "Резюме", "CV"), ("Suhbat", "Интервью", "Interview")],
            sourceItems: [("Mehnat xizmatlari", "Услуги по труду", "Employment services", "https://my.gov.uz/uz/siteMap")],
            image: "job-assistant", icon: "person.text.rectangle.fill", colors: [.purple, .indigo], paywall: .jobAssistantPro
        ),
        assistant(
            id: "migrant-helper", title: ("Safar va migrant yo‘riqchisi", "Навигатор для поездок и мигрантов", "Travel & migrant guide"),
            subtitle: ("Hujjat va xavfsizlik ro‘yxati", "Документы и безопасность", "Documents and safety"),
            description: ("Safar oldidan hujjatlar, xavfsizlik va rasmiy xizmatlar ro‘yxati.", "Документы, безопасность и официальные услуги перед поездкой.", "Documents, safety and official services before travel."),
            benefit: ("Mamlakat va maqsadingizga mos tekshiruv ro‘yxati.", "Чек-лист под вашу страну и цель поездки.", "A checklist tailored to your destination and purpose."),
            prompt: ("O‘zbekistondan chet elga safar yoki ishlash uchun xavfsiz tayyorgarlik yo‘riqchisi tuzing. Mamlakat, maqsad va muddatni so‘rang. Faqat rasmiy elchixona, migratsiya va gov.uz manbalarini tavsiya qiling; vositachilarga pul yuborishni tavsiya qilmang.", "Составьте безопасный чек-лист для поездки или работы за границей из Узбекистана. Спросите страну, цель и срок. Рекомендуйте только официальные источники посольств, миграционных служб и gov.uz; не советуйте платить посредникам.", "Build a safe checklist for travel or work abroad from Uzbekistan. Ask destination, purpose and duration. Recommend only official embassy, migration and gov.uz sources; never advise paying intermediaries."),
            tags: [("Hujjatlar", "Документы", "Documents"), ("Xavfsizlik", "Безопасность", "Safety")],
            sourceItems: [
                ("Migratsiya agentligi: soxta kanallardan ogohlantirish", "Агентство миграции: предупреждение о фальшивых каналах", "Migration Agency warning about fake channels", "https://gov.uz/oz/migration/news/view/194361"),
                ("Migratsiya agentligi: safar xavfsizligi", "Агентство миграции: безопасность поездки", "Migration Agency travel safety", "https://gov.uz/oz/migration/news/view/168551"),
            ], image: "migrant-helper", icon: "airplane.departure", colors: [.cyan, .teal], paywall: .migrantHelperPro
        ),
        assistant(
            id: "family-benefits", kind: .officialGuide,
            title: ("Oila va nafaqa yo‘riqchisi", "Семья и пособия", "Family & benefits guide"),
            subtitle: ("Bola, bog‘cha va yordam xizmatlari", "Дети, сад и помощь", "Child, kindergarten and support"),
            description: ("Bolalar, bog‘cha va oilaviy yordam xizmatlarini toping.", "Найдите услуги для детей, детского сада и семейной помощи.", "Find child, kindergarten and family support services."),
            benefit: ("Vaziyatingizga mos rasmiy xizmat va hujjatlar ro‘yxati.", "Официальная услуга и список документов для вашей ситуации.", "The official service and document list for your situation."),
            prompt: ("O‘zbekistonda oila, bola nafaqasi yoki bog‘cha bo‘yicha kerakli rasmiy xizmatni topishga yordam bering. Vaziyatimni aniqlashtiring va faqat my.gov.uz/gov.uz manbasi bilan aniq qadamlarni bering.", "Помогите найти официальную услугу в Узбекистане по семье, детскому пособию или детскому саду. Уточните ситуацию и дайте шаги только по my.gov.uz/gov.uz.", "Help find the correct official family, child benefit or kindergarten service in Uzbekistan. Clarify my situation and give steps only from my.gov.uz/gov.uz."),
            tags: [("Nafaqa", "Пособия", "Benefits"), ("Bog‘cha", "Детский сад", "Kindergarten")],
            sourceItems: [
                ("Bolalar nafaqasi yoki moddiy yordam", "Детское пособие или материальная помощь", "Child benefit or financial assistance", "https://my.gov.uz/uz/service/1017"),
                ("Bolani davlat bog‘chasiga joylashtirish", "Запись ребёнка в государственный детский сад", "Apply for a public kindergarten place", "https://my.gov.uz/uz/service/285"),
            ], image: "family-benefits", icon: "figure.2.and.child.holdinghands", colors: [.pink, .red], paywall: .familyBenefitsPro
        ),
        assistant(
            id: "teacher-assistant", title: ("O‘qituvchi yordamchisi", "Помощник учителя", "Teacher assistant"),
            subtitle: ("Dars, test va baholash", "Уроки, тесты и оценивание", "Lessons, quizzes and assessment"),
            description: ("Dars rejasi, test, rubrika va ota-onaga hisobot.", "План урока, тест, рубрика и отчёт родителям.", "Lesson plan, quiz, rubric and parent report."),
            benefit: ("Sinf, fan va vaqtga mos tayyor material.", "Готовый материал под класс, предмет и время.", "Ready material tailored to grade, subject and duration."),
            prompt: ("O‘zbekiston maktabi uchun dars materialini tayyorlashga yordam bering. Fan, sinf, mavzu, dars davomiyligi va tilini so‘rang. Maqsad, faoliyat, baholash va uy vazifasini yoshga mos tuzing.", "Помогите подготовить материал для школы Узбекистана. Спросите предмет, класс, тему, длительность и язык. Составьте цели, активности, оценивание и домашнее задание по возрасту.", "Help prepare material for an Uzbekistan school. Ask subject, grade, topic, duration and language. Create age-appropriate objectives, activities, assessment and homework."),
            tags: [("Dars rejasi", "План урока", "Lesson plan"), ("Test", "Тест", "Quiz")],
            image: "teacher-assistant", icon: "person.fill.viewfinder", colors: [.green, .cyan], paywall: .teacherAssistantPro
        ),
        assistant(
            id: "utilities-helper", title: ("Kommunal yordamchi", "Коммунальный помощник", "Utilities helper"),
            subtitle: ("Hisob va murojaatni tushuning", "Разбор счетов и обращений", "Bills and service requests"),
            description: ("Hisob-kitobni tushuning, murojaat va shikoyat matnini tayyorlang.", "Разберите начисления, подготовьте обращение или жалобу.", "Understand charges and prepare a request or complaint."),
            benefit: ("Raqamlar va kvitansiyani sodda izohga aylantiring.", "Превратите цифры и квитанцию в понятное объяснение.", "Turn bills and numbers into a clear explanation."),
            prompt: ("O‘zbekistondagi kommunal to‘lov yoki xizmat muammosini tushunishga yordam bering. Xizmat turi, hudud, kvitansiya raqamlari va muammoni so‘rang. Hisobni tushuntiring va kerak bo‘lsa hurmatli murojaat matnini yozing. Shaxsiy hisob raqamini to‘liq yubormaslikni eslating.", "Помогите разобраться с коммунальным платежом или услугой в Узбекистане. Спросите вид услуги, регион, данные квитанции и проблему. Объясните начисление и при необходимости составьте вежливое обращение. Напомните не отправлять полный лицевой счёт.", "Help understand a utility payment or service issue in Uzbekistan. Ask service type, region, bill figures and issue. Explain the charge and draft a polite request if needed. Remind me not to share the full account number."),
            tags: [("Kvitansiya", "Квитанция", "Bill"), ("Murojaat", "Обращение", "Request")],
            sourceItems: [
                ("Sovuq suv hisoblagichini o‘rnatish va tamg‘alash", "Установка и опломбировка счётчика холодной воды", "Install and seal a cold-water meter", "https://my.gov.uz/uz/service/224"),
                ("MyGov gaz xizmatlari bo‘yicha rasmiy yangilik", "Официальное обновление MyGov по газовым услугам", "Official MyGov update on gas services", "https://my.gov.uz/uz/news/c09d8529-bd3f-46ef-bc85-2726edf94942"),
            ], image: "utilities-helper", icon: "drop.fill", colors: [.cyan, .blue], paywall: .utilitiesHelperPro
        ),
        assistant(
            id: "marketplace-seller", title: ("Onlayn sotuvchi yordamchisi", "Помощник онлайн-продавца", "Online seller assistant"),
            subtitle: ("Mahsulot kartasi va savdo", "Карточка товара и продажи", "Listings and sales"),
            description: ("Mahsulot kartasi, narx, javoblar va savdo rejasini tayyorlang.", "Карточка товара, цена, ответы и план продаж.", "Build product listings, pricing, replies and a sales plan."),
            benefit: ("O‘zbek va rus tilida sotadigan aniq matnlar.", "Продающие тексты на узбекском и русском.", "Clear sales copy in Uzbek and Russian."),
            prompt: ("O‘zbekistonda onlayn mahsulot sotishimga yordam bering. Mahsulot, xaridor, tannarx, platforma va tilni so‘rang. Rost, tushunarli mahsulot nomi, tavsif, afzalliklar, savol-javob va narx hisobini tayyorlang. Asossiz va’dalar bermang.", "Помогите продавать товар онлайн в Узбекистане. Спросите товар, покупателя, себестоимость, платформу и язык. Подготовьте честное название, описание, преимущества, ответы и расчёт цены. Не давайте необоснованных обещаний.", "Help me sell a product online in Uzbekistan. Ask product, audience, cost, platform and language. Create an honest title, description, benefits, FAQ and price calculation. Do not make unsupported claims."),
            tags: [("Mahsulot kartasi", "Карточка товара", "Listing"), ("Savdo", "Продажи", "Sales")],
            image: "marketplace-seller", icon: "shippingbox.fill", colors: [.orange, .pink], paywall: .marketplaceSellerPro
        ),
        assistant(
            id: "voice-notes", title: ("Ovozli yozuvdan natija", "Результат из голосовой записи", "Voice note to action"),
            subtitle: ("Xulosa, vazifa va tayyor matn", "Итог, задачи и готовый текст", "Summary, tasks and polished text"),
            description: ("Ovozli fikrni xulosa, vazifa yoki tayyor matnga aylantiring.", "Превратите голосовую мысль в итог, задачи или готовый текст.", "Turn a voice thought into a summary, tasks or polished text."),
            benefit: ("Gapiring — tartibli natijani oling.", "Говорите — получите структурированный результат.", "Speak and get a structured result."),
            prompt: ("Ovozli yozuvimni tahlil qiling. Avval qisqa xulosa, so‘ng vazifalar, muddatlar va muhim qarorlarni alohida yozing. Noaniq joylarni uydirmang, mendan so‘rang.", "Разберите мою голосовую запись. Сначала дайте краткий итог, затем отдельно задачи, сроки и важные решения. Не додумывайте неясное — спросите меня.", "Analyze my voice note. First provide a short summary, then list tasks, deadlines and key decisions. Do not invent unclear details—ask me."),
            tags: [("Xulosa", "Итог", "Summary"), ("Vazifalar", "Задачи", "Tasks")],
            image: "voice-notes", icon: "waveform.badge.mic", colors: [.purple, .indigo], paywall: .voiceNotesPro
        ),
        assistant(
            id: "farmer-assistant", title: ("Dehqon yordamchisi", "Помощник фермера", "Farmer assistant"),
            subtitle: ("Ekin, xarajat va mavsum rejasi", "Посевы, затраты и сезон", "Crops, costs and season plan"),
            description: ("Ekin rejasi, xarajat va kundalik ishlar uchun sodda yordam.", "Простая помощь по посевам, затратам и ежедневным работам.", "Simple help for crop planning, costs and daily work."),
            benefit: ("Hudud va mavsumga mos savollar bilan amaliy reja.", "Практичный план с учётом региона и сезона.", "A practical plan tailored to region and season."),
            prompt: ("O‘zbekistondagi dehqonchilik vazifamni rejalashtirishga yordam bering. Viloyat, ekin, maydon, suv manbasi va mavsumni so‘rang. Xarajat va ishlar jadvalini tuzing. Pestitsid dozalari yoki xavfli kimyoviy ko‘rsatmalar bermang; agronom va rasmiy manbani tavsiya qiling.", "Помогите спланировать сельскохозяйственную задачу в Узбекистане. Спросите область, культуру, площадь, источник воды и сезон. Составьте график работ и затрат. Не давайте дозировки пестицидов или опасные химические инструкции; рекомендуйте агронома и официальные источники.", "Help plan a farming task in Uzbekistan. Ask region, crop, area, water source and season. Build a work and cost schedule. Do not provide pesticide dosages or hazardous chemical instructions; recommend an agronomist and official sources."),
            tags: [("Ekin rejasi", "План посевов", "Crop plan"), ("Xarajat", "Затраты", "Costs")],
            sourceItems: [("Qishloq xo‘jaligi vazirligi", "Министерство сельского хозяйства", "Ministry of Agriculture", "https://gov.uz/oz/agro")],
            image: "farmer-assistant", icon: "leaf.fill", colors: [.green, .teal], paywall: .farmerAssistantPro
        ),
        assistant(
            id: "health-visit", title: ("Shifokorga tayyorgarlik", "Подготовка к врачу", "Prepare for a doctor visit"),
            subtitle: ("Alomat va savollarni tartiblang", "Симптомы и вопросы по порядку", "Organize symptoms and questions"),
            description: ("Alomatlar, savollar va dori ro‘yxatini shifokor uchun tartiblang.", "Структурируйте симптомы, вопросы и лекарства для врача.", "Organize symptoms, questions and medicines for a doctor."),
            benefit: ("Qabulda muhim narsani unutmaslik uchun qisqa varaq.", "Краткий лист, чтобы не забыть важное на приёме.", "A concise visit sheet so you do not forget what matters."),
            prompt: ("Shifokor qabuliga tayyorgarlik varag‘ini tuzishga yordam bering. Alomat, qachondan boshlangan, kuchaytiruvchi omil, dorilar va allergiyalarni so‘rang. Tashxis qo‘ymang. Shoshilinch xavf belgisi bo‘lsa tez yordamga murojaat qilishni ayting.", "Помогите подготовить лист к приёму врача. Спросите симптомы, начало, усиливающие факторы, лекарства и аллергии. Не ставьте диагноз. При опасных признаках советуйте срочно обратиться за медицинской помощью.", "Help prepare a doctor-visit sheet. Ask symptoms, onset, aggravating factors, medicines and allergies. Do not diagnose. If there are emergency warning signs, advise urgent medical care."),
            tags: [("Qabul varag‘i", "Лист для приёма", "Visit sheet"), ("Xavfsiz", "Безопасно", "Safety first")],
            sourceItems: [("Sog‘liqni saqlash vazirligi", "Министерство здравоохранения", "Ministry of Health", "https://gov.uz/oz/ssv")],
            image: "health-visit", icon: "cross.case.fill", colors: [.pink, .red], paywall: .healthVisitPro
        ),
    ]

    private static func copy(_ uz: String, _ ru: String, _ en: String) -> IlovalarView.Copy {
        .init(uz: uz, cyrl: UzCyrillic.toCyrillic(uz), ru: ru, en: en)
    }

    private static func source(_ uz: String, _ ru: String, _ en: String, _ rawURL: String) -> NativeMiniAppSource {
        .init(title: copy(uz, ru, en), url: URL(string: rawURL)!, lastVerified: "2026-07-24")
    }

    private static func assistant(
        id: String,
        kind: NativeMiniAppKind = .assistant,
        title: (String, String, String),
        subtitle: (String, String, String),
        description: (String, String, String),
        benefit: (String, String, String),
        prompt: (String, String, String),
        tags: [(String, String, String)],
        sourceItems: [(String, String, String, String)] = [],
        image: String,
        icon: String,
        colors: [Color],
        paywall: PaywallContextID
    ) -> RemoteMiniApp {
        .init(
            id: id, kind: kind,
            title: copy(title.0, title.1, title.2),
            subtitle: copy(subtitle.0, subtitle.1, subtitle.2),
            description: copy(description.0, description.1, description.2),
            benefit: copy(benefit.0, benefit.1, benefit.2),
            prompt: copy(prompt.0, prompt.1, prompt.2),
            tags: tags.map { copy($0.0, $0.1, $0.2) },
            sources: sourceItems.map { source($0.0, $0.1, $0.2, $0.3) },
            imageKey: image, systemImage: icon, colors: colors, paywallContext: paywall
        )
    }
}

struct RemoteMiniAppView: View {
    let app: RemoteMiniApp
    var onStart: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode = "uz"
    @StateObject private var subscription = SubscriptionManager.shared
    @State private var showPaywall = false
    @State private var grossSalary = ""
    @State private var monthlyIncome = ""
    @State private var monthlyExpenses = ""
    @State private var distance = ""
    @State private var consumption = ""
    @State private var fuelPrice = ""

    var body: some View {
        NavigationStack {
            ZStack {
                SalomTheme.Gradients.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        hero
                        tagRow
                        valueCard
                        if app.kind == .calculator { calculator }
                        sourceSection
                        safetyNotice
                        actions
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle(app.title.pick(languageCode))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(SalomTheme.Colors.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(SalomTheme.Colors.surface, in: Circle())
                    }
                    .accessibilityLabel(text("Yopish", "Закрыть", "Close"))
                }
            }
            .toolbarBackground(SalomTheme.Colors.bgMain, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallSheet(context: app.paywallContext, source: "ios_mini_app_\(app.id)")
        }
        .task {
            Analytics.shared.track("mini_app_view", ["app_id": app.id, "surface": "ios_native"])
            if TokenStore.shared.accessToken != nil {
                await subscription.checkSubscriptionStatus()
            }
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: app.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            AsyncImage(url: URL(string: "https://salom-ai.uz/mini-app-assets/\(app.imageKey).webp")) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: app.systemImage)
                        .font(.system(size: 72, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 7) {
                Text(app.title.pick(languageCode))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(app.subtitle.pick(languageCode))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(20)
        }
        .frame(height: 270)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.16)))
        .shadow(color: app.colors.first?.opacity(0.18) ?? .clear, radius: 22, y: 10)
    }

    private var tagRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(app.tags.enumerated()), id: \.offset) { _, tag in
                    Text(tag.pick(languageCode))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SalomTheme.Colors.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(SalomTheme.Colors.surfaceMuted, in: Capsule())
                }
            }
        }
    }

    private var valueCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(text("Siz oladigan natija", "Что вы получите", "What you get"), systemImage: "sparkles")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(app.colors.first ?? SalomTheme.Colors.accentPrimary)
            Text(app.description.pick(languageCode))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SalomTheme.Colors.textPrimary)
            Text(app.benefit.pick(languageCode))
                .font(.system(size: 15))
                .foregroundStyle(SalomTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(SalomTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(SalomTheme.Colors.border))
    }

    @ViewBuilder private var calculator: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(text("Tezkor hisob", "Быстрый расчёт", "Quick calculator"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(SalomTheme.Colors.textPrimary)
            switch app.id {
            case "salary-employment":
                numberField(text("Brutto oylik maosh", "Зарплата брутто", "Gross monthly salary"), value: $grossSalary)
                resultRow(
                    text("Taxminiy sof maosh", "Примерная чистая зарплата", "Estimated net salary"),
                    amount: number(grossSalary) * 0.88
                )
            case "money-planner":
                numberField(text("Oylik daromad", "Доход за месяц", "Monthly income"), value: $monthlyIncome)
                numberField(text("Barcha oylik xarajatlar", "Все расходы за месяц", "Total monthly expenses"), value: $monthlyExpenses)
                resultRow(
                    text("Oy oxiridagi qoldiq", "Остаток в конце месяца", "Month-end balance"),
                    amount: number(monthlyIncome) - number(monthlyExpenses)
                )
            case "vehicle-assistant":
                numberField(text("Masofa (km)", "Расстояние (км)", "Distance (km)"), value: $distance)
                numberField(text("100 km ga litr", "Литров на 100 км", "Litres per 100 km"), value: $consumption)
                numberField(text("1 litr narxi", "Цена 1 литра", "Price per litre"), value: $fuelPrice)
                resultRow(
                    text("Taxminiy yoqilg‘i xarajati", "Примерная стоимость топлива", "Estimated fuel cost"),
                    amount: (number(distance) / 100) * number(consumption) * number(fuelPrice)
                )
            default:
                EmptyView()
            }
            Text(text("Hisob taxminiy. Amaldagi talab va stavkani rasmiy manbada tekshiring.", "Расчёт приблизительный. Проверьте актуальные требования и ставки в официальном источнике.", "This is an estimate. Check current requirements and rates at the official source."))
                .font(.system(size: 12))
                .foregroundStyle(SalomTheme.Colors.textTertiary)
        }
        .padding(18)
        .background(SalomTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(SalomTheme.Colors.border))
    }

    private func numberField(_ title: String, value: Binding<String>) -> some View {
        TextField(title, text: value)
            .keyboardType(.decimalPad)
            .textFieldStyle(.plain)
            .foregroundStyle(SalomTheme.Colors.textPrimary)
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(SalomTheme.Colors.controlFill, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(SalomTheme.Colors.border))
    }

    private func resultRow(_ label: String, amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption).foregroundStyle(SalomTheme.Colors.textSecondary)
            Text(currency(amount))
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(amount < 0 ? SalomTheme.Colors.danger : SalomTheme.Colors.success)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(SalomTheme.Colors.surfaceMuted, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder private var sourceSection: some View {
        if !app.sources.isEmpty {
            VStack(alignment: .leading, spacing: 11) {
                Label(text("Rasmiy manbalar", "Официальные источники", "Official sources"), systemImage: "checkmark.shield.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(SalomTheme.Colors.textPrimary)
                ForEach(app.sources) { source in
                    Button {
                        openURL(source.url)
                        Analytics.shared.track("mini_app_official_source_open", ["app_id": app.id, "url": source.url.absoluteString])
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "safari.fill")
                                .foregroundStyle(SalomTheme.Colors.accentPrimary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(source.title.pick(languageCode))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(SalomTheme.Colors.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Text(text("Tekshirildi: \(source.lastVerified)", "Проверено: \(source.lastVerified)", "Verified: \(source.lastVerified)"))
                                    .font(.caption2)
                                    .foregroundStyle(SalomTheme.Colors.textTertiary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(SalomTheme.Colors.textSecondary)
                        }
                        .padding(14)
                        .background(SalomTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(SalomTheme.Colors.border))
                    }
                    .buttonStyle(.plain)
                }
                Text(text("Narxlar va talablar o‘zgarishi mumkin. Ariza faqat rasmiy portalda yuboriladi.", "Цены и требования могут измениться. Заявка подаётся только на официальном портале.", "Prices and requirements can change. Submit applications only on the official portal."))
                    .font(.system(size: 12))
                    .foregroundStyle(SalomTheme.Colors.textTertiary)
            }
        }
    }

    private var safetyNotice: some View {
        Label(
            text("Pasport, JShShIR, karta raqami yoki SMS kodni yubormang.", "Не отправляйте паспорт, ПИНФЛ, номер карты или SMS-код.", "Do not send passport, PINFL, card number or SMS code."),
            systemImage: "lock.shield.fill"
        )
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(SalomTheme.Colors.textSecondary)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SalomTheme.Colors.surfaceMuted, in: RoundedRectangle(cornerRadius: 16))
    }

    private var actions: some View {
        VStack(spacing: 11) {
            Button {
                let prompt = promptWithCalculatorContext
                Analytics.shared.track("mini_app_start_ai", ["app_id": app.id, "surface": "ios_native"])
                onStart(prompt)
            } label: {
                Label(text("AI bilan boshlash", "Начать с ИИ", "Start with AI"), systemImage: "sparkles")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(SalomTheme.Colors.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(LinearGradient(colors: app.colors, startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)

            if !subscription.isPro {
                Button {
                    Analytics.shared.track("mini_app_paywall_open", ["app_id": app.id, "paywall_id": app.paywallContext.rawValue])
                    showPaywall = true
                } label: {
                    Label(text("Premium imkoniyatlarni ochish", "Открыть Premium", "Unlock Premium"), systemImage: "crown.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(SalomTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(SalomTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 17))
                        .overlay(RoundedRectangle(cornerRadius: 17).stroke(app.colors.first ?? SalomTheme.Colors.accentPrimary))
                }
                .buttonStyle(.plain)
            } else {
                Label(text("Premium faol", "Premium активен", "Premium active"), systemImage: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SalomTheme.Colors.success)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 18)
    }

    private var promptWithCalculatorContext: String {
        var parts = [app.prompt.pick(languageCode)]
        switch app.id {
        case "salary-employment" where !grossSalary.isEmpty:
            parts.append("Gross salary: \(grossSalary) UZS; estimated net: \(currency(number(grossSalary) * 0.88)).")
        case "money-planner" where !monthlyIncome.isEmpty || !monthlyExpenses.isEmpty:
            parts.append("Monthly income: \(monthlyIncome) UZS; monthly expenses: \(monthlyExpenses) UZS; estimated balance: \(currency(number(monthlyIncome) - number(monthlyExpenses))).")
        case "vehicle-assistant" where !distance.isEmpty || !consumption.isEmpty || !fuelPrice.isEmpty:
            let total = (number(distance) / 100) * number(consumption) * number(fuelPrice)
            parts.append("Distance: \(distance) km; consumption: \(consumption) L/100 km; fuel price: \(fuelPrice) UZS/L; estimated cost: \(currency(total)).")
        default: break
        }
        return parts.joined(separator: "\n\n")
    }

    private func number(_ raw: String) -> Double {
        Double(raw.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func currency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = " "
        return "\(formatter.string(from: NSNumber(value: amount)) ?? "0") \(text("so‘m", "сум", "UZS"))"
    }

    private func text(_ uz: String, _ ru: String, _ en: String) -> String {
        switch languageCode {
        case "ru": ru
        case "en": en
        case "kr", "uz-Cyrl": UzCyrillic.toCyrillic(uz)
        default: uz
        }
    }
}
