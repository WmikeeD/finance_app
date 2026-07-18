# Finance App — Flutter · Dart 3.10+ · Material Design 3

## Stack
- Flutter + Material Design 3 (`useMaterial3: true`)
- Drift (ORM sobre SQLite) — schema v9
- fl_chart para gráficos, share_plus + pdf para exportación
- flutter_local_notifications, intl (locale `es_CL`)
- **Phosphor Icons** (`phosphor_flutter: ^2.1.0`) — íconos outline modernos
- **Google Fonts Inter** (`google_fonts: ^6.3.3`) — tipografía principal
- **Diseño Responsivo** — breakpoints: 600dp (mobile/tablet), 840dp (tablet/desktop)
- Plataformas: Android, iOS, Windows
- Sin BLoC ni Provider: estado reactivo con `StreamBuilder + Drift .watch()`

## Arquitectura
- Feature-first: `lib/features/<nombre>/<nombre>_screen.dart`
- Core compartido: `lib/core/{database,navigation,services,theme,utils,widgets}`
- Navegación nivel 1 → siempre `AppTabController.goToTab()` (NUNCA `Navigator.push()` para tabs)
- Navegación nivel 2 → `showModalBottomSheet` con `ResponsiveHelper.wrapModal()` para mantener barra de navegación visible
- **Navegación Adaptativa:**
  - Mobile (< 600dp): `BottomNavigationBar`
  - Tablet (600-840dp): `NavigationRail` colapsado (labelType: selected)
  - Desktop (> 840dp): `NavigationRail` extendido con labels siempre visibles

## Design System — AppTheme M3 (OBLIGATORIO)

### Archivos canónicos
- Tema: `lib/core/theme/app_theme.dart` — NO editar colores hardcodeados fuera de este archivo
- Widgets: `lib/core/widgets/widgets.dart` (barrel export)
- Fuente: Google Fonts Inter — aplicada globalmente en ThemeData

### Tema oscuro (fondo negro puro - 2026-05-27)
- Fondo principal: `#000000` (negro puro para máximo contraste)
- Cards: `#0D0D0D` (surfaceContainer)
- Elevación: `#1A1A1A` (surfaceContainerHigh)
- Texto principal: `#FFFFFF` (blanco puro)
- Texto secundario: `#9CA3AF` (gris claro)

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
**Fuente:** Google Fonts Inter (aplicada automáticamente)
```dart
Theme.of(context).textTheme.displaySmall    // balances principales (36px w300 Inter)
Theme.of(context).textTheme.headlineSmall   // títulos de pantalla (24px w600 Inter)
Theme.of(context).textTheme.titleMedium     // cabeceras de sección (16px w600 Inter)
Theme.of(context).textTheme.bodyMedium      // texto de transacciones (14px w400 Inter)
Theme.of(context).textTheme.labelSmall      // metadatos, fechas, badges (11px w500 Inter)
```

### Íconos — usar Phosphor Icons (outline style)
```dart
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ✅ CORRECTO - Phosphor Icons (outline, moderno)
PhosphorIcon(PhosphorIconsRegular.wallet)
PhosphorIcon(PhosphorIconsRegular.creditCard)
PhosphorIcon(PhosphorIconsRegular.trendDown)
PhosphorIcon(PhosphorIconsRegular.arrowUpRight)  // egreso ↗
PhosphorIcon(PhosphorIconsRegular.arrowDownLeft) // ingreso ↙

// ❌ EVITAR - Material Icons (solo usar si Phosphor no tiene equivalente)
Icon(Icons.account_balance_wallet)
Icon(Icons.trending_down)
```

**Íconos comunes:**
- Balance/Cuenta: `PhosphorIconsRegular.wallet`
- Crédito: `PhosphorIconsRegular.creditCard`
- Tendencia: `PhosphorIconsRegular.trendUp` / `trendDown`
- Personas: `PhosphorIconsRegular.users`
- Categorías: `PhosphorIconsRegular.squaresFour`
- Reportes: `PhosphorIconsRegular.chartBar`
- Calendario: `PhosphorIconsRegular.calendar`
- Notificaciones: `PhosphorIconsRegular.bell`

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
- `LiberacionDeudaBanner(liberacion)` — banner de liberación (cuotas + deudas) **[NUEVO 2026-05-27]**
- `ProyeccionCuotasMiniCard(proyeccion)` — mini gráfico 3 barras **[NUEVO 2026-05-27]**
- `CrearTransaccionModal(database)` — modal simplificado para crear transacción **[NUEVO 2026-05-27]**
- `AppSemanticIcon(icon, semanticColor, size)` — ícono con fondo semántico
- `AppSectionHeader(title, actionLabel?, onAction?)` — cabecera de sección
- `AppInfoBanner(message, variant)` — banner informativo (info/warning/danger/success)
- `AppEmptyState` — pantalla vacía con ícono, título, botón CTA
- `AppErrorState` — error con mensaje
- `AppFilterBar` — barra de búsqueda + chips de filtro
- `AppAmountText` — texto de monto con color automático según tipo

## Convenciones críticas de Flutter/Dart
- `Color.withValues(alpha: x)` — NO usar `.withOpacity()` (deprecado)
- `PhosphorIcon(PhosphorIconsRegular.X)` — usar Phosphor Icons, NO Material Icons
- `DropdownButtonFormField`: usar `initialValue` + `key: ValueKey(value)` — NO `value:`
- Operaciones multi-tabla: siempre dentro de `database.transaction()`
- Formularios simples → `showModalBottomSheet` con `StatefulBuilder`
- **Modales responsivos:** Siempre envolver con `ResponsiveHelper.wrapModal()` para limitar ancho en tablets/desktop
- Confirmaciones destructivas → `AlertDialog` con botón de color `error`
- `ScaffoldMessenger.of(ctx)` usando el context del builder, no el padre
- Tipografía: siempre via `textTheme.X` — fuente Inter aplicada automáticamente
- **Layouts responsivos:** Usar `ResponsiveHelper` o `ResponsiveBuilder` para adaptar UI según breakpoints

## Flujo de trabajo esperado
1. Antes de modificar un widget existente: leer el archivo actual completo
2. Nunca crear `TextStyle` con valores numéricos directos — siempre `textTheme.X`
3. Nunca crear colores con `Color(0xFF...)` en archivos de features — solo en `app_theme.dart`
4. Al agregar un widget nuevo: primero verificar si existe en `lib/core/widgets/`
5. `flutter analyze` debe pasar con 0 issues antes de terminar cualquier tarea

## Sistema de Responsividad (2026-07-18)

### Breakpoints Material Design 3
```dart
< 600dp   → Mobile (Compact)     → BottomNavigationBar
600-840dp → Tablet (Medium)      → NavigationRail colapsado
> 840dp   → Desktop (Expanded)   → NavigationRail extendido
```

### Helper de Responsividad
Archivo: `lib/core/utils/responsive.dart`

```dart
// Verificar tipo de dispositivo
ResponsiveHelper.isMobile(context)
ResponsiveHelper.isTablet(context)
ResponsiveHelper.isDesktop(context)

// Extension methods
context.isMobile
context.deviceType

// Valores adaptativos
ResponsiveHelper.getGridCrossAxisCount(context, mobile: 2, tablet: 3, desktop: 4)
ResponsiveHelper.getChartHeight(context)  // 200px / 300px / 400px
ResponsiveHelper.getHorizontalPadding(context)  // 16dp / 32dp / 48dp

// Wrapper para modales (limita ancho a 600dp en tablets/desktop)
showModalBottomSheet(
  context: context,
  builder: (_) => ResponsiveHelper.wrapModal(
    context: context,
    child: MyScreen(),
  ),
)

// Widget builder responsivo
ResponsiveBuilder(
  builder: (context, deviceType) {
    if (deviceType == DeviceType.mobile) {
      return MobileLayout();
    }
    return DesktopLayout();
  },
)
```

### Reglas de Implementación
1. **NUNCA** usar tamaños fijos (width/height hardcoded) para componentes principales
2. **SIEMPRE** envolver modales con `ResponsiveHelper.wrapModal()` 
3. **PREFERIR** `ResponsiveHelper.getValue()` sobre condicionales manuales
4. **GridView**: usar `getGridCrossAxisCount()` para crossAxisCount adaptativo
5. **Charts**: usar `getChartHeight()` en lugar de alturas fijas

## Comandos de build
```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs  # regenera Drift
flutter analyze
flutter run -d windows   # desktop
flutter run              # móvil (dispositivo conectado)
```
