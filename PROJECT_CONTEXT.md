# Finance App — Contexto del Proyecto

## Visión General

Aplicación móvil (Android/iOS) para administración de finanzas personales. El objetivo es proveer a una persona natural el control completo de sus ingresos, egresos, cuentas, deudas y proyección financiera futura, con una experiencia visual personalizable.

**Estado actual**: MVP completado — fase de extensión  
**Plataformas objetivo**: Android, iOS  
**Tecnología**: Flutter + Drift (SQLite) + Material Design 3  
**Versión**: 1.0.0 — DB versión 8

---

## Últimos Cambios (Sesión 2025-05-03)

### Sprint 6 — Exportación + Notificaciones

**Exportación (CSV y PDF)**
- Nuevo servicio `lib/core/services/exportacion_service.dart`
  - `exportarTransaccionesCSV(...)` — genera CSV con todas las columnas usando `csv 8.x` (`CsvEncoder`)
  - `exportarTransaccionesPDF(...)` — genera PDF con resumen + tabla de transacciones usando `pdf`
  - `exportarReportePDF(...)` — genera PDF de reporte mensual con resumen, categorías e histórico
  - Compartición nativa vía `share_plus` (`SharePlus.instance.share`)
- `transacciones_screen.dart` — botón share en AppBar con menú CSV/PDF; exporta el filtro activo
- `reportes_screen.dart` — botón share en AppBar; exporta el mes seleccionado como PDF

**Notificaciones locales**
- Nuevos campos en `perfil.dart`: `notifCuotas (bool)`, `notifDiasAntes (int, 1-7)`, `notifGastosFijos (bool)`
- Migración DB v7 → v8 con los tres campos
- Nuevo servicio `lib/core/services/notification_service.dart`
  - `initialize()` — inicializa plugin + timezone America/Santiago
  - `solicitarPermiso()` — solicita permiso al sistema operativo
  - `tienePermiso()` — consulta estado actual del permiso
  - `programarNotificaciones(db)` — cancela todas y re-programa según perfil
  - Programa `zonedSchedule` para cuotas y gastos fijos próximos
- `main.dart` — solicita permiso + programa notificaciones al arrancar
- `configuracion_screen.dart` — nueva sección "Notificaciones" solo editable si hay permiso concedido
- `AndroidManifest.xml` — permisos `POST_NOTIFICATIONS`, `USE_EXACT_ALARM`, receivers de boot

**Actualización de build Android**
- Gradle: `7.6.3` → `8.7`
- AGP: `7.3.0` → `8.6.0`
- Kotlin: `1.7.10` → `2.1.0`
- Java: `VERSION_1_8` → `VERSION_17`
- Core library desugaring habilitado con `desugar_jdk_libs:2.1.4` (requerido por `flutter_local_notifications 21`)

---

## Objetivos del Producto

| Objetivo | Estado |
|----------|--------|
| Gestión de ingresos y egresos con categorías | ✅ Implementado |
| Control de múltiples cuentas (débito/crédito/efectivo/ahorro) | ✅ Implementado |
| Control de préstamos (prestado a terceros, con cuotas e interés) | ✅ Implementado |
| Gestión de gastos fijos mensuales | ✅ Implementado |
| Simulación/proyección de compras a futuro | ✅ Implementado |
| Filtros y búsqueda de transacciones | ✅ Implementado |
| Reportes con gráficos (torta + barras) | ✅ Implementado |
| Subcategorías con UI jerárquica | ✅ Implementado |
| Personalización del tema (color base, modo oscuro/claro) | ✅ Implementado |
| Color dinámico según estado de cuenta | ✅ Implementado |
| Exportación CSV y PDF | ✅ Implementado |
| Notificaciones locales de vencimientos | ✅ Implementado |
| Sincronización con Supabase | 🔮 Planificado (Fase 3) |

---

## Arquitectura Técnica

### Stack
- **Framework**: Flutter 3.38.8 (Dart 3.10.7)
- **Base de datos**: Drift (ORM type-safe sobre SQLite)
- **State management**: StreamBuilder + Drift Streams (reactivo)
- **Gráficos**: fl_chart 1.2.0 (PieChart, BarChart)
- **Formato**: intl (moneda CLP, fechas en español)
- **Notificaciones**: flutter_local_notifications 21.0.0 + timezone 0.11.0
- **Exportación**: csv 8.0.0, pdf, printing, share_plus
- **BLoC preparado**: flutter_bloc instalado, no activo aún

### Configuración de Build Android
```
Gradle:  8.7
AGP:     8.6.0
Kotlin:  2.1.0
Java:    17
minSdk:  flutter.minSdkVersion
targetSdk: flutter.targetSdkVersion
compileSdk: flutter.compileSdkVersion
Core library desugaring: desugar_jdk_libs 2.1.4
```

### Estructura de Archivos
```
lib/
├── main.dart                          # App root + inicialización notif.
├── core/
│   ├── database/
│   │   ├── database.dart              # AppDatabase Drift (DB v8)
│   │   ├── database.g.dart            # Generado (NO editar)
│   │   └── tables/                    # 9 tablas definidas
│   │       ├── cuentas.dart
│   │       ├── categorias.dart
│   │       ├── personas.dart
│   │       ├── transacciones.dart
│   │       ├── cuotas.dart
│   │       ├── perfil.dart            # +notifCuotas/notifDiasAntes/notifGastosFijos
│   │       ├── deudas.dart
│   │       ├── pagos_deuda.dart
│   │       └── gastos_fijos.dart
│   ├── services/
│   │   ├── exportacion_service.dart   # CSV + PDF + share_plus
│   │   └── notification_service.dart  # Permisos + zonedSchedule
│   ├── theme/app_theme.dart           # Color dinámico + Material3
│   ├── utils/formatters.dart          # CLP, fechas ES
│   └── widgets/app_drawer.dart        # Navegación global
└── features/
    ├── home/                          # Dashboard
    ├── cuentas/                       # CRUD cuentas
    ├── categorias/                    # CRUD + subcategorías jerárquicas
    ├── personas/                      # CRUD personas + deudas
    ├── transacciones/                 # CRUD + filtros + exportar
    ├── gastos_fijos/                  # CRUD gastos fijos
    ├── reportes/                      # Reportes gráficos + exportar
    ├── proyeccion/                    # Simulación financiera
    └── configuracion/                 # Perfil, tema, color dinámico, notif.
```

---

## Esquema de Base de Datos (v8)

| Tabla | Propósito | Estado |
|-------|-----------|--------|
| `cuentas` | Cuentas bancarias, tarjetas, efectivo, ahorro | ✅ |
| `categorias` | Categorías jerárquicas de ingresos/egresos | ✅ |
| `personas` | Personas asociadas a préstamos | ✅ |
| `transacciones` | Movimientos financieros (central) | ✅ |
| `cuotas` | Desglose de pagos de compras a crédito | ✅ |
| `perfiles` | Configuración del usuario (singleton id=1) | ✅ |
| `deudas` | Seguimiento de deudas de terceros al usuario | ✅ |
| `pagos_deuda` | Abonos parciales a deudas | ✅ |
| `gastos_fijos` | Gastos recurrentes mensuales | ✅ |

### Historial de Migraciones
```
v1 → v2: Tabla PERFILES
v2 → v3: Campo 'meta' en CUENTAS
v3 → v4: Tablas DEUDAS y PAGOS_DEUDA
v4 → v5: Tabla GASTOS_FIJOS
v5 → v6: Campo 'temaOscuro' en PERFILES
v6 → v7: Campos 'colorDinamico', 'balanceMinimo', 'balanceMaximo' en PERFILES
v7 → v8: Campos 'notifCuotas', 'notifDiasAntes', 'notifGastosFijos' en PERFILES
```

---

## Features Implementadas

### Cuentas
- Tipos: `efectivo`, `debito`, `credito`, `ahorro`
- Tarjetas de crédito: límite, día cierre, día pago
- Cuentas de ahorro: meta con barra de progreso
- CRUD completo con validaciones

### Transacciones
- Tipos: `ingreso` / `egreso`
- Formas de pago: `debito` / `credito`
- Soporte para compras en cuotas con/sin interés
- Flag `esPrestamo`: vincula transacción con persona
- Filtros: búsqueda, tipo, cuenta, rango de fechas
- Exportar el filtro activo a CSV o PDF

### Gastos Fijos
- CRUD con nombre, monto, día de vencimiento, categoría (FK)
- Toggle activo/inactivo por ítem
- Card de resumen: total activo + conteo
- Integrado en proyección (`_incluirGastosFijos`)

### Proyección / Simulación
- Algoritmo mensual con Drift joins (cuotas → transacciones → cuentas)
- Variables: cuotas pendientes, gastos fijos, sueldo esperado, préstamos a cobrar
- Filtros: cuenta, incluir gastos fijos, número de meses
- Mes de liberación: primer mes sin compromisos pendientes
- Visualización: gráfico de barras + lista expandible por mes

### Reportes
- Selector de mes (navegación hacia atrás, tope en mes actual)
- Cards de resumen: ingresos, egresos, balance del mes
- PieChart interactivo de gastos por categoría
- BarChart de evolución últimos 6 meses
- Exportar reporte del mes como PDF

### Categorías
- Vista jerárquica: padres con `ExpansionTile` mostrando hijos
- Popup menu con "Agregar subcategoría"
- Bottom sheet con selector de categoría padre opcional

### Configuración
- Perfil: nombre, fecha de nacimiento
- Color base: 10 colores predefinidos
- Tema: SegmentedButton Claro / Sistema / Oscuro
- Color dinámico: toggle + preview en tiempo real + leyenda de zonas + límites editables
- Notificaciones: solicitud de permiso, toggles cuotas/gastos fijos, selector de días anticipación

### Color Dinámico
- Zonas: Rojo oscuro (negativo) → Naranja (precaución) → Verde (estable) → Teal (cómodo) → Dorado (meta)
- Límites configurables: balance mínimo (default \$100k) y máximo (default \$50M)
- Se calcula en tiempo real observando cuentas efectivo + débito
- StreamBuilder anidado en `main.dart` solo cuando está activado

### Notificaciones
- Solicitud de permiso al primer arranque
- Auto-programación de alertas al inicio (timezone America/Santiago)
- Cuotas pendientes próximas a vencer (N días antes, configurable)
- Gastos fijos activos próximos a vencer (N días antes, configurable)
- Configurables desde pantalla de configuración (solo si permiso concedido)

### Exportación
- CSV: todas las columnas (fecha, tipo, descripción, categoría, cuenta, forma pago, monto, cuotas, préstamo, estado, notas)
- PDF transacciones: encabezado, resumen financiero, tabla de datos
- PDF reporte: resumen, tabla de categorías con %, evolución histórica 6 meses
- Compartición nativa (WhatsApp, Drive, email, etc.)

---

## Pantallas y Estado

| Pantalla | Acceso | Estado |
|----------|--------|--------|
| Home / Dashboard | Inicio | ✅ Completo |
| Cuentas | Drawer | ✅ Completo |
| Categorías | Drawer | ✅ Completo + subcategorías |
| Personas | Drawer | ✅ Completo |
| Transacciones | Drawer | ✅ Completo + filtros + exportar |
| Gastos Fijos | Drawer | ✅ Completo |
| Reportes | Drawer | ✅ Completo + exportar |
| Proyección | `/proyeccion` desde Home | ✅ Completo |
| Configuración | Drawer | ✅ Completo + notif. |

---

## Convenciones de Código

- Moneda: CLP, formato `$9.000` (punto como separador de miles)
- Fechas: `dd/MM/yyyy` en español
- Locale: `es_CL`
- Timezone notificaciones: `America/Santiago`
- IDs: Int auto-increment local (UUID preparado para sync futura)
- Foreign keys: activas (`PRAGMA foreign_keys = ON`)
- Generación código: `dart run build_runner build --delete-conflicting-outputs` (post cambios en tablas)
- `database.g.dart` excluido del análisis en `analysis_options.yaml`

---

## Roadmap de Desarrollo

### Fase 1 — MVP (Completada ✅)
- [x] Gestión de cuentas múltiples
- [x] CRUD de transacciones con cuotas
- [x] Control de préstamos a personas
- [x] Dashboard con KPIs
- [x] Tema personalizable (color + oscuro/claro)
- [x] Gastos fijos UI completa
- [x] Proyección/simulación completa
- [x] Filtros en transacciones
- [x] Reportes con gráficos
- [x] Subcategorías UI
- [x] Color dinámico según salud financiera
- [x] Exportación CSV + PDF
- [x] Notificaciones locales

### Fase 2 — Mejoras de UX
- [ ] Paginación / lazy loading en transacciones
- [ ] Tests unitarios e integración
- [ ] Manejo robusto de errores en toda la app
- [ ] Optimización de widgets con `const`
- [ ] Dashboard: alertas de cuotas próximas en la semana
- [ ] Editar perfil con foto

### Fase 3 — Expansión
- [ ] Sincronización con Supabase (campos `syncId`, `sincronizado` ya preparados)
- [ ] Backup automático Google Drive
- [ ] Importación desde CSV bancario
- [ ] Análisis predictivo / tendencias
- [ ] Multi-moneda

---

## Cómo Ejecutar

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Solo si se modificaron tablas Drift
flutter run
```

## Cómo compilar APK debug

```bash
flutter build apk --debug
# Salida: build/app/outputs/flutter-apk/app-debug.apk
```
