import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../database/database.dart';

class ExportacionService {
  static final _fecha = DateFormat('dd/MM/yyyy');
  static final _ahora = DateFormat('yyyyMMdd_HHmm');

  // ─── CSV ─────────────────────────────────────────────────────────────────

  static Future<void> exportarTransaccionesCSV({
    required List<Transaccion> transacciones,
    required List<Categoria> categorias,
    required List<Cuenta> cuentas,
    String? periodoLabel,
  }) async {
    final catMap = {for (final c in categorias) c.id: c.nombre};
    final cuentaMap = {for (final c in cuentas) c.id: c.nombre};

    final rows = <List<dynamic>>[
      [
        'Fecha',
        'Tipo',
        'Descripción',
        'Categoría',
        'Cuenta',
        'Forma de Pago',
        'Monto',
        'Cuotas',
        'Valor Cuota',
        'Es Préstamo',
        'Estado',
        'Notas',
      ],
      ...transacciones.map((t) => [
            _fecha.format(t.fecha),
            t.tipo,
            t.descripcion,
            catMap[t.categoriaId] ?? '',
            cuentaMap[t.cuentaId] ?? '',
            t.formaPago,
            t.montoTotal.toStringAsFixed(0),
            t.cantidadCuotas ?? '',
            t.valorCuota?.toStringAsFixed(0) ?? '',
            t.esPrestamo ? 'Sí' : 'No',
            t.estado,
            t.notas ?? '',
          ]),
    ];

    final csv = const CsvEncoder().convert(rows);
    final file = await _tempFile('transacciones_${_ahora.format(DateTime.now())}.csv');
    await file.writeAsString(csv);
    await _compartir(file, 'Exportar transacciones');
  }

  // ─── PDF Transacciones ────────────────────────────────────────────────────

  static Future<void> exportarTransaccionesPDF({
    required List<Transaccion> transacciones,
    required List<Categoria> categorias,
    List<Cuenta> cuentas = const [],
    String? periodoLabel,
  }) async {
    final catMap = {for (final c in categorias) c.id: c.nombre};

    final totalIngresos = transacciones
        .where((t) => t.tipo == 'ingreso')
        .fold<double>(0, (s, t) => s + t.montoTotal);
    final totalEgresos = transacciones
        .where((t) => t.tipo == 'egreso')
        .fold<double>(0, (s, t) => s + t.montoTotal);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          // Encabezado
          pw.Text(
            'Reporte de Transacciones',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          if (periodoLabel != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(periodoLabel, style: const pw.TextStyle(fontSize: 12)),
          ],
          pw.SizedBox(height: 4),
          pw.Text(
            'Generado: ${_fecha.format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 16),

          // Resumen
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfResumenItem('Ingresos', totalIngresos, PdfColors.green700),
                _pdfResumenItem('Egresos', totalEgresos, PdfColors.red700),
                _pdfResumenItem(
                  'Balance',
                  totalIngresos - totalEgresos,
                  totalIngresos >= totalEgresos ? PdfColors.green700 : PdfColors.red700,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Tabla
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2),
              1: const pw.FlexColumnWidth(0.8),
              2: const pw.FlexColumnWidth(2.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.2),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: ['Fecha', 'Tipo', 'Descripción', 'Categoría', 'Monto']
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: pw.Text(
                            h,
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              // Data rows
              ...transacciones.map((t) {
                final isIngreso = t.tipo == 'ingreso';
                return pw.TableRow(
                  children: [
                    _pdfCell(_fecha.format(t.fecha)),
                    _pdfCell(isIngreso ? 'Ingreso' : 'Egreso'),
                    _pdfCell(t.descripcion),
                    _pdfCell(catMap[t.categoriaId] ?? ''),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: pw.Text(
                        '${isIngreso ? '+' : '-'}\$${_formatNum(t.montoTotal)}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: isIngreso ? PdfColors.green700 : PdfColors.red700,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    final file = await _tempFile('transacciones_${_ahora.format(DateTime.now())}.pdf');
    await file.writeAsBytes(await pdf.save());
    await _compartir(file, 'Exportar transacciones');
  }

  // ─── PDF Reporte mensual ──────────────────────────────────────────────────

  static Future<void> exportarReportePDF({
    required String periodoLabel,
    required double ingresos,
    required double egresos,
    required List<Map<String, dynamic>> categorias,
    required List<Map<String, dynamic>> historico,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Text(
            'Reporte Mensual — $periodoLabel',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generado: ${_fecha.format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 16),

          // Resumen
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfResumenItem('Ingresos', ingresos, PdfColors.green700),
                _pdfResumenItem('Egresos', egresos, PdfColors.red700),
                _pdfResumenItem(
                  'Balance',
                  ingresos - egresos,
                  ingresos >= egresos ? PdfColors.green700 : PdfColors.red700,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          if (categorias.isNotEmpty) ...[
            pw.Text(
              'Gastos por Categoría',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: ['Categoría', 'Monto', '% del total']
                      .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: pw.Text(
                              h,
                              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                            ),
                          ))
                      .toList(),
                ),
                ...categorias.map((c) {
                  final total = categorias.fold<double>(0, (s, x) => s + (x['monto'] as double));
                  final pct = total > 0 ? ((c['monto'] as double) / total * 100) : 0.0;
                  return pw.TableRow(children: [
                    _pdfCell(c['nombre'] as String),
                    _pdfCell('\$${_formatNum(c['monto'] as double)}'),
                    _pdfCell('${pct.toStringAsFixed(1)}%'),
                  ]);
                }),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          if (historico.isNotEmpty) ...[
            pw.Text(
              'Evolución últimos 6 meses',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: ['Mes', 'Ingresos', 'Egresos', 'Balance']
                      .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: pw.Text(
                              h,
                              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                            ),
                          ))
                      .toList(),
                ),
                ...historico.map((m) {
                  final ing = m['ingresos'] as double;
                  final egr = m['egresos'] as double;
                  return pw.TableRow(children: [
                    _pdfCell(m['mes'] as String),
                    _pdfCell('\$${_formatNum(ing)}'),
                    _pdfCell('\$${_formatNum(egr)}'),
                    _pdfCell('${ing >= egr ? '+' : '-'}\$${_formatNum((ing - egr).abs())}'),
                  ]);
                }),
              ],
            ),
          ],
        ],
      ),
    );

    final file = await _tempFile('reporte_${_ahora.format(DateTime.now())}.pdf');
    await file.writeAsBytes(await pdf.save());
    await _compartir(file, 'Exportar reporte');
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static pw.Widget _pdfResumenItem(String label, double monto, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 4),
        pw.Text(
          '\$${_formatNum(monto.abs())}',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  static pw.Widget _pdfCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  static String _formatNum(double v) {
    final f = NumberFormat('#,##0', 'es_CL');
    return f.format(v);
  }

  static Future<File> _tempFile(String nombre) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/$nombre');
  }

  static Future<void> _compartir(File file, String subject) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: subject,
      ),
    );
  }
}
