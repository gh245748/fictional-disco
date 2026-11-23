import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The gold pill button (min height 44).
class MeskPrimaryButton extends StatelessWidget {
  const MeskPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  static const TextStyle textStyle = TextStyle(
    fontFamily: MeskType.sans,
    fontWeight: FontWeight.w700,
    fontSize: 14,
  );

  @override
  Widget build(BuildContext context) {
    final style =
        FilledButton.styleFrom(
          backgroundColor: MeskColors.accent,
          foregroundColor: MeskColors.bg,
          disabledBackgroundColor: MeskColors.track,
          disabledForegroundColor: MeskColors.faint,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: const StadiumBorder(),
          textStyle: textStyle,
          elevation: 0,
        ).copyWith(
          overlayColor: const WidgetStatePropertyAll(Color(0x22DEC089)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? MeskColors.track
                : states.contains(WidgetState.pressed)
                ? MeskColors.accentHover
                : MeskColors.accent,
          ),
        );
    final text = Text(label);
    final i = icon;
    return FilledButton(
      style: style,
      onPressed: onPressed,
      child: i == null
          ? text
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [Icon(i, size: 16), text],
            ),
    );
  }
}

/// The outlined pill button for secondary actions (min height 44).
class MeskSecondaryButton extends StatelessWidget {
  const MeskSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final text = Text(label);
    final i = icon;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: MeskColors.accent,
        disabledForegroundColor: MeskColors.faint,
        side: const BorderSide(color: MeskColors.surfaceBorder),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: const StadiumBorder(),
        textStyle: MeskPrimaryButton.textStyle,
      ),
      onPressed: onPressed,
      child: i == null
          ? text
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [Icon(i, size: 16), text],
            ),
    );
  }
}

/// A text button at least 44 px tall, for dialogs and sheets.
class MeskTextButton extends StatelessWidget {
  const MeskTextButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(44, 44),
      foregroundColor: color ?? MeskColors.accent,
      textStyle: MeskPrimaryButton.textStyle,
    ),
    child: Text(label),
  );
}
