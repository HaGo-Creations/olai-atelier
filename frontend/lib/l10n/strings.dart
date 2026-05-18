// lib/l10n/strings.dart
//
// Lightweight i18n. Loads a JSON file per locale from assets/i18n/.
// To add a new language: drop assets/i18n/{code}.json, register the code
// in [supportedLocales], add the .json to pubspec assets.

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Strings {
  Strings(this.locale, this._map);

  final Locale locale;
  final Map<String, String> _map;

  static const supportedLocales = <Locale>[
    Locale('en'),
    // Locale('ta'), // future: drop assets/i18n/ta.json and uncomment
    // Locale('hi'),
  ];

  static Future<Strings> load(Locale locale) async {
    final code = locale.languageCode;
    final raw = await rootBundle.loadString('assets/i18n/$code.json');
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return Strings(locale, decoded.map((k, v) => MapEntry(k, v.toString())));
  }

  String t(String key, {Map<String, String>? args}) {
    var value = _map[key] ?? key;
    if (args != null) {
      args.forEach((k, v) => value = value.replaceAll('{$k}', v));
    }
    return value;
  }
}

final stringsProvider = StateProvider<Strings?>((_) => null);

/// Convenience getter — call inside a ConsumerWidget.
extension StringsX on WidgetRef {
  String tr(String key, {Map<String, String>? args}) =>
      watch(stringsProvider)?.t(key, args: args) ?? key;
}
