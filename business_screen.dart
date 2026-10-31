import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../main.dart' show globalProfileService;
import '../widgets/user_avatar_widget.dart';
import 'calculator_screen.dart';

// ─────────────────────────────────────────────
//  MODÈLES & CONSTANTES
// ─────────────────────────────────────────────
enum EntryType { vente, achat, depense, inventaire, client }

const depenseCategories = [
  'Loyer',
  'Salaires',
  'Transport',
  'Fournisseur',
  'Électricité/Eau',
  'Marketing',
  'Autre',
];

class BusinessScreen extends StatefulWidget {
  final String userPhone;
  const BusinessScreen({super.key, required this.userPhone});

  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  int _tab = 0;
  final List<String> _tabs = [
    "Ventes",
    "Achats",
    "Dépenses",
    "Inventaire",
    "Clients"
  ];
  final List<IconData> _tabIcons = [
    Icons.trending_up,
    Icons.shopping_cart,
    Icons.money_off,
    Icons.inventory_2,
    Icons.people
  ];

  String _periode = 'Tout';
  final List<String> _periodes = ['Aujourd\'hui', 'Semaine', 'Mois', 'Tout'];
  String _search = '';
  final TextEditingController _searchC = TextEditingController();
  bool _showChart = false;

  // Scroll handling to hide/show the top header when user scrolls
  late final ScrollController _listController;
  double _lastScroll = 0;
  bool _headerVisible = true;

  // ── FILTRE PÉRIODE ──
  bool _inPeriod(dynamic rawDate) {
    if (_periode == 'Tout') return true;
    if (rawDate is! Timestamp) return true;
    final date = rawDate.toDate();
    final now = DateTime.now();
    if (_periode == 'Aujourd\'hui')
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    if (_periode == 'Semaine') return now.difference(date).inDays <= 7;
    if (_periode == 'Mois')
      return date.year == now.year && date.month == now.month;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _listController = ScrollController();
    _listController.addListener(() {
      final offset =
          _listController.hasClients ? _listController.position.pixels : 0.0;
      if (offset > _lastScroll + 5 && _headerVisible) {
        setState(() => _headerVisible = false);
      } else if (offset < _lastScroll - 5 && !_headerVisible) {
        setState(() => _headerVisible = true);
      }
      _lastScroll = offset;
    });
  }

  @override
  void dispose() {
    _listController.dispose();
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF050510),
        title: const Text("BUSINESS HUB",
            style: TextStyle(color: kGold, letterSpacing: 2)),
        leading: ListenableBuilder(
          listenable: globalProfileService,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: UserAvatarWidget(
              avatarUrl: globalProfileService.avatar,
              identifier: widget.userPhone,
              size: 36,
              borderColor: kGold,
              borderWidth: 1.5,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: kGold, size: 28),
            onPressed: () => _showAddSheet(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: kGold),
            onSelected: (value) {
              switch (value) {
                case 'toggle_chart':
                  setState(() => _showChart = !_showChart);
                  break;
                case 'export_csv':
                  _exportCSV();
                  break;
                case 'choose_periode':
                  _showPeriodeDialog(context);
                  break;
                case 'calculator':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CalculatorScreen(userPhone: widget.userPhone),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'toggle_chart',
                child: Text(_showChart ? 'Afficher la liste' : 'Afficher le graphique'),
              ),
              const PopupMenuItem(
                value: 'export_csv',
                child: Text('Exporter CSV'),
              ),
              PopupMenuItem(
                value: 'choose_periode',
                child: Text('Période : $_periode'),
              ),
              const PopupMenuItem(
                value: 'calculator',
                child: Text('Calculatrice'),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: kGradientBg),
        child: Stack(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('business')
                  .where('owner', isEqualTo: widget.userPhone)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(
                      child: CircularProgressIndicator(color: kGold));

                final allDocs = snapshot.data!.docs;
                double v = 0, a = 0, d = 0;

                for (var doc in allDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (!_inPeriod(data['date'])) continue;
                  double m = (data['montant'] ?? 0).toDouble();
                  if (data['type'] == 'vente') v += m;
                  if (data['type'] == 'achat') a += m;
                  if (data['type'] == 'depense') d += m;
                }

                return Column(
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: _headerVisible
                          ? Column(children: [
                              _buildSummaryHeader(v, a, d),
                              if (!_showChart) _buildSearchBar()
                            ])
                          : const SizedBox.shrink(),
                    ),
                    if (_showChart)
                      _buildChart(v, a, d)
                    else ...[
                      _buildTabsScroll(),
                      Expanded(child: _buildMainList(allDocs)),
                    ],
                  ],
                );
              },
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _headerVisible ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: _headerVisible,
                  child: FloatingActionButton(
                    backgroundColor: kGold,
                    mini: true,
                    onPressed: () =>
                        setState(() => _headerVisible = !_headerVisible),
                    child: Icon(
                        _headerVisible
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        color: Colors.black),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER STATISTIQUES ──
  Widget _buildSummaryHeader(double v, double a, double d) {
    double profit = v - a - d;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _statCard("VENTES", v, kCyan, Icons.trending_up),
          const SizedBox(width: 8),
          _statCard("SORTIES", a + d, kPink, Icons.trending_down),
          const SizedBox(width: 8),
          _statCard("PROFIT", profit, profit >= 0 ? kGold : Colors.redAccent,
              Icons.monetization_on),
        ],
      ),
    );
  }

  Widget _statCard(String label, double amount, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            FittedBox(
                child: Text("\$${amount.toStringAsFixed(2)}",
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14))),
            Text(label, style: const TextStyle(color: kTextDim, fontSize: 8)),
          ],
        ),
      ),
    );
  }

  // ── BARRE DE RECHERCHE ──
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: _searchC,
        onChanged: (v) => setState(() => _search = v.toLowerCase()),
        style: const TextStyle(color: kText),
        decoration: InputDecoration(
          hintText: "Rechercher...",
          hintStyle: const TextStyle(color: kTextDim),
          prefixIcon: const Icon(Icons.search, color: kTextDim),
          filled: true,
          fillColor: kCard,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }

  // ── ONGLETS ──
  Widget _buildTabsScroll() {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _tabs.length,
        itemBuilder: (c, i) => GestureDetector(
          onTap: () => setState(() => _tab = i),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _tab == i ? kGold.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _tab == i ? kGold : kTextDim.withOpacity(0.2)),
            ),
            child: Center(
                child: Text(_tabs[i],
                    style: TextStyle(
                        color: _tab == i ? kGold : kTextDim, fontSize: 12))),
          ),
        ),
      ),
    );
  }

  // ── LISTE DE CONTENU ──
  Widget _buildMainList(List<DocumentSnapshot> docs) {
    final typeMap = ['vente', 'achat', 'depense', 'inventaire', 'client'];
    final filtered = docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return data['type'] == typeMap[_tab] &&
          (_search.isEmpty ||
              data['description'].toString().toLowerCase().contains(_search));
    }).toList();

    if (filtered.isEmpty)
      return const Center(
          child:
              Text("Aucune donnée trouvée", style: TextStyle(color: kTextDim)));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      controller: _listController,
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: filtered.length,
      itemBuilder: (c, i) {
        final doc = filtered[i];
        final data = doc.data() as Map<String, dynamic>;
        return Card(
          color: kCard,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(_tabIcons[_tab], color: kGold, size: 20),
            title: Text(data['description'] ?? '',
                style: const TextStyle(color: kText)),
            subtitle: Text(
                data['date'] is Timestamp
                    ? "${data['date'].toDate().day}/${data['date'].toDate().month}"
                    : "",
                style: const TextStyle(color: kTextDim, fontSize: 10)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("\$${data['montant']}",
                    style: const TextStyle(
                        color: kGold, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: kTextDim, size: 20),
                  onSelected: (value) {
                    if (value == 'edit') _showEditSheet(context, doc);
                    if (value == 'delete') _deleteEntry(doc);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── GRAPHIQUE SIMPLE ──
  Widget _buildChart(double v, double a, double d) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics, color: kGold, size: 50),
            const SizedBox(height: 20),
            Text("Ventes: \$${v.toStringAsFixed(2)}",
                style: const TextStyle(color: kCyan)),
            Text("Achats: \$${a.toStringAsFixed(2)}",
                style: const TextStyle(color: Colors.orange)),
            Text("Frais: \$${d.toStringAsFixed(2)}",
                style: const TextStyle(color: kPink)),
          ],
        ),
      ),
    );
  }

  // ── AJOUT DE DONNÉES ──
  void _showAddSheet(BuildContext context) {
    final descC = TextEditingController();
    final mntC = TextEditingController();
    final qtyC = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCard,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Ajouter ${_tabs[_tab]}",
                style: const TextStyle(
                    color: kGold, fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(
                controller: descC,
                decoration: const InputDecoration(labelText: "Description"),
                style: const TextStyle(color: kText)),
            TextField(
                controller: mntC,
                decoration:
                    const InputDecoration(labelText: "Montant Total \$"),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: kText)),
            if (_tab == 1)
              TextField(
                  controller: qtyC,
                  decoration: const InputDecoration(labelText: "Quantité"),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: kText)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kGold),
              onPressed: () async {
                final typeMap = [
                  'vente',
                  'achat',
                  'depense',
                  'inventaire',
                  'client'
                ];
                final m = double.tryParse(mntC.text) ?? 0;
                final q = int.tryParse(qtyC.text) ?? 0;

                await FirebaseFirestore.instance.collection('business').add({
                  'owner': widget.userPhone,
                  'type': typeMap[_tab],
                  'description': descC.text,
                  'montant': m,
                  'qty': q,
                  'date': Timestamp.now(),
                });

                if (_tab == 1)
                  await _updateStock(descC.text, q, m / (q == 0 ? 1 : q));
                FocusScope.of(context).unfocus();
                await Future.delayed(const Duration(milliseconds: 120));
                Navigator.of(context).pop();
              },
              child: const Text("VALIDER",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final descC =
        TextEditingController(text: data['description']?.toString() ?? '');
    final mntC =
        TextEditingController(text: data['montant']?.toString() ?? '0');
    final qtyC = TextEditingController(text: data['qty']?.toString() ?? '0');
    final type = data['type']?.toString() ?? '';
    final title = type.isNotEmpty
        ? 'Modifier ${type[0].toUpperCase()}${type.substring(1)}'
        : 'Modifier entrée';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCard,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: const TextStyle(
                    color: kGold, fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(
                controller: descC,
                decoration: const InputDecoration(labelText: "Description"),
                style: const TextStyle(color: kText)),
            TextField(
                controller: mntC,
                decoration:
                    const InputDecoration(labelText: "Montant Total \$"),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: kText)),
            if (type == 'achat' || type == 'inventaire')
              TextField(
                  controller: qtyC,
                  decoration: const InputDecoration(labelText: "Quantité"),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: kText)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kGold),
              onPressed: () async {
                final m = double.tryParse(mntC.text) ?? 0;
                final q = int.tryParse(qtyC.text) ?? 0;

                await doc.reference.update(
                    {'description': descC.text, 'montant': m, 'qty': q});

                if (type == 'achat' && q > 0) {
                  await _updateStock(descC.text, q, m / q);
                }

                FocusScope.of(context).unfocus();
                await Future.delayed(const Duration(milliseconds: 120));
                Navigator.of(context).pop();
              },
              child: const Text("ENREGISTRER",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showPeriodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('Choisir la période', style: TextStyle(color: kGold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _periodes.map((p) {
            return RadioListTile<String>(
              activeColor: kGold,
              title: Text(p, style: const TextStyle(color: kText)),
              value: p,
              groupValue: _periode,
              onChanged: (value) { 
                if (value != null) {
                  setState(() => _periode = value);
                  Navigator.of(ctx).pop();
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('FERMER', style: TextStyle(color: kGold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEntry(DocumentSnapshot doc) async {
    await doc.reference.delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Entrée supprimée'), duration: Duration(seconds: 2)));
  }

  Future<void> _updateStock(String name, int q, double p) async {
    final ref = FirebaseFirestore.instance.collection('business');
    final snap = await ref
        .where('owner', isEqualTo: widget.userPhone)
        .where('type', isEqualTo: 'inventaire')
        .where('description', isEqualTo: name)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference
          .update({'qty': (snap.docs.first['qty'] ?? 0) + q, 'prixAchat': p});
    } else {
      await ref.add({
        'owner': widget.userPhone,
        'type': 'inventaire',
        'description': name,
        'qty': q,
        'prixAchat': p,
        'date': Timestamp.now()
      });
    }
  }

  void _exportCSV() async {/* Logique Export */}
}
