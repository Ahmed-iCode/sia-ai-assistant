import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    return const Locale('ar'); // Default to Arabic RTL
  }

  void setLocale(Locale newLocale) {
    if (state.languageCode != newLocale.languageCode) {
      state = newLocale;
    }
  }

  void toggleLocale() {
    state = state.languageCode == 'ar' ? const Locale('en') : const Locale('ar');
  }

  bool get isRtl => state.languageCode == 'ar';
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
