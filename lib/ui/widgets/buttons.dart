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
