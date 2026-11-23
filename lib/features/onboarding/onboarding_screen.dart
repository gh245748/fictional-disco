import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../data/kv_repo.dart';
import '../../data/skills_repo.dart';
import '../../domain/models.dart';
import '../../domain/stats.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/stat_dot.dart';
import 'templates.dart';

/// A skill the user typed in during onboarding: a name and its main stat.
typedef CustomSkill = ({String name, Stat primary});

/// Saves the character, the chosen skills (templates by name plus
/// [customSkills]) and the links among the chosen templates, then marks
/// onboarding done. Everything is written in one transaction. New skills
/// get no graph position yet.
Future<void> completeOnboarding(
  Ref ref, {
  required String characterName,
  required Set<String> templateNames,
  List<CustomSkill> customSkills = const [],
}) async {
  final db = ref.read(dbProvider);
  final clock = ref.read(clockProvider);
  final now = clock.nowUtc();
  final skills = SkillsRepo(db);
  final links = LinksRepo(db);
  final kv = KvRepo(db);

  final idByName = <String, String>{};
  await db.database.transaction((txn) async {
    for (final t in skillTemplates) {
      if (!templateNames.contains(t.name)) continue;
      final id = newId();
      idByName[t.name] = id;
      await skills.put(
        Skill(
          id: id,
          name: t.name,
          primary: t.primary,
          secondary: t.secondary,
          createdAt: now,
        ),
        txn: txn,
      );
    }
    for (final (a, b) in templateLinks) {
      final x = idByName[a];
      final y = idByName[b];
      if (x == null || y == null) continue;
      await links.put(
        SkillLink.normalized(id: newId(), x: x, y: y, createdAt: now),
        txn: txn,
      );
    }
    for (final c in customSkills) {
      await skills.put(
        Skill(id: newId(), name: c.name, primary: c.primary, createdAt: now),
        txn: txn,
      );
    }
    await kv.saveCharacter(Character(name: characterName), txn: txn);
    final settings = await kv.settings(txn: txn);
    await kv.saveSettings(settings.copyWith(onboarded: true), txn: txn);
  });
}

/// [completeOnboarding] bound to a provider, so widgets can call it.
final completeOnboardingProvider =
    Provider<
      Future<void> Function({
        required String characterName,
        required Set<String> templateNames,
        List<CustomSkill> customSkills,
      })
    >(
      (ref) =>
          ({
            required characterName,
            required templateNames,
            customSkills = const [],
          }) => completeOnboarding(
            ref,
            characterName: characterName,
            templateNames: templateNames,
            customSkills: customSkills,
          ),
    );

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageCount = 4;
  static const _anim = Duration(milliseconds: 250);

  final _pages = PageController();
  final _name = TextEditingController();
  final _selected = <String>{};
  final _custom = <CustomSkill>[];
  int _page = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _canContinue => _page != 1 || _name.text.trim().isNotEmpty;

  void _go(int page) {
    FocusScope.of(context).unfocus();
    setState(() => _page = page);
    _pages.animateToPage(page, duration: _anim, curve: Curves.easeOut);
  }

  Future<void> _finish({required bool askPermission}) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      if (askPermission) {
        try {
          await ref.read(notificationsProvider).requestPermission();
        } catch (_) {
          // A refused or failing permission request never blocks onboarding.
        }
      }
      await ref.read(completeOnboardingProvider)(
        characterName: _name.text.trim(),
        templateNames: _selected,
        customSkills: _custom,
      );
      if (mounted) context.go('/bugun');
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _addCustom() async {
    final taken = {
      for (final t in skillTemplates) t.name.toLowerCase(),
      for (final c in _custom) c.name.toLowerCase(),
    };
    final skill = await showModalBottomSheet<CustomSkill>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MeskColors.surface,
      builder: (_) => _CustomSkillSheet(taken: taken),
    );
    if (skill != null) setState(() => _custom.add(skill));
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pageCount - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Dots(count: _pageCount, index: _page),
              const SizedBox(height: 24),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    const _WelcomePage(),
                    _NamePage(
                      controller: _name,
                      onChanged: () => setState(() {}),
                      onSubmitted: () {
                        if (_canContinue) _go(2);
                      },
                    ),
                    _SkillsPage(
                      selected: _selected,
                      custom: _custom,
                      onToggle: (n) => setState(
                        () => _selected.contains(n)
                            ? _selected.remove(n)
                            : _selected.add(n),
                      ),
                      onRemoveCustom: (c) => setState(() => _custom.remove(c)),
                      onAddCustom: _addCustom,
                    ),
                    const _NotificationPage(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (last) ...[
                MeskPrimaryButton(
                  label: 'İzin ver',
                  onPressed: _finishing
                      ? null
                      : () => _finish(askPermission: true),
                ),
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: MeskColors.muted,
                    textStyle: MeskPrimaryButton.textStyle,
                  ),
                  onPressed: _finishing
                      ? null
                      : () => _finish(askPermission: false),
                  child: const Text('Şimdi değil'),
                ),
              ] else
                Row(
                  children: [
                    if (_page > 0)
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          foregroundColor: MeskColors.muted,
                          textStyle: MeskPrimaryButton.textStyle,
                        ),
                        onPressed: () => _go(_page - 1),
                        child: const Text('Geri'),
                      ),
                    const Spacer(),
                    MeskPrimaryButton(
                      label: 'Devam',
                      onPressed: _canContinue ? () => _go(_page + 1) : null,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Adım ${index + 1} / $count',
    child: Row(
      spacing: 6,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == index ? 24 : 8,
            height: 4,
            decoration: BoxDecoration(
              color: i <= index ? MeskColors.accent : MeskColors.track,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    ),
  );
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: 16,
    children: [
      MeskLabel('Başlangıç'),
      Text("Meşk'e hoş geldin", style: MeskType.screenTitle),
      Text(
        'Çalıştığın her dakika bir yeteneği büyütür. Sayma, biriktir; '
        'emeğin seviyeye, unvana ve haritaya dönüşsün.',
        style: TextStyle(
          fontFamily: MeskType.sans,
          fontSize: 15,
          height: 1.5,
          color: MeskColors.muted,
        ),
      ),
    ],
  );
}

class _NamePage extends StatelessWidget {
  const _NamePage({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        const SizedBox(height: 24),
        const MeskLabel('Karakter'),
        const Text('Adın ne?', style: MeskType.screenTitle),
        TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          maxLength: 40,
          style: MeskType.body15,
          decoration: const InputDecoration(
            labelText: 'Karakter adı',
            counterText: '',
          ),
          onChanged: (_) => onChanged(),
          onSubmitted: (_) => onSubmitted(),
        ),
      ],
    ),
  );
}

class _SkillsPage extends StatelessWidget {
  const _SkillsPage({
    required this.selected,
    required this.custom,
    required this.onToggle,
    required this.onRemoveCustom,
    required this.onAddCustom,
  });

  final Set<String> selected;
  final List<CustomSkill> custom;
  final ValueChanged<String> onToggle;
  final ValueChanged<CustomSkill> onRemoveCustom;
  final VoidCallback onAddCustom;

  static const _selectedSide = BorderSide(color: MeskColors.accent);

  static ChipThemeData _chipTheme() => const ChipThemeData(
    shape: StadiumBorder(),
    showCheckmark: false,
    backgroundColor: MeskColors.surface,
    selectedColor: Color(0xFF2A2418),
    side: BorderSide(color: MeskColors.surfaceBorder),
    labelStyle: MeskType.body14,
    padding: EdgeInsets.symmetric(horizontal: 6),
  );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        const MeskLabel('Yetenekler'),
        const Text('Neyi ustalaşmak istiyorsun?', style: MeskType.sectionTitle),
        const Text(
          'Birkaçını seç. Seçtiklerin arasında önerilen bağlantılar da '
          'kurulur; sonra istediğini değiştirebilirsin.',
          style: MeskType.caption,
        ),
        ChipTheme(
          data: _chipTheme(),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final t in skillTemplates)
                FilterChip(
                  avatar: StatDot(t.primary),
                  label: Text(t.name),
                  selected: selected.contains(t.name),
                  side: selected.contains(t.name) ? _selectedSide : null,
                  onSelected: (_) => onToggle(t.name),
                ),
              for (final c in custom)
                InputChip(
                  avatar: StatDot(c.primary),
                  label: Text(c.name),
                  selected: true,
                  side: _selectedSide,
                  onDeleted: () => onRemoveCustom(c),
                  deleteButtonTooltipMessage: '${c.name} yeteneğini kaldır',
                ),
              ActionChip(
                avatar: const Icon(
                  Icons.add,
                  size: 16,
                  color: MeskColors.accent,
                ),
                label: const Text(
                  'Kendi yeteneğini ekle',
                  style: TextStyle(
                    fontFamily: MeskType.sans,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: MeskColors.accent,
                  ),
                ),
                onPressed: onAddCustom,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NotificationPage extends StatelessWidget {
  const _NotificationPage();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: 16,
    children: [
      MeskLabel('Bildirimler'),
      Text('Haberdar ol', style: MeskType.screenTitle),
      Text(
        'Pomodoro bittiğinde haber verebilmek için bildirim izni gerekiyor.',
        style: TextStyle(
          fontFamily: MeskType.sans,
          fontSize: 15,
          height: 1.5,
          color: MeskColors.muted,
        ),
      ),
    ],
  );
}

class _CustomSkillSheet extends StatefulWidget {
  const _CustomSkillSheet({required this.taken});

  /// Lower-cased names that already exist.
  final Set<String> taken;

  @override
  State<_CustomSkillSheet> createState() => _CustomSkillSheetState();
}

class _CustomSkillSheetState extends State<_CustomSkillSheet> {
  final _name = TextEditingController();
  Stat _stat = Stat.zihin;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _trimmed => _name.text.trim();
  bool get _duplicate => widget.taken.contains(_trimmed.toLowerCase());
  bool get _valid => _trimmed.isNotEmpty && !_duplicate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          const Text('Kendi yeteneğin', style: MeskType.sectionTitle),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            style: MeskType.body15,
            decoration: InputDecoration(
              labelText: 'Yetenek adı',
              counterText: '',
              errorText: _duplicate ? 'Bu yetenek zaten listede' : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const MeskLabel('Ana stat'),
          ChipTheme(
            data: _SkillsPage._chipTheme(),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final s in skillStats)
                  ChoiceChip(
                    avatar: StatDot(s),
                    label: Text(s.label),
                    selected: _stat == s,
                    side: _stat == s ? _SkillsPage._selectedSide : null,
                    onSelected: (_) => setState(() => _stat = s),
                  ),
              ],
            ),
          ),
          MeskPrimaryButton(
            label: 'Ekle',
            onPressed: _valid
                ? () =>
                      Navigator.of(context)
                          .pop((name: _trimmed, primary: _stat))
                : null,
          ),
        ],
      ),
    ),
  );
}
