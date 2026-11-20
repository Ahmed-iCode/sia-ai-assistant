import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_strings.dart';

class AppLocalizations {
  final Locale locale;
  final AppStrings strings;

  const AppLocalizations(this.locale, this.strings);

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return localizations ?? AppLocalizations(const Locale('ar'), AppStrings.ar);
  }

  bool get isRtl => locale.languageCode == 'ar';
  bool get isArabic => locale.languageCode == 'ar';
  bool get isEnglish => locale.languageCode == 'en';

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('ar', ''),
    Locale('en', ''),
  ];
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['ar', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    final strings = locale.languageCode == 'ar' ? AppStrings.ar : AppStrings.en;
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale, strings));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
