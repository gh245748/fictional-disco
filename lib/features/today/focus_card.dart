import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/format.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/mesk_card.dart';

/// Today's focus time and the "Odaklan" shortcut to the focus tab, which
/// preselects the last used skill.
class FocusCard extends StatelessWidget {
  const FocusCard({
    super.key,
    required this.seconds,
    required this.pomodoros,
    this.lastSkillName,
  });

  final int seconds;
  final int pomodoros;
  final String? lastSkillName;

  @override
  Widget build(BuildContext context) => MeskCard(
    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
    child: Row(
      spacing: 12,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 3,
            children: [
              Text(
                'Bugün ${formatDuration(seconds)} odak',
                style: MeskType.body15,
              ),
              Text(
                '$pomodoros pomodoro'
                '${lastSkillName == null ? '' : ' · son: $lastSkillName'}',
                style: MeskType.caption,
              ),
            ],
          ),
        ),
        MeskPrimaryButton(
          label: 'Odaklan',
          icon: Icons.play_arrow_rounded,
          onPressed: () => context.go('/odak'),
        ),
      ],
    ),
  );
}
