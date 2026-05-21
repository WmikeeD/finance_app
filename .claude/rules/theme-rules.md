# Reglas de tema — aplican a todos los archivos en lib/

## Prohibido en archivos de features y widgets

```
❌ Color(0xFF...)         → usar AppColors.X o scheme.X
❌ Colors.red             → usar AppTheme.expenseColor(context)
❌ Colors.green           → usar AppTheme.incomeColor(context)
❌ FontWeight.w700        → usar w600 máximo (w700 rompe jerarquía M3)
❌ fontSize: 18           → usar textTheme.titleLarge
❌ borderRadius: BorderRadius.circular(8)  → usar AppRadius.md
❌ BoxShadow(...)         → usar surfaceContainer + outlineVariant border
❌ .withOpacity(x)        → usar .withValues(alpha: x)
❌ Container(color: ...)  → en tarjetas usar decoration con scheme colors
```

## Patrón correcto para tarjetas (Card M3)

```dart
Container(
  decoration: BoxDecoration(
    color: scheme.surfaceContainer,           // ← fondo con surface tint
    borderRadius: BorderRadius.circular(AppRadius.xxl),
    border: Border.all(
      color: scheme.outlineVariant,
      width: 0.5,
    ),
  ),
)
```

## Patrón correcto para íconos semánticos

```dart
// ✅ Usar AppSemanticIcon
AppSemanticIcon(
  icon: Icons.restaurant,
  semanticColor: SemanticColor.expense,
)

// ❌ No hacer esto
Container(
  color: Colors.red.withOpacity(0.1),
  child: Icon(Icons.restaurant, color: Colors.red),
)
```

## Patrón correcto para montos

```dart
// ✅ Usar AppAmountText o AppTheme helpers
Text(
  '-\$5.000',
  style: textTheme.titleSmall?.copyWith(
    color: AppTheme.expenseColor(context),
    fontWeight: FontWeight.w600,
  ),
)
```

## NavigationBar — indicador M3

El NavigationBar ya está configurado en ThemeData. No crear NavigationBar custom.
El ícono activo usa `indicatorColor: scheme.primary.withValues(alpha: 0.2)` con
`indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))`.
