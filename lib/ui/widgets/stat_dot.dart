import 'package:material_ui/material_ui.dart';

import '../../domain/stats.dart';
import '../theme.dart';

/// A small filled circle in the stat's color.
class StatDot extends StatelessWidget {
  const StatDot(this.stat, {super.key, this.size = 8});

  final Stat stat;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: BoxDecoration(color: statColor(stat), shape: BoxShape.circle),
    ),
  );
}
