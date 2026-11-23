import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// A [MeskType.sectionTitle] heading with an optional trailing widget on the
/// same baseline.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Expanded(
        child: Semantics(
          header: true,
          child: Text(title, style: MeskType.sectionTitle),
        ),
      ),
      ?trailing,
    ],
  );
}
