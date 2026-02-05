import json
import re

path = '/Users/alijonovshohruhmirzo/Desktop/Salom-AI-Mobile/Salom-Ai-iOS/Salom-Ai-iOS/Resources/Localizable.xcstrings'

# Manual translations for specific missing keys
manual_en = {
    "5 yulduz qo'yish": "Rate 5 stars",
    "Agar ilovadan foydalanish sizga yoqsa, iltimos, uni baholash uchun bir oz vaqt ajrating. Bu bizga uni yaxshilashga yordam beradi!": "If you enjoy using the app, please take a moment to rate it. It helps us improve!",
    "Bildirishnomalar": "Notifications",
    "Cheklovsiz imkoniyatlar": "Unlimited possibilities",
    "Cheklovsiz Imkoniyatlar": "Unlimited Possibilities",
    "Hozir emas": "Not now",
    "Keyinroq": "Later",
    "No notifications yet": "No notifications yet",
    "Premium ga o'tish": "Upgrade to Premium",
    "Pro ga o'tish - %@ UZS/oy": "Get Pro - %@ UZS/mo",
    "Salom AI Pro orqali sun'iy intellektning to'liq kuchidan foydalaning.": "Unlock the full power of AI with Salom AI Pro.",
    "Sizga Salom AI yoqyaptimi?": "Do you enjoy Salom AI?",
    "Xabarlar tarixi": "Message history"
}

manual_ru = {
    "Bildirishnomalar": "Уведомления",
    "Cheklovsiz imkoniyatlar": "Безграничные возможности",
    "Cheklovsiz Imkoniyatlar": "Безграничные возможности",
    "Keyinroq": "Позже",
    "No notifications yet": "Пока нет уведомлений",
    "Premium ga o'tish": "Перейти на Premium",
    "Pro ga o'tish - %@ UZS/oy": "Перейти на Pro - %@ сум/мес",
    "Salom AI Pro orqali sun'iy intellektning to'liq kuchidan foydalaning.": "Используйте полную мощь ИИ с Salom AI Pro.",
    "Xabarlar tarixi": "История сообщений",
    "5 yulduz qo'yish": "Оценить на 5 звезд",
    "Agar ilovadan foydalanish sizga yoqsa, iltimos, uni baholash uchun bir oz vaqt ajrating. Bu bizga uni yaxshilashga yordam beradi!": "Если вам нравится приложение, пожалуйста, оцените его. Это поможет нам стать лучше!",
    "Hozir emas": "Не сейчас",
    "Sizga Salom AI yoqyaptimi?": "Вам нравится Salom AI?",
    "Oʻzbekcha (Kirill)": "Узбекский (Кириллица)",
    "Oʻzbekcha": "Узбекский",
    "Ruscha": "Русский",
    "Inglizcha": "Английский"
}

manual_uz = {
    "No notifications yet": "Hozircha bildirishnomalar yo'q",
    "Oʻzbekcha (Kirill)": "Oʻzbekcha (Kirill)",
    "Oʻzbekcha": "Oʻzbekcha",
    "Ruscha": "Ruscha",
    "Inglizcha": "Inglizcha"
}

manual_en.update({
    "Oʻzbekcha (Kirill)": "Uzbek (Cyrillic)",
    "Oʻzbekcha": "Uzbek",
    "Ruscha": "Russian",
    "Inglizcha": "English"
})

manual_uz_cyrl = {
    "Oʻzbekcha (Kirill)": "Ўзбекча (Кирилл)",
    "Oʻzbekcha": "Ўзбекча",
    "Ruscha": "Русча",
    "Inglizcha": "Инглизча",
    "Til": "Тил"
}

# Transliteration logic
def transliterate_to_cyrl(text):
    if not text: return text
    
    # 1. Handle digraphs and special chars first
    # Case sensitive replacements
    replacements = [
        ("Ye", "Е"), ("ye", "е"), # ye -> е (approximation)
        ("Yo", "Ё"), ("yo", "ё"),
        ("Yu", "Ю"), ("yu", "ю"),
        ("Ya", "Я"), ("ya", "я"),
        ("Sh", "Ш"), ("sh", "ш"),
        ("Ch", "Ч"), ("ch", "ч"),
        ("O'", "Ў"), ("o'", "ў"),
        ("G'", "Ғ"), ("g'", "ғ"),
        ("Ng", "Нг"), ("ng", "нг"), # simple scan
    ]
    
    res = text
    for lat, cyr in replacements:
        res = res.replace(lat, cyr)
        
    # 2. Logic for 'e' -> 'э' (start of word) vs 'e' (elsewhere)
    # We'll use regex to find 'e' at word boundaries
    # Note: We already handled 'ye', so remaining 'e's are likely simple vowels
    # Logic: Start of word e -> Э ({E} -> Э, {e} -> э)
    # Inside word e -> е ({E} is rare inside, usually {e})
    
    def e_replace(match):
        char = match.group(0)
        return 'Э' if char == 'E' else 'э'
        
    res = re.sub(r'\b[Ee]', e_replace, res)
    # Remaining 'E'/'e' inside words -> Е/е
    res = res.replace('E', 'Е').replace('e', 'е')
    
    # 3. Single char mapping
    chars = {
        'A': 'А', 'a': 'а',
        'B': 'Б', 'b': 'б',
        'D': 'Д', 'd': 'д',
        'F': 'Ф', 'f': 'ф',
        'G': 'Г', 'g': 'г',
        'H': 'Ҳ', 'h': 'ҳ',
        'I': 'И', 'i': 'и',
        'J': 'Ж', 'j': 'ж',
        'K': 'К', 'k': 'к',
        'L': 'Л', 'l': 'л',
        'M': 'М', 'm': 'м',
        'N': 'Н', 'n': 'н',
        'O': 'О', 'o': 'о',
        'P': 'П', 'p': 'п',
        'Q': 'Қ', 'q': 'қ',
        'R': 'Р', 'r': 'р',
        'S': 'С', 's': 'с',
        'T': 'Т', 't': 'т',
        'U': 'У', 'u': 'у',
        'V': 'В', 'v': 'в',
        'X': 'Х', 'x': 'х',
        'Y': 'Й', 'y': 'й',
        'Z': 'З', 'z': 'з',
        
        # Keep punctuation and numbers
    }
    
    new_res = ""
    for char in res:
        new_res += chars.get(char, char)
        
    return new_res

with open(path, 'r') as f:
    data = json.load(f)

count_en = 0
count_ru = 0
count_cyrl = 0

for key, entry in data['strings'].items():
    locs = entry.get('localizations', {})
    
    # 1. Fill EN
    if 'en' not in locs:
        if key in manual_en:
            locs['en'] = {"stringUnit": {"state": "translated", "value": manual_en[key]}}
            count_en += 1
            
    # 2. Fill RU
    if 'ru' not in locs:
        if key in manual_ru:
            locs['ru'] = {"stringUnit": {"state": "translated", "value": manual_ru[key]}}
            count_ru += 1
            
    # 3. Fill UZ (if missing, though usually key is UZ)
    # Wait, sometimes key is English, but sourceLanguage is "uz".
    # If key is "No notifications yet", source is "uz", but effectively it's english text.
    # We should ensure 'uz' exists for "No notifications yet"
    if 'uz' not in locs:
         if key in manual_uz:
             locs['uz'] = {"stringUnit": {"state": "translated", "value": manual_uz[key]}}

    # 4. Fill UZ-CYRL (uz-Cyrl)
    if 'uz-Cyrl' not in locs:
        if key in manual_uz_cyrl:
             locs['uz-Cyrl'] = { "stringUnit": { "state": "translated", "value": manual_uz_cyrl[key] } }
             count_cyrl += 1
        else:
            # Source text: prefer 'uz' translation, then key
            source_text = key
            if 'uz' in locs:
                source_text = locs['uz']['stringUnit']['value']
            
            cyrl_text = transliterate_to_cyrl(source_text)
            
            locs['uz-Cyrl'] = {
                "stringUnit": {
                    "state": "translated",
                    "value": cyrl_text
                }
            }
            count_cyrl += 1
    
    entry['localizations'] = locs

# Ensure new keys exist
all_manual_keys = set(manual_en.keys()) | set(manual_ru.keys()) | set(manual_uz.keys()) | set(manual_uz_cyrl.keys())
for k in all_manual_keys:
    if k not in data['strings']:
        data['strings'][k] = {"localizations": {}}
        # Rescan to fill
        entry = data['strings'][k]
        locs = entry['localizations']
        if 'en' not in locs and k in manual_en:
             locs['en'] = {"stringUnit": {"state": "translated", "value": manual_en[k]}}
        if 'ru' not in locs and k in manual_ru:
             locs['ru'] = {"stringUnit": {"state": "translated", "value": manual_ru[k]}}
        if 'uz' not in locs and k in manual_uz:
             locs['uz'] = {"stringUnit": {"state": "translated", "value": manual_uz[k]}}
        if 'uz-Cyrl' not in locs and k in manual_uz_cyrl:
             locs['uz-Cyrl'] = {"stringUnit": {"state": "translated", "value": manual_uz_cyrl[k]}}
        entry['localizations'] = locs


print(f"Added {count_en} EN, {count_ru} RU, {count_cyrl} UZ-CYRL translations.")

with open(path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
