import 'package:flutter/material.dart';

/// Example feature-level widget. Use for home-specific UI pieces.
class HomePlaceholder extends StatelessWidget {
  const HomePlaceholder({super.key, this.label = 'Placeholder'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label),
    );
  }
}
