import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../widgets/ui.dart';

import 'learn_service.dart';

class SqlLabScreen extends StatefulWidget {
  const SqlLabScreen({super.key});
  @override
  State<SqlLabScreen> createState() => _SqlLabScreenState();
}

class _SqlLabScreenState extends State<SqlLabScreen> {
  final _q = TextEditingController(text: 'SELECT * FROM customers;');
  List<Map<String, dynamic>>? _rows;
  String? _error;
  bool _running = false;

  static const _examples = [
    ('All products', 'SELECT * FROM products;'),
    ('Lagos customers', "SELECT name, joined_on FROM customers\nWHERE city = 'Lagos';"),
    ('Top 3 prices', 'SELECT name, price FROM products\nORDER BY price DESC\nLIMIT 3;'),
    ('Customers per city', 'SELECT city, COUNT(*) AS customers\nFROM customers\nGROUP BY city\nORDER BY customers DESC;'),
    ('Revenue by city',
        'SELECT c.city, SUM(o.qty * p.price) AS revenue\nFROM orders o\nJOIN customers c ON c.id = o.customer_id\nJOIN products p ON p.id = o.product_id\nGROUP BY c.city\nORDER BY revenue DESC;'),
    ('Best sellers',
        'SELECT p.name, SUM(o.qty) AS units\nFROM orders o JOIN products p ON p.id = o.product_id\nGROUP BY p.name\nORDER BY units DESC;'),
  ];

  Future<void> _run() async {
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final r = await LearnService.runSql(_q.text);
      setState(() => _rows = r);
    } on PostgrestException catch (e) {
      setState(() {
        _rows = null;
        _error = e.message;
      });
    } catch (_) {
      setState(() => _error = 'Could not run the query. Check your connection.');
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rows = _rows;
    final cols = rows == null || rows.isEmpty ? <String>[] : rows.first.keys.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('SQL Lab')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text('Practice tables: customers, products, orders', style: t.bodySmall?.copyWith(color: AppColors.muted)),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _examples
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(label: Text(e.$1), onPressed: () => setState(() => _q.text = e.$2)),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: const Color(0xFF2D2640), borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(4),
            child: TextField(
              controller: _q,
              minLines: 5,
              maxLines: 12,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFF8E6EE), fontSize: 14),
              decoration: const InputDecoration(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _running ? null : _run,
            icon: _running
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.play_arrow),
            label: const Text('Run query'),
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(14)),
              child: Text('⚠️ $_error', style: TextStyle(color: Colors.red.shade700)),
            ),
          if (rows != null && rows.isEmpty) Text('No rows returned.', style: t.bodyMedium?.copyWith(color: AppColors.muted)),
          if (rows != null && rows.isNotEmpty) ...[
            Text('${rows.length} row${rows.length == 1 ? '' : 's'}${rows.length == 200 ? ' (first 200)' : ''}',
                style: t.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            WhiteCard(
              padding: EdgeInsets.zero,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 40,
                  dataRowMinHeight: 36,
                  dataRowMaxHeight: 44,
                  columns: cols.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontWeight: FontWeight.w900)))).toList(),
                  rows: rows
                      .map((r) => DataRow(cells: cols.map((c) => DataCell(Text('${r[c] ?? 'NULL'}'))).toList()))
                      .toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
