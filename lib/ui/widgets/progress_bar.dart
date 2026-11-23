import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// A thin rounded bar on the [MeskColors.track] color.
class MeskProgressBar extends StatelessWidget {
  const MeskProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 3,
  });

  /// 0..1; values outside are clamped.
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: SizedBox(
      height: height,
      child: ColoredBox(
        color: MeskColors.track,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            heightFactor: 1,
            child: ColoredBox(color: color),
          ),
        ),
      ),
    ),
  );
}
