import 'package:flutter/material.dart';

class UsageSlider extends StatelessWidget {
  final double value;
  final Function(double) onChanged;

  const UsageSlider({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mục tiêu hàng ngày',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${value.toStringAsFixed(1)} giờ',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: colorScheme.surfaceContainerHighest,
            thumbColor: colorScheme.primary,
            overlayColor: colorScheme.primary.withOpacity(0.2),
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
            trackHeight: 6,
          ),
          child: Slider(
            min: 0.5,
            max: 12,
            divisions: 23,
            value: value,
            label: '${value.toStringAsFixed(1)}h',
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0.5h',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            Text(
              '12h',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
