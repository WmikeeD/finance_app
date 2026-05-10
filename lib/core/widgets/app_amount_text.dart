import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class AppAmountText extends StatelessWidget {
  const AppAmountText({
    super.key,
    required this.amount,
    this.showSign = false,
    this.semanticColor = false,
    this.style,
  });

  final double amount;
  final bool showSign;
  final bool semanticColor;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.displaySmall ?? const TextStyle();

    Color? color;
    if (semanticColor) {
      color = amount >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor;
    }

    String text = Formatters.monedaConSimbolo(amount.abs());
    if (showSign) {
      text = amount >= 0 ? '+$text' : '-$text';
    }

    return Text(text, style: base.copyWith(color: color));
  }
}
