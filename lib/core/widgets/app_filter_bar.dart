import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppFilterChipData {
  const AppFilterChipData({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.avatar,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final Widget? avatar;
}

class AppFilterBar extends StatelessWidget {
  const AppFilterBar({
    super.key,
    required this.chips,
    this.showSearch = false,
    this.searchHint,
    this.searchValue,
    this.onSearchChanged,
    this.searchController,
  });

  final List<AppFilterChipData> chips;
  final bool showSearch;
  final String? searchHint;
  final String? searchValue;
  final ValueChanged<String>? onSearchChanged;
  final TextEditingController? searchController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSearch) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.sm,
            ),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: searchHint ?? 'Buscar...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                  vertical: AppSpacing.sm,
                ),
                isDense: true,
              ),
            ),
          ),
        ],
        if (chips.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final chip = chips[i];
                final chipColor = chip.color ?? theme.colorScheme.primary;
                return FilterChip(
                  label: Text(chip.label),
                  selected: chip.selected,
                  onSelected: (_) => chip.onTap(),
                  avatar: chip.avatar,
                  selectedColor: chipColor.withValues(alpha: 0.20),
                  checkmarkColor: chipColor,
                  labelStyle: chip.selected
                      ? TextStyle(color: chipColor, fontWeight: FontWeight.w600)
                      : null,
                );
              },
            ),
          ),
      ],
    );
  }
}
