//
//  DtmModels.swift
//  Salom-Ai-iOS
//
//  Models + API wrapper + localized strings + Cyrillic transliteration for the
//  adaptive DTM test-prep feature (mirrors the web hub).
//

import Foundation

// MARK: - API models (snake_case mapped via decoder's convertFromSnakeCase)

struct DtmSubject: Decodable, Identifiable {
    let key: String
    let label: String
    let questionCount: Int
    var id: String { key }
}
private struct DtmSubjectsResponse: Decodable { let subjects: [DtmSubject] }

struct DtmTopicStat: Decodable, Identifiable {
    let topic: String
    let key: String
    let questionCount: Int
    let seen: Int
    let mastery: Int
    var id: String { key + topic }
}

struct DtmTopics: Decodable {
    let subject: String
    let level: String
    let levelLabel: String
    let seen: Int
    let accuracy: Int
    let topics: [DtmTopicStat]
}

struct DtmOption: Decodable, Hashable { let key: String; let text: String }

struct DtmQuestion: Decodable, Identifiable {
    let id: Int
    let subject: String
    let topic: String?
    let difficulty: String
    let language: String
    let questionText: String
    let options: [DtmOption]
}

struct DtmQuizResponse: Decodable {
    let subject: String
    let count: Int
    let paid: Bool
    let level: String?
    let levelLabel: String?
    let topic: String?
    let questions: [DtmQuestion]
    let comingSoon: Bool?
}

struct DtmAnswerResponse: Decodable {
    let isCorrect: Bool
    let correctKey: String
    let explanation: String?
    let topic: String?
}

// MARK: - Service

enum DtmService {
    static func subjects() async throws -> [DtmSubject] {
        try await APIClient.shared.request(.dtmSubjects, decodeTo: DtmSubjectsResponse.self).subjects
    }
    static func topics(subject: String) async throws -> DtmTopics {
        try await APIClient.shared.request(.dtmTopics(subject: subject), decodeTo: DtmTopics.self)
    }
    static func quiz(subject: String, topic: String?) async throws -> DtmQuizResponse {
        try await APIClient.shared.request(.dtmQuiz(subject: subject, topic: topic), decodeTo: DtmQuizResponse.self)
    }
    static func answer(questionId: Int, chosenKey: String) async throws -> DtmAnswerResponse {
        try await APIClient.shared.request(.dtmAnswer(questionId: questionId, chosenKey: chosenKey), decodeTo: DtmAnswerResponse.self)
    }
}

// MARK: - Localized strings (uz / ru / en + Cyrillic via transliteration)

struct DtmL {
    let lang: String
    init(_ code: String) { self.lang = code }

    private func pick(_ uz: String, _ ru: String, _ en: String) -> String {
        switch lang {
        case "ru": return ru
        case "en": return en
        case "kr", "uz-Cyrl": return UzCyrillic.toCyrillic(uz)
        default: return uz
        }
    }
    /// Transliterate dynamic backend (Latin Uzbek) content for Cyrillic users.
    func tr(_ s: String?) -> String {
        guard let s = s else { return "" }
        return (lang == "kr" || lang == "uz-Cyrl") ? UzCyrillic.toCyrillic(s) : s
    }

    var title: String { pick("DTM mashqlari", "Подготовка к ДТМ", "DTM practice") }
    var subtitle: String { pick("Fan tanlang — darajangizga mos testlar", "Выберите предмет — тесты под ваш уровень", "Pick a subject — tests at your level") }
    var adaptive: String { pick("Moslashuvchan mashq", "Адаптивная практика", "Adaptive practice") }
    var adaptiveHint: String { pick("AI zaif mavzularingizdan savol beradi", "ИИ подбирает вопросы по слабым темам", "AI targets your weak topics") }
    var sections: String { pick("Bo‘limlar", "Разделы", "Sections") }
    var yourLevel: String { pick("Darajangiz", "Ваш уровень", "Your level") }
    var mastery: String { pick("o‘zlashtirish", "освоение", "mastery") }
    var focus: String { pick("E’tibor bering", "Над чем поработать", "Focus on") }
    var notStarted: String { pick("Boshlanmagan", "Не начато", "Not started") }
    var questions: String { pick("savol", "вопросов", "questions") }
    var check: String { pick("Tekshirish", "Проверить", "Check") }
    var next: String { pick("Keyingi", "Дальше", "Next") }
    var finish: String { pick("Yakunlash", "Завершить", "Finish") }
    var correct: String { pick("To‘g‘ri!", "Верно!", "Correct!") }
    var wrong: String { pick("Noto‘g‘ri", "Неверно", "Incorrect") }
    var result: String { pick("Natija", "Результат", "Result") }
    var again: String { pick("Yana mashq", "Ещё раз", "Practice again") }
    var back: String { pick("Orqaga", "Назад", "Back") }
    var comingSoon: String { pick("Savollar tez orada qo‘shiladi.", "Вопросы скоро появятся.", "Questions coming soon.") }
    var freeDailyDone: String { pick("Bugungi bepul mashqlar tugadi. Pro bilan cheksiz.", "Бесплатные тесты на сегодня закончились. На Pro — без лимитов.", "Today's free practice is done. Pro = unlimited.") }
    var upgrade: String { pick("Pro tarifga o‘tish", "Перейти на Pro", "Upgrade to Pro") }
    var loading: String { pick("Yuklanmoqda…", "Загрузка…", "Loading…") }
    var loadError: String { pick("Yuklab bo‘lmadi. Internet aloqangizni tekshirib, qayta urining.", "Не удалось загрузить. Проверьте интернет и повторите.", "Couldn't load. Check your connection and retry.") }
    var retry: String { pick("Qayta urinish", "Повторить", "Retry") }
}

// MARK: - Uzbek Latin → Cyrillic transliteration (for `kr` locale)

enum UzCyrillic {
    private static let digraphs: [(String, String)] = [
        ("O‘", "Ў"), ("O'", "Ў"), ("Oʻ", "Ў"), ("o‘", "ў"), ("o'", "ў"), ("oʻ", "ў"),
        ("G‘", "Ғ"), ("G'", "Ғ"), ("Gʻ", "Ғ"), ("g‘", "ғ"), ("g'", "ғ"), ("gʻ", "ғ"),
        ("Sh", "Ш"), ("SH", "Ш"), ("sh", "ш"),
        ("Ch", "Ч"), ("CH", "Ч"), ("ch", "ч"),
        ("Yo", "Ё"), ("YO", "Ё"), ("yo", "ё"),
        ("Yu", "Ю"), ("YU", "Ю"), ("yu", "ю"),
        ("Ya", "Я"), ("YA", "Я"), ("ya", "я"),
        ("Ye", "Е"), ("ye", "е"),
        ("ts", "ц"), ("Ts", "Ц"),
    ]
    private static let singles: [Character: Character] = [
        "a": "а", "b": "б", "d": "д", "e": "е", "f": "ф", "g": "г", "h": "ҳ", "i": "и",
        "j": "ж", "k": "к", "l": "л", "m": "м", "n": "н", "o": "о", "p": "п", "q": "қ",
        "r": "р", "s": "с", "t": "т", "u": "у", "v": "в", "x": "х", "y": "й", "z": "з", "c": "с",
        "A": "А", "B": "Б", "D": "Д", "E": "Е", "F": "Ф", "G": "Г", "H": "Ҳ", "I": "И",
        "J": "Ж", "K": "К", "L": "Л", "M": "М", "N": "Н", "O": "О", "P": "П", "Q": "Қ",
        "R": "Р", "S": "С", "T": "Т", "U": "У", "V": "В", "X": "Х", "Y": "Й", "Z": "З", "C": "С",
        "'": "ъ", "’": "ъ", "ʻ": "ъ",
    ]
    static func toCyrillic(_ input: String) -> String {
        var s = input
        for (lat, cyr) in digraphs { s = s.replacingOccurrences(of: lat, with: cyr) }
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s { out.append(singles[ch] ?? ch) }
        return out
    }
}
