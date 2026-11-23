import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// A surface card: radius 18, 1 px border, no shadow (spec §5.13).
class MeskCard extends StatelessWidget {
  const MeskCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  static const double radius = 18;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(radius)),
      side: BorderSide(color: MeskColors.surfaceBorder),
    );
    return Material(
      color: MeskColors.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}
