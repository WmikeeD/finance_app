# Diagrama de Base de Datos - Finance App

## Esquema Relacional

```
┌─────────────────────────────────────────────────────────────────┐
│                          CUENTAS                                │
├─────────────────────────────────────────────────────────────────┤
│ id (PK)                  INTEGER                                │
│ nombre                   TEXT                                   │
│ tipo                     TEXT (credito/debito/efectivo/ahorro)  │
│ saldo                    REAL                                   │
│ limite_credito           REAL (nullable)                        │
│ dia_cierre              INTEGER (nullable)                      │
│ dia_pago                INTEGER (nullable)                      │
│ color                    TEXT                                   │
│ icono                    TEXT                                   │
│ activa                   BOOLEAN                                │
│ creada_en               DATETIME                                │
│ actualizada_en          DATETIME                                │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    │ 1
                                    │
                                    │ N
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                       TRANSACCIONES                             │
├─────────────────────────────────────────────────────────────────┤
│ id (PK)                      INTEGER                            │
│ tipo                         TEXT (ingreso/egreso)              │
│ descripcion                  TEXT                               │
│ monto_total                  REAL                               │
│ forma_pago                   TEXT (debito/credito)              │
│ es_prestamo                  BOOLEAN                            │
│ estado                       TEXT (pendiente/completado...)     │
│ fecha                        DATETIME                           │
│                                                                 │
│ cuenta_id (FK)              INTEGER → CUENTAS(id)              │
│ categoria_id (FK)           INTEGER → CATEGORIAS(id)           │
│ persona_id (FK)             INTEGER → PERSONAS(id) (nullable)  │
│                                                                 │
│ cantidad_cuotas             INTEGER (nullable)                  │
│ valor_cuota                 REAL (nullable)                     │
│ tasa_interes                REAL (nullable)                     │
│ tipo_interes                TEXT (nullable)                     │
│ monto_total_con_interes     REAL (nullable)                     │
│ interes_total               REAL (nullable)                     │
│                                                                 │
│ notas                        TEXT (nullable)                     │
│ etiquetas                    TEXT (nullable)                     │
│                                                                 │
│ sincronizado                 BOOLEAN                            │
│ sync_id                      TEXT (nullable)                    │
│ creada_en                   DATETIME                            │
│ actualizada_en              DATETIME                            │
│ ultima_modificacion         DATETIME                            │
└─────────────────────────────────────────────────────────────────┘
         │                              ▲
         │ 1                            │ N
         │                              │
         │ N                    ┌───────┴────────┐
         ▼                      │                │
┌──────────────────┐    ┌──────────────┐  ┌────────────┐
│     CUOTAS       │    │  CATEGORIAS  │  │  PERSONAS  │
├──────────────────┤    ├──────────────┤  ├────────────┤
│ id (PK)          │    │ id (PK)      │  │ id (PK)    │
│ transaccion_id   │    │ nombre       │  │ nombre     │
│ numero_cuota     │    │ tipo         │  │ telefono   │
│ monto            │    │ categoria_   │  │ email      │
│ fecha_vencimiento│    │ padre_id (FK)│  │ relacion   │
│ pagada           │    │ color        │  │ notas      │
│ fecha_pago       │    │ icono        │  │ avatar     │
│ monto_capital    │    │ orden        │  │ color      │
│ monto_interes    │    │ activa       │  │ activa     │
│ notas            │    │ creada_en    │  │ creada_en  │
│ creada_en        │    │ actualizada_ │  │ actualizada│
│ actualizada_en   │    │ en           │  │ _en        │
└──────────────────┘    └──────────────┘  └────────────┘
                               │
                               │ Self-Join
                               │
                               └─────┐
                                     │
                                     ▼
                        (Subcategorías jerárquicas)
```

## Relaciones

### 1. CUENTAS → TRANSACCIONES (1:N)
- Una cuenta puede tener muchas transacciones
- Una transacción pertenece a una cuenta
- `ON DELETE CASCADE`: Al eliminar cuenta, se eliminan sus transacciones

### 2. CATEGORIAS → TRANSACCIONES (1:N)
- Una categoría puede tener muchas transacciones
- Una transacción pertenece a una categoría
- `ON DELETE RESTRICT`: No se puede eliminar categoría con transacciones

### 3. CATEGORIAS → CATEGORIAS (Auto-referencial)
- Una categoría puede tener subcategorías
- Ejemplo: "Auto" → ["Combustible", "Mantenimiento", "TAG"]
- `ON DELETE CASCADE`: Al eliminar categoría padre, se eliminan hijas

### 4. PERSONAS → TRANSACCIONES (1:N)
- Una persona puede tener múltiples préstamos/compras
- Una transacción puede estar asociada a una persona (opcional)
- `ON DELETE RESTRICT`: No se puede eliminar persona con préstamos activos

### 5. TRANSACCIONES → CUOTAS (1:N)
- Una transacción a crédito genera múltiples cuotas
- Una cuota pertenece a una transacción
- `ON DELETE CASCADE`: Al eliminar transacción, se eliminan sus cuotas

## Índices (para optimizar queries)

```sql
-- Índice en transacciones por fecha (queries frecuentes por mes)
CREATE INDEX idx_transacciones_fecha ON transacciones(fecha DESC);

-- Índice en transacciones por cuenta
CREATE INDEX idx_transacciones_cuenta ON transacciones(cuenta_id);

-- Índice en transacciones por categoría
CREATE INDEX idx_transacciones_categoria ON transacciones(categoria_id);

-- Índice en cuotas por estado de pago
CREATE INDEX idx_cuotas_pagadas ON cuotas(pagada, fecha_vencimiento);

-- Índice compuesto para préstamos
CREATE INDEX idx_transacciones_prestamos ON transacciones(es_prestamo, estado, persona_id);
```

## Ejemplos de Datos

### Cuentas
```
id | nombre              | tipo    | saldo     | limite_credito
---|---------------------|---------|-----------|---------------
1  | Efectivo            | efectivo| 50000.00  | NULL
2  | Tarjeta Visa Gold   | credito | -120000.00| 500000.00
3  | Cuenta Corriente    | debito  | 350000.00 | NULL
```

### Categorías (Jerarquía)
```
id | nombre        | tipo   | categoria_padre_id
---|---------------|--------|-------------------
1  | Auto          | egreso | NULL
2  | Combustible   | egreso | 1
3  | Mantenimiento | egreso | 1
4  | TAG           | egreso | 1
5  | Alimentación  | egreso | NULL
6  | Supermercado  | egreso | 5
7  | Restaurantes  | egreso | 5
```

### Transacciones
```
id | descripcion          | monto_total | forma_pago | cantidad_cuotas | valor_cuota
---|----------------------|-------------|------------|-----------------|------------
1  | Compra supermercado  | 45000       | debito     | NULL            | NULL
2  | TV Samsung 55"       | 600000      | credito    | 12              | 55000
3  | Préstamo a Juan      | 100000      | debito     | NULL            | NULL
```

### Cuotas (para transacción #2 - TV)
```
id | transaccion_id | numero_cuota | monto  | fecha_vencimiento | pagada
---|----------------|--------------|--------|-------------------|-------
1  | 2              | 1            | 55000  | 2026-02-15        | true
2  | 2              | 2            | 55000  | 2026-03-15        | true
3  | 2              | 3            | 55000  | 2026-04-15        | false
4  | 2              | 4            | 55000  | 2026-05-15        | false
...
```

## Casos de Uso Cubiertos

✅ **Compra débito propia**: transaccion(tipo=egreso, forma_pago=debito, es_prestamo=false)
✅ **Compra crédito propia**: transaccion(tipo=egreso, forma_pago=credito) + N cuotas
✅ **Préstamo débito a tercero**: transaccion(es_prestamo=true, persona_id=X, forma_pago=debito)
✅ **Compra crédito para tercero**: transaccion(es_prestamo=true, persona_id=X, forma_pago=credito) + N cuotas
✅ **Ingreso**: transaccion(tipo=ingreso)
✅ **Categorías jerárquicas**: categoria.categoria_padre_id
✅ **Control de pagos**: cuota.pagada + cuota.fecha_pago
✅ **Cálculo de intereses**: campos monto_total_con_interes, interes_total
✅ **Sincronización futura**: campos sincronizado, sync_id

## Queries Comunes

### 1. Total gastado en el mes actual (solo gastos propios)
```sql
SELECT SUM(monto_total) 
FROM transacciones 
WHERE tipo = 'egreso' 
  AND es_prestamo = false 
  AND strftime('%Y-%m', fecha) = strftime('%Y-%m', 'now');
```

### 2. Préstamos pendientes de cobro
```sql
SELECT t.*, p.nombre as persona_nombre
FROM transacciones t
JOIN personas p ON t.persona_id = p.id
WHERE t.es_prestamo = true 
  AND t.estado = 'pendiente';
```

### 3. Cuotas vencidas no pagadas
```sql
SELECT c.*, t.descripcion
FROM cuotas c
JOIN transacciones t ON c.transaccion_id = t.id
WHERE c.pagada = false 
  AND c.fecha_vencimiento < date('now');
```

### 4. Gastos por categoría (con subcategorías)
```sql
WITH RECURSIVE categoria_tree AS (
  SELECT id, nombre, categoria_padre_id
  FROM categorias
  WHERE categoria_padre_id IS NULL
  
  UNION ALL
  
  SELECT c.id, c.nombre, c.categoria_padre_id
  FROM categorias c
  JOIN categoria_tree ct ON c.categoria_padre_id = ct.id
)
SELECT ct.nombre, SUM(t.monto_total) as total
FROM transacciones t
JOIN categoria_tree ct ON t.categoria_id = ct.id
WHERE t.tipo = 'egreso'
GROUP BY ct.id
ORDER BY total DESC;
```