import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../domain/day.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';
import '../celebrations/celebration_host.dart';
import 'goals_controller.dart';

/// Sets the goal of a skill, or edits its active goal: target hours and an
/// optional deadline that is not in the past.
class GoalEditScreen extends ConsumerWidget {
  const GoalEditScreen({super.key, required this.skillId});

  final String skillId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills = ref.watch(skillsProvider).value;
    final goals = ref.watch(goalsProvider).value;
    final today = ref.watch(todayProvider).value;
    if (skills == null || goals == null || today == null) {
      return Scaffold(appBar: AppBar());
    }
    final skill = skills.where((s) => s.id == skillId).firstOrNull;
    if (skill == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Yetenek bulunamadı.', style: MeskType.caption),
        ),
      );
    }
    final active = goals
        .where((g) => g.skillId == skillId && g.active)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          active == null ? 'Hedef koy' : 'Hedefi düzenle',
          style: MeskType.sectionTitle,
        ),
      ),
      body: SafeArea(
        child: _GoalForm(
          key: ValueKey(skillId),
          skill: skill,
          goal: active,
          today: today,
        ),
      ),
    );
  }
}

class _GoalForm extends ConsumerStatefulWidget {
  const _GoalForm({
    super.key,
    required this.skill,
    required this.goal,
    required this.today,
  });

  final Skill skill;

  /// The active goal being edited; null when creating.
  final Goal? goal;
  final LocalDay today;

  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  late final _hours = TextEditingController(
    text: widget.goal == null
        ? null
        : '${(widget.goal!.targetSeconds / 3600).round()}',
  );
  late LocalDay? _deadline = widget.goal?.deadline;
  bool _busy = false;

  @override
  void dispose() {
    _hours.dispose();
    super.dispose();
  }

  int? get _targetHours {
    final v = int.tryParse(_hours.text.trim());
    return v != null && v > 0 ? v : null;
  }

  Future<void> _pickDeadline() async {
    final today = widget.today;
    final current = _deadline;
    final initial = current != null && current.compareTo(today) >= 0
        ? current
        : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.toDateTime(),
      firstDate: today.toDateTime(),
      lastDate: DateTime(today.year + 30),
    );
    if (picked != null && mounted) {
      setState(
        () => _deadline = LocalDay(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _save() async {
    final hours = _targetHours;
    if (hours == null || _busy) return;
    setState(() => _busy = true);
    try {
      final existing = widget.goal;
      final goal = existing == null
          ? Goal(
              id: newId(),
              skillId: widget.skill.id,
              targetSeconds: hours * 3600,
              deadline: _deadline,
              createdAt: ref.read(clockProvider).nowUtc(),
            )
          : existing.copyWith(targetSeconds: hours * 3600, deadline: _deadline);
      await runAndCelebrate(
        ref,
        () => ref.read(goalsControllerProvider).save(goal),
      );
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/yetenekler/${widget.skill.id}');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kaydedilemedi, tekrar dene.')),
        );
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deadline = _deadline;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(widget.skill.name, style: MeskType.screenTitle),
        const SizedBox(height: 4),
        const Text(
          'Hedef gerçek süredir. Önceki deneyim de sayılır.',
          style: MeskType.caption,
        ),
        const SizedBox(height: 24),
        TextField(
          key: const ValueKey('goal-hours'),
          controller: _hours,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 5,
          style: MeskType.body15,
          decoration: const InputDecoration(
            labelText: 'Hedef süre (saat)',
            counterText: '',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        const MeskLabel('Bitiş tarihi (isteğe bağlı)'),
        const SizedBox(height: 8),
        Row(
          spacing: 8,
          children: [
            MeskSecondaryButton(
              key: const ValueKey('goal-deadline'),
              label: deadline == null
                  ? 'Tarih seç'
                  : formatDate(deadline.toDateTime()),
              icon: Icons.event,
              onPressed: _pickDeadline,
            ),
            if (deadline != null)
              IconButton(
                tooltip: 'Tarihi kaldır',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(Icons.close, color: MeskColors.muted),
                onPressed: () => setState(() => _deadline = null),
              ),
          ],
        ),
        const SizedBox(height: 32),
        MeskPrimaryButton(
          label: 'Kaydet',
          onPressed: _targetHours != null && !_busy ? _save : null,
        ),
      ],
    );
  }
}
