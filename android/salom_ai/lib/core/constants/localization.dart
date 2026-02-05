import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salom_ai/router.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocaleNotifier(prefs);
});

class LocaleNotifier extends StateNotifier<String> {
  final SharedPreferences _prefs;
  
  LocaleNotifier(this._prefs) : super(_prefs.getString('preferredLanguageCode') ?? 'uz');

  void setLocale(String code) {
    state = code;
    _prefs.setString('preferredLanguageCode', code);
  }

  String translate(String key) {
    final translations = _allTranslations[state] ?? _allTranslations['uz']!;
    return translations[key] ?? key;
  }
}

extension LocalizationExtension on WidgetRef {
  String tr(String key) {
    final locale = watch(localeProvider);
    final translations = _allTranslations[locale] ?? _allTranslations['uz']!;
    return translations[key] ?? key;
  }
}

final Map<String, Map<String, String>> _allTranslations = {
  "uz": {
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
    "uzbek_cyrl": "Oʻzbekcha (Kirill)",
  },
  "ru": {
    "settings": "Настройки",
    "profile_card_default_user": "Привет, пользователь",
    "profile_card_guest": "Гость",
    "phone_not_identified": "Номер телефона не определен",
    "subscription": "Подписка",
    "current_plan": "Текущий план",
    "free": "Бесплатно",
    "loading": "Загрузка...",
    "help": "Помощь",
    "send_feedback": "Отправить отзыв",
    "language": "Язык",
    "uzbek": "Узбекский",
    "russian": "Русский",
    "english": "Английский",
    "login_info": "Данные для входа",
    "logout": "Выйти",
    "delete_account": "Удалить аккаунт",
    "deleting": "Удаление...",
    "delete_account_title": "Удалить аккаунт",
    "delete_account_message": "Вы уверены, что хотите полностью удалить свой аккаунт? Это действие удалит все ваши чаты, сообщения и данные без возможности восстановления!",
    "cancel": "Отмена",
    "delete": "Удалить",
    "error": "Ошибка",
    "ok": "OK",
    "pro_features": "Pro возможности",
    "unlimited_conv": "Без ограничений и больше возможностей",
    "subscriptions": "Подписки",
    "valid_until": "Срок действия",
    "active": "Активный",
    "choose": "Выбрать",
    "no_perks": "Преимущества недоступны",
    "month_count": "/ месяц",
    "uzbek_cyrl": "Узбекский (Кириллица)",
  },
  "en": {
    "settings": "Settings",
    "profile_card_default_user": "Salom User",
    "profile_card_guest": "Guest",
    "phone_not_identified": "Phone number not identified",
    "subscription": "Subscription",
    "current_plan": "Current Plan",
    "free": "Free",
    "loading": "Loading...",
    "help": "Support",
    "send_feedback": "Send feedback",
    "language": "Language",
    "uzbek": "Uzbek",
    "russian": "Russian",
    "english": "English",
    "login_info": "Login Information",
    "logout": "Log out",
    "delete_account": "Delete Account",
    "deleting": "Deleting...",
    "delete_account_title": "Delete Account",
    "delete_account_message": "Are you sure you want to permanently delete your account? This action will delete all your conversations, messages, and data. This cannot be undone!",
    "cancel": "Cancel",
    "delete": "Delete",
    "error": "Error",
    "ok": "OK",
    "pro_features": "Pro Features",
    "unlimited_conv": "Unlimited conversations and more possibilities",
    "subscriptions": "Subscriptions",
    "valid_until": "Valid until",
    "active": "Active",
    "choose": "Choose",
    "no_perks": "No perks available",
    "month_count": "/ month",
    "uzbek_cyrl": "Uzbek (Cyrillic)",
  },
  "uz-Cyrl": {
    "settings": "Созламалар",
    "profile_card_default_user": "Салом фойдаланувчи",
    "profile_card_guest": "Меҳмон",
    "phone_not_identified": "Телефон рақам аниқланмаган",
    "subscription": "Обуна",
    "current_plan": "Жорий режа",
    "free": "Бепул",
    "loading": "Юкланмоқда...",
    "help": "Ёрдам",
    "send_feedback": "Фикр-мулоҳаза юбориш",
    "language": "Тил",
    "uzbek": "Ўзбекча",
    "russian": "Русча",
    "english": "Инглизча",
    "login_info": "Кириш маʼлумотлари",
    "logout": "Чиқиш",
    "delete_account": "Ҳисобни ўчириш",
    "deleting": "Ўчирилмоқда...",
    "delete_account_title": "Ҳисобни ўчириш",
    "delete_account_message": "Ҳисобингизни бутунлай ўчиришни хоҳлайсизми? Бу амал барча суҳбатлар, хабарлар ва маʼлумотларингизни бутунлай ўчиради. Бу амални бекор қилиб бўлмайди!",
    "cancel": "Бекор қилиш",
    "delete": "Ўчириш",
    "error": "Хатолик",
    "ok": "ОК",
    "pro_features": "Про имкониятлар",
    "unlimited_conv": "Чекловсиз мулоқот ва кўпроқ имкониятлар",
    "subscriptions": "Обуналар",
    "valid_until": "Амал қилиш муддати",
    "active": "Фаол",
    "choose": "Танлаш",
    "no_perks": "Имтиёзлар мавжуд эмас",
    "month_count": "/ ойига",
    "uzbek_cyrl": "Ўзбекча (Кирилл)",
  },
};
