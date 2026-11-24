import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../domain/day.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/mesk_card.dart';

/// TestFlight builds stop working 90 days after they are uploaded (§6.4).
const int testflightValidDays = 90;

/// The reminder shows once the build is this old.
const int testflightReminderAfterDays = 80;

/// The build date baked in by `ios.yml` (`YYYY-MM-DD`); empty everywhere else.
const String kBuildDate = String.fromEnvironment('MESK_BUILD_DATE');

/// The build date. Overridden in tests.
final buildDateProvider = Provider<String>((ref) => kBuildDate);

/// Whether the app runs on iOS. Overridden in tests.
final isIosProvider = Provider<bool>(
  (ref) => defaultTargetPlatform == TargetPlatform.iOS,
);

/// Days left before the TestFlight build expires, once the build is at least
/// 80 days old; null before that, or when [buildDate] is missing or invalid.
int? testflightDaysLeft({required String buildDate, required LocalDay today}) {
  final LocalDay built;
  try {
    built = LocalDay.parse(buildDate);
  } on FormatException {
    return null;
  }
  final age = built.daysUntil(today);
  if (age < testflightReminderAfterDays) return null;
  final left = testflightValidDays - age;
  return left < 0 ? 0 : left;
}

/// Days left on this TestFlight build when the reminder is due, else null.
/// Null off iOS, without a build date, and before the build is 80 days old.
final testflightLeftProvider = Provider<int?>((ref) {
  if (!ref.watch(isIosProvider)) return null;
  final today = ref.watch(todayProvider).value;
  if (today == null) return null;
  return testflightDaysLeft(
    buildDate: ref.watch(buildDateProvider),
    today: today,
  );
});

/// The expiry reminder card on Today and Settings. Callers that lay it out in
/// a spaced column should only include it when [testflightLeftProvider] is
/// non-null; it renders nothing otherwise.
class TestflightReminder extends ConsumerWidget {
  const TestflightReminder({super.key, this.bottomGap = 0});

  /// Space below the card, only when it is shown.
  final double bottomGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = ref.watch(testflightLeftProvider);
    if (left == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: MeskCard(
        child: Text(
          'Bu TestFlight sürümü $left gün içinde sona erecek. '
          'Yeni bir sürüm yükle.',
          style: MeskType.body14,
        ),
      ),
    );
  }
}
