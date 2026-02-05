import re

# Transliteration logic (Same as before)
def transliterate_to_cyrl(text):
    if not text: return text
    
    replacements = [
        ("Ye", "Е"), ("ye", "е"),
        ("Yo", "Ё"), ("yo", "ё"),
        ("Yu", "Ю"), ("yu", "ю"),
        ("Ya", "Я"), ("ya", "я"),
        ("Sh", "Ш"), ("sh", "ш"),
        ("Ch", "Ч"), ("ch", "ч"),
        ("O'", "Ў"), ("o'", "ў"),
        ("G'", "Ғ"), ("g'", "ғ"),
        ("Ng", "Нг"), ("ng", "нг"),
    ]
    
    res = text
    for lat, cyr in replacements:
        res = res.replace(lat, cyr)
        
    def e_replace(match):
        char = match.group(0)
        return 'Э' if char == 'E' else 'э'
        
    res = re.sub(r'\b[Ee]', e_replace, res)
    res = res.replace('E', 'Е').replace('e', 'е')
    
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
    }
    
    new_res = ""
    for char in res:
        new_res += chars.get(char, char)
        
    return new_res

# Manually defined uz map from localization.dart
uz_map = {
    "settings": "Sozlamalar",
    "profile_card_default_user": "Salom foydalanuvchi",
    "profile_card_guest": "Mehmon",
    "phone_not_identified": "Telefon raqam aniqlanmagan",
    "subscription": "Obuna",
    "current_plan": "Joriy reja",
    "free": "Bepul",
    "loading": "Yuklanmoqda...",
    "help": "Yordam",
    "send_feedback": "Fikr-mulohaza yuborish",
    "language": "Til",
    "uzbek": "Oʻzbekcha",
    "russian": "Ruscha",
    "english": "Inglizcha",
    "login_info": "Kirish maʼlumotlari",
    "logout": "Chiqish",
    "delete_account": "Hisobni o'chirish",
    "deleting": "O'chirilmoqda...",
    "delete_account_title": "Hisobni o'chirish",
    "delete_account_message": "Hisobingizni butunlay o'chirishni xohlaysizmi? Bu amal barcha suhbatlar, xabarlar va ma'lumotlaringizni butunlay o'chiradi. Bu amalni bekor qilib bo'lmaydi!",
    "cancel": "Bekor qilish",
    "delete": "O'chirish",
    "error": "Xatolik",
    "ok": "OK",
    "pro_features": "Pro imkoniyatlar",
    "unlimited_conv": "Cheklovsiz muloqot va ko'proq imkoniyatlar",
    "subscriptions": "Obunalar",
    "valid_until": "Amal qilish muddati",
    "active": "Faol",
    "choose": "Tanlash",
    "no_perks": "Imtiyozlar mavjud emas",
    "month_count": "/ oyiga",
    # Add new keys if any
    "uzbek_cyrl": "Oʻzbekcha (Kirill)" 
}

# Generate uz-Cyrl map
cyrl_map = {}
for k, v in uz_map.items():
    if k == "uzbek_cyrl":
        cyrl_map[k] = "Ўзбекча (Кирилл)"
    elif k == "uzbek":
        cyrl_map[k] = "Ўзбекча"
    elif k == "russian":
        cyrl_map[k] = "Русча"
    elif k == "english":
        cyrl_map[k] = "Инглизча"
    else:
        cyrl_map[k] = transliterate_to_cyrl(v)

print("  \"uz-Cyrl\": {")
for k, v in cyrl_map.items():
    print(f"    \"{k}\": \"{v}\",")
print("  },")
