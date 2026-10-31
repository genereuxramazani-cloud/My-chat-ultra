// widgets/business_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';

class BusinessChartView extends StatefulWidget {
  final List<DocumentSnapshot> docs;
  const BusinessChartView({super.key, required this.docs});

  @override
  State<BusinessChartView> createState() => _BusinessChartViewState();
}

class _BusinessChartViewState extends State<BusinessChartView> {
  int _chartTab = 0; // 0 = Barres, 1 = Camembert

  // ── CALCUL DES DONNÉES ──
  Map<String, double> _getMonthlySums(String type) {
    final Map<String, double> result = {};
    for (var doc in widget.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['type'] != type) continue;
      if (data['date'] is! Timestamp) continue;
      final date = (data['date'] as Timestamp).toDate();
      final key = "${date.month}/${date.year}";
      result[key] = (result[key] ?? 0) + (data['montant'] ?? 0).toDouble();
    }
    return result;
  }

  Map<String, double> _getDepenseByCategory() {
    final Map<String, double> result = {};
    for (var doc in widget.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['type'] != 'depense') continue;
      final cat = data['categorie'] ?? 'Autre';
      result[cat] = (result[cat] ?? 0) + (data['montant'] ?? 0).toDouble();
    }
    return result;
  }

  // ── LABELS DES 6 DERNIERS MOIS ──
  List<String> _last6MonthsLabels() {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final d = DateTime(now.year, now.month - (5 - i));
      return "${d.month}/${d.year}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          // Toggle Barres / Camembert
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _chartToggle("Barres", 0, Icons.bar_chart),
                const SizedBox(width: 8),
                _chartToggle("Répartition", 1, Icons.pie_chart),
              ],
            ),
          ),
          Expanded(
            child: _chartTab == 0 ? _buildBarChart() : _buildPieChart(),
          ),
          _buildLegend(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _chartToggle(String label, int idx, IconData icon) {
    final active = _chartTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _chartTab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kGold.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? kGold : kTextDim.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? kGold : kTextDim, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style:
                    TextStyle(color: active ? kGold : kTextDim, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ── GRAPHIQUE EN BARRES ──
  Widget _buildBarChart() {
    final labels = _last6MonthsLabels();
    final ventes = _getMonthlySums('vente');
    final achats = _getMonthlySums('achat');
    final depenses = _getMonthlySums('depense');

    final groups = labels.asMap().entries.map((e) {
      final i = e.key;
      final k = e.value;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
              toY: ventes[k] ?? 0,
              color: kCyan,
              width: 7,
              borderRadius: BorderRadius.circular(4)),
          BarChartRodData(
              toY: achats[k] ?? 0,
              color: Colors.orange,
              width: 7,
              borderRadius: BorderRadius.circular(4)),
          BarChartRodData(
              toY: depenses[k] ?? 0,
              color: kPink,
              width: 7,
              borderRadius: BorderRadius.circular(4)),
        ],
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: BarChart(
        BarChartData(
          barGroups: groups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: kTextDim.withOpacity(0.1), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) => Text(
                  '\$${v.toInt()}',
                  style: const TextStyle(color: kTextDim, fontSize: 9),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= labels.length) return const SizedBox();
                  final parts = labels[idx].split('/');
                  final monthNames = [
                    '',
                    'Jan',
                    'Fév',
                    'Mar',
                    'Avr',
                    'Mai',
                    'Jun',
                    'Jul',
                    'Aoû',
                    'Sep',
                    'Oct',
                    'Nov',
                    'Déc'
                  ];
                  return Text(
                    monthNames[int.parse(parts[0])],
                    style: const TextStyle(color: kTextDim, fontSize: 9),
                  );
                },
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIdx, rod, rodIdx) {
                final labels0 = ['Ventes', 'Achats', 'Dépenses'];
                return BarTooltipItem(
                  '${labels0[rodIdx]}\n\$${rod.toY.toStringAsFixed(2)}',
                  TextStyle(
                      color: rod.color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
        ),
        ),
      );
  }

  // ── GRAPHIQUE CAMEMBERT ──
  Widget _buildPieChart() {
    final data = _getDepenseByCategory();
    if (data.isEmpty) {
      return const Center(
          child: Text("Aucune dépense enregistrée",
              style: TextStyle(color: kTextDim)));
    }

    final colors = [
      kGold,
      kCyan,
      kPink,
      Colors.orange,
      Colors.purple,
      Colors.green,
      Colors.teal,
    ];

    final total = data.values.fold(0.0, (a, b) => a + b);
    final sections = data.entries.toList().asMap().entries.map((e) {
      final idx = e.key;
      final entry = e.value;
      final pct = (entry.value / total * 100);
      return PieChartSectionData(
        value: entry.value,
        color: colors[idx % colors.length],
        title: '${pct.toStringAsFixed(1)}%',
        radius: 80,
        titleStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
        pieTouchData: PieTouchData(
          touchCallback: (_, response) {
            // Optionnel : highlight au tap
          },
        ),
      ),
    );
  }

  // ── LÉGENDE ──
  Widget _buildLegend() {
    if (_chartTab == 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendDot(kCyan, "Ventes"),
          const SizedBox(width: 16),
          _legendDot(Colors.orange, "Achats"),
          const SizedBox(width: 16),
          _legendDot(kPink, "Dépenses"),
        ],
      );
    }

    final data = _getDepenseByCategory();
    final colors = [
      kGold,
      kCyan,
      kPink,
      Colors.orange,
      Colors.purple,
      Colors.green,
      Colors.teal,
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: data.entries.toList().asMap().entries.map((e) {
        return _legendDot(colors[e.key % colors.length], e.value.key);
      }).toList(),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: kTextDim, fontSize: 11)),
      ],
    );
  }
}
