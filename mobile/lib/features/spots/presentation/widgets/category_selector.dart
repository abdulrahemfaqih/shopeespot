import 'package:flutter/material.dart';
import '../../../../app/theme/tokens.dart';
import '../../domain/category.dart';

class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onChanged,
  });

  final Category selectedCategory;
  final ValueChanged<Category> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Row(
      children: [
        Expanded(
          child: _CategoryOption(
            category: Category.shopeefood,
            label: 'ShopeeFood',
            icon: Icons.restaurant,
            isSelected: selectedCategory == Category.shopeefood,
            onTap: () => onChanged(Category.shopeefood),
          ),
        ),
        SizedBox(width: tokens.space12),
        Expanded(
          child: _CategoryOption(
            category: Category.spx,
            label: 'SPX',
            icon: Icons.inventory_2_outlined,
            isSelected: selectedCategory == Category.spx,
            onTap: () => onChanged(Category.spx),
          ),
        ),
      ],
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.category,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final Category category;
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bgColor = isSelected ? tokens.actionFill : tokens.surface;
    final fgColor = isSelected ? tokens.actionOnFill : tokens.textPrimary;
    final borderColor = isSelected ? tokens.actionFill : tokens.border;

    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        child: Container(
          height: 48.0,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            border: Border.all(color: borderColor, width: tokens.borderWidth),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20.0, color: fgColor),
              SizedBox(width: tokens.space8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.0,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: fgColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
