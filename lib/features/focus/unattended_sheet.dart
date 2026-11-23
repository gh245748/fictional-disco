import 'package:material_ui/material_ui.dart';

import '../../domain/day.dart';
import '../../domain/format.dart';
import '../../domain/timer_machine.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';

/// Asks which of the work [phases] that ran without the user should count
/// ("Gözetimsiz devam", §5.7). Nothing is preselected, so a forgotten timer
/// adds no time unless the user says so. Returns the kept phase starts; the
/// sheet can only be closed by answering.
Future<Set<DateTime>> showUnattendedSheet(
  BuildContext context, {
  required List<WorkPhaseRecord> phases,
  required Clock clock,
}) async {
  final kept = await showModalBottomSheet<Set<DateTime>>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: MeskColors.surface,
    builder: (_) => PopScope(
      canPop: false,
      child: UnattendedSheet(phases: phases, clock: clock),
    ),
  );
  return kept ?? const {};
}

class UnattendedSheet extends StatefulWidget {
  const UnattendedSheet({super.key, required this.phases, required this.clock});

  final List<WorkPhaseRecord> phases;
  final Clock clock;

  @override
  State<UnattendedSheet> createState() => _UnattendedSheetState();
}

class _UnattendedSheetState extends State<UnattendedSheet> {
  final Set<DateTime> _kept = {};

  String _localTime(DateTime utc) {
    final local = utc.add(Duration(minutes: widget.clock.offsetMinutesAt(utc)));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sen yokken ${widget.phases.length} çalışma aşaması kendiliğinden '
          'devam etti. Hangilerini sayalım?',
          style: MeskType.body15,
        ),
        const SizedBox(height: 12),
        for (final p in widget.phases)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: MeskColors.accent,
            checkColor: MeskColors.bg,
            value: _kept.contains(p.start),
            title: Text(_localTime(p.start), style: MeskType.body15),
            subtitle: Text(formatDuration(p.seconds), style: MeskType.caption),
            onChanged: (v) => setState(
              () => v ?? false ? _kept.add(p.start) : _kept.remove(p.start),
            ),
          ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: MeskPrimaryButton(
            label: 'Tamam',
            onPressed: () => Navigator.pop(context, {..._kept}),
          ),
        ),
      ],
    ),
  );
}
