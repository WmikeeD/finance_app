import 'package:flutter/material.dart';
//import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../core/database/database.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/utils/formatters.dart';
import '../cuentas/cuentas_screen.dart';
import '../transacciones/transacciones_screen.dart';
import '../categorias/categorias_screen.dart';
import '../personas/personas_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppDatabase database;
  
  const HomeScreen({super.key, required this.database});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ✅ Ya no necesitas _dateFormat aquí, usas Formatters.fecha()
  // final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Implementar notificaciones
            },
          ),
        ],
      ),
      drawer: AppDrawer(
        database: widget.database,
        currentRoute: '/home',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 24),
            _buildThreeCards(),
            const SizedBox(height: 16),
            _buildAhorroProgress(),
            const SizedBox(height: 24),
            _buildRecentTransactions(),
            const SizedBox(height: 24),
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¡Bienvenido!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gestiona tus finanzas de manera inteligente',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeCards() {
    return StreamBuilder<List<Cuenta>>(
      stream: widget.database.select(widget.database.cuentas).watch(),
      builder: (context, snapshot) {
        final cuentas = snapshot.data ?? [];
        
        final balanceDisponible = cuentas
            .where((c) => c.tipo == 'efectivo' || c.tipo == 'debito')
            .fold(0.0, (sum, c) => sum + c.saldo);

        final creditoDisponible = cuentas
            .where((c) => c.tipo == 'credito')
            .fold(0.0, (sum, c) => sum + ((c.limiteCredito ?? 0) + c.saldo));

        return StreamBuilder<double>(
          stream: _calcularFlujoDelMes(),
          builder: (context, flujoSnapshot) {
            final flujoDelMes = flujoSnapshot.data ?? 0.0;

            return Row(
              children: [
                Expanded(
                  child: _buildBalanceCard(
                    'Balance Disponible',
                    balanceDisponible,
                    'Tu dinero real',
                    Icons.account_balance_wallet,
                    Colors.green,
                    () => _navigateToCuentas(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBalanceCard(
                    'Crédito Disponible',
                    creditoDisponible,
                    'Límite disponible',
                    Icons.credit_card,
                    Colors.blue,
                    () => _navigateToCuentas(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBalanceCard(
                    'Flujo del Mes',
                    flujoDelMes,
                    'Cuotas + Gastos',
                    Icons.trending_down,
                    flujoDelMes >= 0 ? Colors.green : Colors.red,
                    () => _navigateToTransacciones(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBalanceCard(
    String title,
    double amount,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              // ✅ USA Formatters AQUÍ
              Text(
                Formatters.monedaConSimbolo(amount),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: amount < 0 ? Colors.red : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAhorroProgress() {
    return StreamBuilder<List<Cuenta>>(
      stream: widget.database
          .select(widget.database.cuentas)
          .watch()
          .map((cuentas) => cuentas.where((c) => c.tipo == 'ahorro').toList()),
      builder: (context, snapshot) {
        final cuentasAhorro = snapshot.data ?? [];
        
        if (cuentasAhorro.isEmpty) {
          return const SizedBox.shrink();
        }

        final totalAhorrado = cuentasAhorro.fold(0.0, (sum, c) => sum + c.saldo);
        final totalMeta = cuentasAhorro.fold(0.0, (sum, c) => sum + (c.meta ?? 0));

        if (totalMeta == 0) {
          return const SizedBox.shrink();
        }

        final progreso = (totalAhorrado / totalMeta).clamp(0.0, 1.0);
        final porcentaje = (progreso * 100).toStringAsFixed(1);

        return GestureDetector(
          onTap: () => _navigateToCuentas(),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.savings, color: Colors.orange, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '🎯 Ahorro',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            // ✅ USA Formatters AQUÍ
                            Text(
                              '${Formatters.monedaConSimbolo(totalAhorrado)} / ${Formatters.monedaConSimbolo(totalMeta)} ($porcentaje%)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progreso,
                      minHeight: 12,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progreso >= 1.0 ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Transacciones Recientes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showAddTransaccionDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nuevo'),
                ),
                TextButton(
                  onPressed: () => _navigateToTransacciones(),
                  child: const Text('Ver Todas →'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Transaccion>>(
          stream: (widget.database.select(widget.database.transacciones)
            ..orderBy([
              (t) => OrderingTerm(
                    expression: t.fecha,
                    mode: OrderingMode.desc,
                  )
            ]))
          .watch()
          .map((list) => list.take(5).toList()),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final transacciones = snapshot.data ?? [];

            if (transacciones.isEmpty) {
              return _buildEmptyTransactions();
            }

            return Card(
              child: Column(
                children: transacciones.map((t) => _buildTransactionTile(t)).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyTransactions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'No hay transacciones todavía',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showAddTransaccionDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Crear primera transacción'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionTile(Transaccion transaccion) {
    final isIngreso = transaccion.tipo == 'ingreso';
    final color = isIngreso ? Colors.green : Colors.red;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isIngreso ? Icons.arrow_downward : Icons.arrow_upward,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        transaccion.descripcion,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        // ✅ USA Formatters AQUÍ para la fecha
        Formatters.fecha(transaccion.fecha),
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Text(
        // ✅ USA Formatters AQUÍ para el monto
        '${isIngreso ? '+' : '-'}${Formatters.monedaConSimbolo(transaccion.montoTotal)}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Acciones Rápidas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildActionCard(
              'Gestionar Cuentas',
              Icons.account_balance_wallet,
              Colors.blue,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CuentasScreen(database: widget.database),
                  ),
                );
              },
            ),
            _buildActionCard(
              'Categorías',
              Icons.category,
              Colors.purple,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoriasScreen(database: widget.database),
                  ),
                );
              },
            ),
            _buildActionCard(
              'Personas',
              Icons.people,
              Colors.orange,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PersonasScreen(database: widget.database),
                  ),
                );
              },
            ),
            _buildActionCard(
              'Proyección',
              Icons.trending_up,  // O Icons.calendar_month
              Colors.teal,
              () {
                Navigator.pushNamed(context, '/proyeccion');
              },
            ),
          ],
        ),
      ],
    );
  }
  /*Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Acciones Rápidas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildActionCard(
              'Gestionar Cuentas',
              Icons.account_balance_wallet,
              Colors.blue,
              () => _navigateToCuentas(),
            ),
            _buildActionCard(
              'Categorías',
              Icons.category,
              Colors.purple,
              () {
                Navigator.pushNamed(context, '/categorias');
              },
            ),
            _buildActionCard(
              'Personas',
              Icons.people,
              Colors.orange,
              () {
                Navigator.pushNamed(context, '/personas');
              },
            ),
            _buildActionCard(
              'Ver Reportes',
              Icons.assessment,
              Colors.green,
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Próximamente: Reportes')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }*/

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MÉTODOS DE NAVEGACIÓN Y CÁLCULOS
  // ==========================================

  void _navigateToCuentas() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CuentasScreen(database: widget.database),
      ),
    );
  }

  void _navigateToTransacciones() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransaccionesScreen(database: widget.database),
      ),
    );
  }

  void _showAddTransaccionDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransaccionesScreen(database: widget.database),
      ),
    );
  }

  Stream<double> _calcularFlujoDelMes() {
    final now = DateTime.now();
    final inicioMes = DateTime(now.year, now.month, 1);
    final finMes = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return widget.database
        .select(widget.database.transacciones)
        .watch()
        .asyncMap((transacciones) async {
      // Filtrar transacciones del mes actual (para egresos débito)
      final transaccionesDelMes = transacciones.where((t) =>
          t.fecha.isAfter(inicioMes.subtract(const Duration(days: 1))) &&
          t.fecha.isBefore(finMes.add(const Duration(days: 1)))).toList();

      // Calcular ingresos del mes
      final ingresos = transaccionesDelMes
          .where((t) => t.tipo == 'ingreso')
          .fold(0.0, (sum, t) => sum + t.montoTotal);

      // Calcular egresos débito del mes
      final egresosDebito = transaccionesDelMes
          .where((t) => t.tipo == 'egreso' && t.formaPago == 'debito')
          .fold(0.0, (sum, t) => sum + t.montoTotal);

      // ✅ CORREGIDO: Cuotas que VENCEN este mes (no las creadas este mes)
      final cuotasDelMes = await (widget.database.select(widget.database.cuotas)
            ..where((c) => 
              c.fechaVencimiento.isBiggerOrEqualValue(inicioMes) & 
              c.fechaVencimiento.isSmallerOrEqualValue(finMes) &
              c.pagada.equals(false))) // Solo las que aún no se pagan
          .get();

      final totalCuotas = cuotasDelMes.fold(0.0, (sum, c) => sum + c.monto);

      return ingresos - egresosDebito - totalCuotas;
    });
  }
  /*Stream<double> _calcularFlujoDelMes() {
    final now = DateTime.now();
    final inicioMes = DateTime(now.year, now.month, 1);
    final finMes = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return widget.database
        .select(widget.database.transacciones)
        .watch()
        .asyncMap((transacciones) async {
      final transaccionesDelMes = transacciones.where((t) =>
          t.fecha.isAfter(inicioMes.subtract(const Duration(days: 1))) &&
          t.fecha.isBefore(finMes.add(const Duration(days: 1)))).toList();

      final ingresos = transaccionesDelMes
          .where((t) => t.tipo == 'ingreso')
          .fold(0.0, (sum, t) => sum + t.montoTotal);

      final egresosDebito = transaccionesDelMes
          .where((t) => t.tipo == 'egreso' && t.formaPago == 'debito')
          .fold(0.0, (sum, t) => sum + t.montoTotal);

      final cuotasDelMes = await (widget.database.select(widget.database.cuotas)
            ..where((c) => c.fechaVencimiento.isBetweenValues(inicioMes, finMes)))
          .get();

      final totalCuotas = cuotasDelMes.fold(0.0, (sum, c) => sum + c.monto);

      return ingresos - egresosDebito - totalCuotas;
    });
  }*/
}