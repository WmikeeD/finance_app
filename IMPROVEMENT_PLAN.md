# Plan de Mejora — Finance App

> **Objetivo**: Completar el MVP funcional y sentar las bases para las fases siguientes, priorizando las features de mayor valor para el usuario.

---

## Prioridad 1 — Completar MVP Core

### 1.1 Gastos Fijos — UI Completa
**Qué**: La tabla `gastos_fijos` existe en DB pero no tiene interfaz de usuario.  
**Por qué importa**: Es dato esencial para que la proyección funcione correctamente.

**Tareas**:
- [ ] Pantalla `gastos_fijos_screen.dart` dentro de `features/gastos_fijos/`
- [ ] CRUD completo: crear, listar, editar, activar/desactivar
- [ ] Agregar ruta y acceso desde el drawer
- [ ] Integrar en Home: mostrar total de gastos fijos del mes
- [ ] Migración DB v4 → v5: ajustar campos si es necesario
- [ ] Selector de categoría existente (FK a tabla categorias)

**Campos UI requeridos**:
- Nombre del gasto
- Monto mensual
- Día de vencimiento (1-31)
- Categoría asociada
- Toggle activo/inactivo

---

### 1.2 Proyección / Simulación — Completar Lógica
**Qué**: La estructura de pantalla y modelos existen, pero `_calcularProyeccion()` no está implementado y los widgets de visualización están vacíos.  
**Por qué importa**: Es la feature diferenciadora del producto.

**Tareas**:
- [ ] Implementar algoritmo `_calcularProyeccion()`:
  - Iterar mes a mes desde hoy hasta N meses
  - Para cada mes: sumar cuotas vencidas + gastos fijos activos
  - Restar ingresos esperados (sueldo configurado)
  - Incluir préstamos a cobrar ese mes
  - Calcular balance proyectado acumulado
- [ ] Completar widget `grafico_barras.dart` (bar chart por mes)
- [ ] Completar widget `detalle_meses.dart` (lista expandible por mes)
- [ ] Completar widget `liberacion_banner.dart` (mes en que $0 compromisos)
- [ ] Agregar dependencia de charts: `fl_chart` o `syncfusion_flutter_charts`
- [ ] Filtro por cuenta específica funcional
- [ ] Simulación de nueva compra: mostrar impacto en proyección existente

**Modelo de cálculo por mes**:
```
balance_mes = sueldo_configurado
            - sum(cuotas con fecha_vencimiento en ese mes)
            - sum(gastos_fijos activos)
            + sum(préstamos a cobrar ese mes)
```

---

### 1.3 Migración DB v5 — Gastos Fijos Mejorado
**Qué**: Revisar y normalizar tabla `gastos_fijos` con FK a categorías.

**Tareas**:
- [ ] Verificar campo `categoria` en `gastos_fijos` — cambiar a `categoriaId INT FK`
- [ ] Agregar migración v4 → v5 en `database.dart`
- [ ] Regenerar `database.g.dart` con build_runner

---

## Prioridad 2 — Experiencia de Usuario

### 2.1 Filtros y Búsqueda en Transacciones
**Qué**: La pantalla de transacciones solo lista sin filtros.

**Tareas**:
- [ ] Barra de búsqueda por descripción
- [ ] Filtro por rango de fechas (DateRange picker)
- [ ] Filtro por cuenta
- [ ] Filtro por categoría
- [ ] Filtro por tipo (ingreso/egreso)
- [ ] Ordenamiento (fecha, monto)
- [ ] Paginación o lazy loading (evitar cargar todas las transacciones)

---

### 2.2 Reportes y Gráficos
**Qué**: No existe sección de reportes. El usuario no puede ver tendencias.

**Tareas**:
- [ ] Nueva pantalla `reportes_screen.dart`
- [ ] Gráfico de torta: distribución de egresos por categoría (mes actual)
- [ ] Gráfico de líneas: evolución de balance (últimos 6 meses)
- [ ] Resumen mensual: total ingresos vs egresos
- [ ] Top 5 categorías con mayor gasto
- [ ] Comparativa mes actual vs mes anterior

---

### 2.3 Subcategorías — UI Jerárquica
**Qué**: La DB soporta subcategorías (campo `categoriaPadreId`) pero la UI las muestra planas.

**Tareas**:
- [ ] Árbol expandible de categorías en `categorias_screen`
- [ ] Selector de categoría con subcategorías en formulario de transacción
- [ ] Filtrar subcategorías según categoría padre seleccionada

---

### 2.4 Mejoras en Dashboard (Home)
**Tareas**:
- [ ] Mostrar total de gastos fijos mensuales como KPI
- [ ] Alertas: cuotas que vencen en los próximos 7 días
- [ ] Alertas: préstamos con fecha próxima a vencer
- [ ] Estado de cuenta de ahorro: porcentaje de meta alcanzada
- [ ] Botón rápido para agregar transacción directamente desde Home

---

## Prioridad 3 — Personalización y Diseño

### 3.1 Modo Oscuro / Claro — Toggle Explícito
**Qué**: Flutter usa el modo del sistema. El usuario debe poder forzar uno.

**Tareas**:
- [ ] Agregar campo `temaOscuro BOOL` en tabla `perfil`
- [ ] Toggle en `configuracion_screen`
- [ ] Migración DB v5 → v6 (o incluir en v5)
- [ ] Aplicar en `main.dart` con `themeMode` dinámico

---

### 3.2 Color Dinámico Según Estado de Cuenta (Fase 2)
**Qué**: Feature planificada — el color base cambia automáticamente según la "salud" financiera.

**Diseño propuesto**:
```
Verde:   balance positivo, sin compromisos pendientes
Amarillo: compromisos moderados, crédito < 70% usado
Naranja: compromisos altos o crédito > 70% usado
Rojo:    balance negativo o cuotas vencidas sin pagar
```

**Tareas**:
- [ ] Definir lógica de "estado de cuenta" (índice de salud financiera)
- [ ] Agregar campo `colorDinamico BOOL` en perfil (activa/desactiva la función)
- [ ] Calcular color en tiempo real al cargar Home
- [ ] Animación de transición al cambiar color
- [ ] Permitir desactivar si el usuario prefiere color fijo

---

## Prioridad 4 — Calidad y Robustez

### 4.1 Manejo de Errores
**Tareas**:
- [ ] Agregar `try/catch` en todas las operaciones de DB
- [ ] Mostrar `SnackBar` de error cuando falla una operación
- [ ] Validar consistencia: no eliminar cuenta con transacciones asociadas
- [ ] Mensaje de error claro cuando se intenta eliminar categoría en uso

---

### 4.2 Tests
**Tareas**:
- [ ] Tests unitarios para cálculos (proyección, interés, flujo del mes)
- [ ] Tests de widget para formularios principales
- [ ] Tests de integración con DB en memoria (Drift soporta `NativeDatabase.memory()`)

---

### 4.3 Performance
**Tareas**:
- [ ] Paginación en lista de transacciones (actualmente carga todo)
- [ ] `const` constructors donde aplique
- [ ] Revisar streams innecesarios duplicados en pantalla Home

---

## Prioridad 5 — Expansión (Fase 3)

### 5.1 Exportación de Datos
- [ ] Exportar transacciones a CSV
- [ ] Exportar resumen mensual a PDF
- [ ] Compartir resumen (share_plus)

### 5.2 Notificaciones Locales
- [ ] Recordatorio de cuota próxima (3 días antes)
- [ ] Alerta de préstamo por vencer
- [ ] Resumen semanal de gastos
- [ ] Dependencia: `flutter_local_notifications`

### 5.3 Sincronización con Supabase
> Los campos `syncId` y `sincronizado` ya están preparados en transacciones.

- [ ] Configurar proyecto Supabase
- [ ] Implementar auth (email/Google)
- [ ] Sync bidireccional de tablas principales
- [ ] Manejo de conflictos (last-write-wins o manual)

### 5.4 Backup / Restaurar
- [ ] Exportar DB completa como archivo `.sqlite`
- [ ] Importar DB desde archivo
- [ ] Backup automático a Google Drive

---

## Orden de Implementación Recomendado

```
Sprint 1 (2-3 semanas):
  ├── 1.1 Gastos Fijos UI
  ├── 1.3 Migración DB v5
  └── 2.4 Mejoras Dashboard (alertas, gastos fijos en KPI)

Sprint 2 (2-3 semanas):
  ├── 1.2 Proyección — Algoritmo completo
  └── Agregar fl_chart y visualizaciones

Sprint 3 (1-2 semanas):
  ├── 2.1 Filtros en Transacciones
  └── 3.1 Toggle tema oscuro/claro

Sprint 4 (2-3 semanas):
  ├── 2.2 Reportes y gráficos
  └── 2.3 Subcategorías UI

Sprint 5 (2 semanas):
  ├── 4.1 Manejo de errores
  ├── 4.2 Tests básicos
  └── 3.2 Color dinámico (Fase 2)

Sprint 6+:
  └── Exportación, notificaciones, Supabase sync
```

---

## Dependencias a Agregar

| Paquete | Versión | Propósito |
|---------|---------|----------|
| `fl_chart` | ^0.70.0 | Gráficos (barras, líneas, torta) |
| `flutter_local_notifications` | ^17.0.0 | Notificaciones locales |
| `share_plus` | ^10.0.0 | Compartir archivos/texto |
| `csv` | ^6.0.0 | Exportar a CSV |
| `pdf` | ^3.11.0 | Generar PDF |
| `path` | ^1.9.0 | Manejo de rutas de archivo |

---

## Notas Técnicas Importantes

1. **Siempre regenerar `database.g.dart`** al modificar tablas: `flutter pub run build_runner build --delete-conflicting-outputs`
2. **Las migraciones son irreversibles** en SQLite. Probar en emulador antes de publicar.
3. **El perfil siempre es id=1** — no crear lógica multi-usuario hasta Fase 3.
4. **StreamBuilder es suficiente** para el MVP — no migrar a BLoC hasta que la complejidad lo justifique.
5. **fl_chart** es la librería recomendada: open source, sin licencia, bien mantenida.
