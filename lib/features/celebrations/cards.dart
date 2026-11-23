import 'package:material_ui/material_ui.dart';

import '../../domain/achievements.dart';
import '../../domain/format.dart';
import '../../domain/level_curve.dart';
import '../../domain/level_events.dart';
import '../../domain/titles.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/mesk_card.dart';

/// "Sv. 5 → 8" for a jump of several levels, "Sv. 8" for one.
String levelChangeText(int? from, int to) =>
    from == null || to - from <= 1 ? 'Sv. $to' : 'Sv. $from → $to';

/// One queued [Celebration], drawn above the app. Cards are dismissed by a
/// tap anywhere or "Devam"; the achievement toast also leaves by itself.
class CelebrationOverlay extends StatelessWidget {
  const CelebrationOverlay({
    super.key,
    required this.celebration,
    required this.onDismiss,
    this.skillName = '',
    this.goalTargetSeconds,
  });

  final Celebration celebration;
  final VoidCallback onDismiss;
  final String skillName;

  /// Target of the completed goal, for [CelebrationKind.goalCompleted].
  final int? goalTargetSeconds;

  @override
  Widget build(BuildContext context) {
    final c = celebration;
    final to = c.toLevel ?? 1;
    return Material(
      type: MaterialType.transparency,
      child: switch (c.kind) {
        CelebrationKind.levelUp => _ModalCard(
          onDismiss: onDismiss,
          semanticsLabel:
              '$skillName ${levelChangeText(c.fromLevel, to)}, '
              '${titleForLevel(to)}',
          child: _LevelUpBody(
            skillName: skillName,
            fromLevel: c.fromLevel,
            toLevel: to,
            viaBonus: c.viaBonus,
          ),
        ),
        CelebrationKind.milestone => _MilestoneScreen(
          skillName: skillName,
          fromLevel: c.fromLevel,
          toLevel: to,
          viaBonus: c.viaBonus,
          onDismiss: onDismiss,
        ),
        CelebrationKind.hiddenTier => _ModalCard(
          onDismiss: onDismiss,
          semanticsLabel: '$skillName: ${hiddenTierName(c.tier!)}',
          child: _HiddenTierBody(skillName: skillName, tier: c.tier!),
        ),
        CelebrationKind.goalCompleted => _ModalCard(
          onDismiss: onDismiss,
          semanticsLabel: 'Hedefe ulaştın',
          child: _GoalBody(
            skillName: skillName,
            targetSeconds: goalTargetSeconds ?? 0,
          ),
        ),
        CelebrationKind.achievement => _AchievementToast(
          def: generalAchievements
              .where((d) => d.key == c.achievementKey)
              .firstOrNull,
          onDismiss: onDismiss,
        ),
      },
    );
  }
}

/// A centered card on a dark scrim; a tap anywhere dismisses it.
class _ModalCard extends StatelessWidget {
  const _ModalCard({
    required this.onDismiss,
    required this.semanticsLabel,
    required this.child,
  });

  final VoidCallback onDismiss;
  final String semanticsLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) => BlockSemantics(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      child: ColoredBox(
        color: MeskColors.scrim,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  label: semanticsLabel,
                  child: _GlowFrame(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        child,
                        const SizedBox(height: 12),
                        _ContinueButton(onDismiss),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The card surface whose 1 px border warms to gold over 250 ms while the
/// content fades in.
class _GlowFrame extends StatefulWidget {
  const _GlowFrame({required this.child});

  final Widget child;

  @override
  State<_GlowFrame> createState() => _GlowFrameState();
}

class _GlowFrameState extends State<_GlowFrame>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => DecoratedBox(
      decoration: BoxDecoration(
        color: MeskColors.surface,
        borderRadius: BorderRadius.circular(MeskCard.radius),
        border: Border.all(
          color: Color.lerp(
            MeskColors.surfaceBorder,
            MeskColors.accent,
            _controller.value,
          )!,
        ),
      ),
      child: child,
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      child: FadeTransition(opacity: _controller, child: widget.child),
    ),
  );
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton(this.onPressed);

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(88, 44),
      foregroundColor: MeskColors.accent,
      textStyle: const TextStyle(
        fontFamily: MeskType.sans,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    ),
    child: const Text('Devam'),
  );
}

final TextStyle _cardTitle = MeskType.titleItalic.copyWith(
  fontSize: 28,
  height: 1.15,
);
final TextStyle _cardLevel = MeskType.levelNumber.copyWith(fontSize: 30);
final TextStyle _cardText = MeskType.body14.copyWith(
  fontWeight: FontWeight.w400,
  color: MeskColors.muted,
  height: 1.45,
);

class _LevelUpBody extends StatelessWidget {
  const _LevelUpBody({
    required this.skillName,
    required this.fromLevel,
    required this.toLevel,
    required this.viaBonus,
  });

  final String skillName;
  final int? fromLevel;
  final int toLevel;
  final bool viaBonus;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 10,
    children: [
      MeskLabel(skillName),
      Text(levelChangeText(fromLevel, toLevel), style: _cardLevel),
      Text(
        titleForLevel(toLevel),
        textAlign: TextAlign.center,
        style: _cardTitle,
      ),
      Text(
        descriptionForLevel(toLevel),
        textAlign: TextAlign.center,
        style: _cardText,
      ),
      if (viaBonus) const Text('(bağ bonusu)', style: MeskType.caption),
    ],
  );
}

/// Milestone levels (10, 25, 50, 75, 99) take the whole screen and show a
/// gold-framed badge.
class _MilestoneScreen extends StatelessWidget {
  const _MilestoneScreen({
    required this.skillName,
    required this.fromLevel,
    required this.toLevel,
    required this.viaBonus,
    required this.onDismiss,
  });

  final String skillName;
  final int? fromLevel;
  final int toLevel;
  final bool viaBonus;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final from = fromLevel;
    final newBand = bandForLevel(toLevel);
    final bandChanged = from != null && bandForLevel(from) != newBand;
    return BlockSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: ColoredBox(
          color: MeskColors.bg,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  label:
                      '$skillName ${levelChangeText(from, toLevel)}, '
                      '${titleForLevel(toLevel)}',
                  child: _FadeIn(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 14,
                      children: [
                        _MilestoneBadge(toLevel),
                        const SizedBox(height: 6),
                        MeskLabel(skillName),
                        Text(levelChangeText(from, toLevel), style: _cardLevel),
                        Text(
                          titleForLevel(toLevel),
                          textAlign: TextAlign.center,
                          style: _cardTitle.copyWith(fontSize: 36),
                        ),
                        Text(
                          descriptionForLevel(toLevel),
                          textAlign: TextAlign.center,
                          style: _cardText,
                        ),
                        if (bandChanged)
                          Text(
                            '${newBand.label} kademesine geçtin',
                            textAlign: TextAlign.center,
                            style: MeskType.body14.copyWith(
                              color: MeskColors.accent,
                            ),
                          ),
                        if (viaBonus)
                          const Text('(bağ bonusu)', style: MeskType.caption),
                        _ContinueButton(onDismiss),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round badge in a double gold frame with the level number.
class _MilestoneBadge extends StatelessWidget {
  const _MilestoneBadge(this.level);

  final int level;

  @override
  Widget build(BuildContext context) => Container(
    width: 112,
    height: 112,
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: MeskColors.accent, width: 1.5),
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: MeskColors.surface,
        border: Border.all(color: MeskColors.accent),
      ),
      child: Center(
        child: Text(
          '$level',
          style: MeskType.bigNumber.copyWith(color: MeskColors.accent),
        ),
      ),
    ),
  );
}

/// Fades its child in over 250 ms.
class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _controller, child: widget.child);
}

/// "???" that slowly turns into the tier's name, then its description.
class _HiddenTierBody extends StatefulWidget {
  const _HiddenTierBody({required this.skillName, required this.tier});

  final String skillName;
  final HiddenTier tier;

  @override
  State<_HiddenTierBody> createState() => _HiddenTierBodyState();
}

class _HiddenTierBodyState extends State<_HiddenTierBody>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  late final _unknown = ReverseAnimation(
    CurvedAnimation(parent: _controller, curve: const Interval(0.35, 0.6)),
  );
  late final _name = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.45, 0.75),
  );
  late final _description = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.75, 1),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _cardTitle.copyWith(fontSize: 36);
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        MeskLabel(widget.skillName),
        Stack(
          alignment: Alignment.center,
          children: [
            FadeTransition(
              opacity: _unknown,
              child: Text('???', style: style),
            ),
            FadeTransition(
              opacity: _name,
              child: Text(
                hiddenTierName(widget.tier),
                textAlign: TextAlign.center,
                style: style.copyWith(color: MeskColors.accent),
              ),
            ),
          ],
        ),
        FadeTransition(
          opacity: _description,
          child: Text(
            hiddenTierDescription(widget.tier),
            textAlign: TextAlign.center,
            style: _cardText,
          ),
        ),
      ],
    );
  }
}

class _GoalBody extends StatelessWidget {
  const _GoalBody({required this.skillName, required this.targetSeconds});

  final String skillName;
  final int targetSeconds;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 10,
    children: [
      const MeskLabel('Hedef'),
      Text('Hedefe ulaştın', style: _cardTitle),
      Text(
        '$skillName · ${formatHours(targetSeconds)}',
        textAlign: TextAlign.center,
        style: _cardText,
      ),
    ],
  );
}

/// A small card above the navigation bar that leaves after four seconds
/// or on a tap; the app stays usable underneath.
class _AchievementToast extends StatefulWidget {
  const _AchievementToast({required this.def, required this.onDismiss});

  final AchievementDef? def;
  final VoidCallback onDismiss;

  @override
  State<_AchievementToast> createState() => _AchievementToastState();
}

class _AchievementToastState extends State<_AchievementToast>
    with SingleTickerProviderStateMixin {
  static const _life = Duration(seconds: 4);
  static const _fade = 250 / 4000;

  late final _controller = AnimationController(vsync: this, duration: _life);
  late final _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: _fade),
    TweenSequenceItem(tween: ConstantTween(1), weight: 1 - 2 * _fade),
    TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: _fade),
  ]).animate(_controller);

  @override
  void initState() {
    super.initState();
    if (widget.def == null) {
      // Unknown key (e.g. from a newer backup): nothing to show.
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDismiss());
      return;
    }
    _controller
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDismiss();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    if (def == null) return const SizedBox.shrink();
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          child: FadeTransition(
            opacity: _opacity,
            child: Semantics(
              container: true,
              liveRegion: true,
              child: Material(
                color: MeskColors.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(MeskCard.radius),
                  ),
                  side: BorderSide(color: MeskColors.accent),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onDismiss,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      spacing: 12,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: MeskColors.accent),
                          ),
                          child: const Icon(
                            Icons.star_outline,
                            size: 16,
                            color: MeskColors.accent,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 2,
                            children: [
                              const MeskLabel('Başarım açıldı'),
                              Text(def.name, style: MeskType.body15),
                              Text(def.condition, style: MeskType.caption),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
