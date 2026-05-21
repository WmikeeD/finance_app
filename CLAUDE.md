# Finance App — Flutter · Dart 3.10+ · Material Design 3

## Stack
- Flutter + Material Design 3 (`useMaterial3: true`)
- Drift (ORM sobre SQLite) — schema v9
- fl_chart para gráficos, share_plus + pdf para exportación
- flutter_local_notifications, intl (locale `es_CL`)
- Plataformas: Android, iOS, Windows
- Sin BLoC ni Provider: estado reactivo con `StreamBuilder + Drift .watch()`

## Arquitectura
- Feature-first: `lib/features/<nombre>/<nombre>_screen.dart`
- Core compartido: `lib/core/{database,navigation,services,theme,utils,widgets}`
- Navegación nivel 1 → siempre `AppTabController.goToTab()` (NUNCA `Navigator.push()` para tabs)
- Navegación nivel 2 → `Navigator.push()` para Cuentas, Categorías, Personas, Gastos Fijos

## Design System — AppTheme M3 (OBLIGATORIO)

### Archivos canónicos
- Tema: `lib/core/theme/app_theme.dart` — NO editar colores hardcodeados fuera de este archivo
- Widgets: `lib/core/widgets/widgets.dart` (barrel export)

### Tokens de color — usar SIEMPRE, nunca hex hardcodeado
```dart
// Colores del scheme (adaptan light/dark automáticamente)
Theme.of(context).colorScheme.primary          // #00C896 teal
Theme.of(context).colorScheme.surface          // fondo principal
Theme.of(context).colorScheme.surfaceContainer // tarjetas
Theme.of(context).colorScheme.onSurface        // texto principal
Theme.of(context).colorScheme.outlineVariant   // bordes suaves

// Colores semánticos (requieren context para light/dark)
AppTheme.incomeColor(context)   // verde  → ingresos
AppTheme.expenseColor(context)  // rojo   → egresos
AppTheme.creditColor(context)   // morado → cuotas/crédito
AppTheme.savingsColor(context)  // azul   → ahorro
AppColors.warning               // amber  → alertas (constante, no cambia)
```

### Escala tipográfica — usar textTheme, nunca TextStyle manual
```dart
Theme.of(context).textTheme.displaySmall    // balances principales (36px w300)
Theme.of(context).textTheme.headlineSmall   // títulos de pantalla (24px w500)
Theme.of(context).textTheme.titleMedium     // cabeceras de sección (16px w600)
Theme.of(context).textTheme.bodyMedium      // texto de transacciones (14px w400)
Theme.of(context).textTheme.labelSmall      // metadatos, fechas, badges (11px w500)
```

### Radios y espaciado — usar siempre las constantes
```dart
AppRadius.xxl  // 28dp → tarjetas principales (M3 large)
AppRadius.xl   // 20dp → tarjetas secundarias
AppRadius.lg   // 16dp → botones, inputs, ítems de lista
AppRadius.md   // 12dp → íconos semánticos, chips pequeños

AppSpacing.base // 16dp → padding estándar de pantalla
AppSpacing.lg   // 20dp → padding interno de tarjetas grandes
AppSpacing.md   // 12dp → gap entre elementos
AppSpacing.sm   //  8dp → gap pequeño
```

### Elevación M3 — Surface Tint, no box-shadow
- ✅ `surfaceContainer` / `surfaceContainerHigh` para profundidad
- ✅ `border: Border.all(color: scheme.outlineVariant, width: 0.5)`
- ❌ NUNCA `BoxDecoration(boxShadow: [BoxShadow(...)])`
- ❌ NUNCA `elevation: N` en Card (siempre `elevation: 0`)

## Componentes reutilizables disponibles
Siempre verificar si existe antes de crear uno nuevo:
- `FinanceHeroCard` — balance principal del dashboard
- `TransactionListItem(type, description, category, date, amount)` — ítem de lista
- `LiberacionBanner(releaseMonth, monthsRemaining, ...)` — banner de proyección
- `AppSemanticIcon(icon, semanticColor, size)` — ícono con fondo semántico
- `AppSectionHeader(title, actionLabel?, onAction?)` — cabecera de sección
- `AppInfoBanner(message, variant)` — banner informativo (info/warning/danger/success)
- `AppEmptyState` — pantalla vacía con ícono, título, botón CTA
- `AppErrorState` — error con mensaje
- `AppFilterBar` — barra de búsqueda + chips de filtro
- `AppAmountText` — texto de monto con color automático según tipo

## Convenciones críticas de Flutter/Dart
- `Color.withValues(alpha: x)` — NO usar `.withOpacity()` (deprecado)
- `DropdownButtonFormField`: usar `initialValue` + `key: ValueKey(value)` — NO `value:`
- Operaciones multi-tabla: siempre dentro de `database.transaction()`
- Formularios simples → `showModalBottomSheet` con `StatefulBuilder`
- Confirmaciones destructivas → `AlertDialog` con botón de color `error`
- `ScaffoldMessenger.of(ctx)` usando el context del builder, no el padre

## Flujo de trabajo esperado
1. Antes de modificar un widget existente: leer el archivo actual completo
2. Nunca crear `TextStyle` con valores numéricos directos — siempre `textTheme.X`
3. Nunca crear colores con `Color(0xFF...)` en archivos de features — solo en `app_theme.dart`
4. Al agregar un widget nuevo: primero verificar si existe en `lib/core/widgets/`
5. `flutter analyze` debe pasar con 0 issues antes de terminar cualquier tarea

## Comandos de build
```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs  # regenera Drift
flutter analyze
flutter run -d windows   # desktop
flutter run              # móvil (dispositivo conectado)
```
