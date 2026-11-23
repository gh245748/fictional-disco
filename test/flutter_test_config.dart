import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _fonts = <String, List<String>>{
  'CormorantGaramond': [
    'assets/fonts/CormorantGaramond-Medium.ttf',
    'assets/fonts/CormorantGaramond-SemiBold.ttf',
    'assets/fonts/CormorantGaramond-MediumItalic.ttf',
  ],
  'Manrope': [
    'assets/fonts/Manrope-Regular.ttf',
    'assets/fonts/Manrope-Medium.ttf',
    'assets/fonts/Manrope-SemiBold.ttf',
    'assets/fonts/Manrope-Bold.ttf',
  ],
  'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
};

/// Loads the bundled fonts so goldens render real glyphs, and the Turkish
/// date symbols used by the formatters.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final MapEntry(key: family, value: assets) in _fonts.entries) {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
  await initializeDateFormatting('tr');
  await testMain();
}
