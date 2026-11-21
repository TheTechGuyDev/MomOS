import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

/// A tiny spreadsheet: 8 columns x 12 rows with formulas
/// (=A1+B1, =SUM(A1:A5), AVERAGE, MIN, MAX, COUNT, ROUND, IF).
class SheetLabScreen extends StatefulWidget {
  const SheetLabScreen({super.key});
  @override
  State<SheetLabScreen> createState() => _SheetLabScreenState();
}

class _SheetLabScreenState extends State<SheetLabScreen> {
  static const cols = 6;
  static const rows = 12;
  final Map<String, String> _raw = {
    'A1': 'Item', 'B1': 'Price', 'C1': 'Qty', 'D1': 'Total',
    'A2': 'Diapers', 'B2': '8500', 'C2': '2', 'D2': '=B2*C2',
    'A3': 'Formula', 'B3': '12000', 'C3': '1', 'D3': '=B3*C3',
    'A4': 'Wipes', 'B4': '2500', 'C4': '3', 'D4': '=B4*C4',
    'A6': 'Grand total', 'D6': '=SUM(D2:D4)',
    'A7': 'Average price', 'D7': '=ROUND(AVERAGE(B2:B4),0)',
  };
  String _sel = 'D2';
  final _edit = TextEditingController();

  @override
  void initState() {
    super.initState();
    _edit.text = _raw[_sel] ?? '';
  }

  String _colName(int c) => String.fromCharCode(65 + c);

  void _select(String ref) {
    setState(() {
      _sel = ref;
      _edit.text = _raw[ref] ?? '';
    });
  }

  void _commit(String v) {
    setState(() {
      if (v.trim().isEmpty) {
        _raw.remove(_sel);
      } else {
        _raw[_sel] = v.trim();
      }
    });
  }

  // ---------- evaluator ----------
  dynamic _value(String ref, [Set<String>? seen]) {
    seen ??= {};
    if (seen.contains(ref)) return '#CYCLE';
    final raw = _raw[ref];
    if (raw == null || raw.isEmpty) return null;
    if (!raw.startsWith('=')) {
      return double.tryParse(raw.replaceAll(',', '')) ?? raw;
    }
    try {
      final p = _Parser(raw.substring(1).toUpperCase(), (r) => _value(r, {...seen!, ref}));
      final v = p.parse();
      return v;
    } catch (_) {
      return '#ERROR';
    }
  }

  String _display(String ref) {
    final v = _value(ref);
    if (v == null) return '';
    if (v is double) {
      if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
      return v.toStringAsFixed(2);
    }
    if (v is bool) return v ? 'TRUE' : 'FALSE';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Spreadsheet Lab')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(children: [
            Container(
              width: 52,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Text(_sel, style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _edit,
                autocorrect: false,
                onSubmitted: _commit,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: const InputDecoration(hintText: 'Value or =formula', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: () => _commit(_edit.text), icon: const Icon(Icons.check)),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Table(
                border: TableBorder.all(color: const Color(0xFFEADDE2)),
                defaultColumnWidth: const FixedColumnWidth(96),
                columnWidths: const {0: FixedColumnWidth(36)},
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFFF7EEF1)),
                    children: [
                      const SizedBox(height: 30),
                      for (var c = 0; c < cols; c++)
                        Center(child: Padding(padding: const EdgeInsets.all(6), child: Text(_colName(c), style: const TextStyle(fontWeight: FontWeight.w900)))),
                    ],
                  ),
                  for (var r = 1; r <= rows; r++)
                    TableRow(children: [
                      Container(
                        height: 36,
                        color: const Color(0xFFF7EEF1),
                        alignment: Alignment.center,
                        child: Text('$r', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                      for (var c = 0; c < cols; c++) _cell('${_colName(c)}$r'),
                    ]),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          color: Colors.white,
          child: Text(
            'Try: =SUM(D2:D4)   =AVERAGE(B2:B4)   =MAX(B2:B4)   =COUNT(B2:B10)   =IF(D2>15000,"Big","Small")   =B2*\$C\$2',
            style: t.bodySmall?.copyWith(fontFamily: 'monospace', color: AppColors.muted),
          ),
        ),
      ]),
    );
  }

  Widget _cell(String ref) {
    final sel = ref == _sel;
    final isFormula = (_raw[ref] ?? '').startsWith('=');
    final text = _display(ref);
    final isNum = double.tryParse(text) != null;
    return GestureDetector(
      onTap: () => _select(ref),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: isNum ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: sel ? AppColors.primary.withValues(alpha: 0.12) : (isFormula ? AppColors.mint.withValues(alpha: 0.08) : Colors.white),
          border: sel ? Border.all(color: AppColors.primary, width: 2) : null,
        ),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: text.startsWith('#') ? Colors.red : AppColors.ink)),
      ),
    );
  }
}

/// Small recursive-descent formula parser.
class _Parser {
  final String s;
  final dynamic Function(String ref) lookup;
  int i = 0;
  _Parser(this.s, this.lookup);

  dynamic parse() {
    final v = _compare();
    _ws();
    if (i < s.length) throw const FormatException('extra');
    return v;
  }

  void _ws() {
    while (i < s.length && s[i] == ' ') {
      i++;
    }
  }

  bool _eat(String t) {
    _ws();
    if (s.startsWith(t, i)) {
      i += t.length;
      return true;
    }
    return false;
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is bool) return v ? 1 : 0;
    final d = double.tryParse('$v');
    if (d == null) throw const FormatException('nan');
    return d;
  }

  dynamic _compare() {
    var a = _add();
    for (final op in ['>=', '<=', '<>', '>', '<', '=']) {
      if (_eat(op)) {
        final b = _add();
        switch (op) {
          case '>=':
            return _num(a) >= _num(b);
          case '<=':
            return _num(a) <= _num(b);
          case '<>':
            return '$a' != '$b';
          case '>':
            return _num(a) > _num(b);
          case '<':
            return _num(a) < _num(b);
          default:
            return a is String || b is String ? '$a' == '$b' : _num(a) == _num(b);
        }
      }
    }
    return a;
  }

  dynamic _add() {
    var v = _mul();
    while (true) {
      if (_eat('+')) {
        v = _num(v) + _num(_mul());
      } else if (_eat('-')) {
        v = _num(v) - _num(_mul());
      } else if (_eat('&')) {
        v = '${_str(v)}${_str(_mul())}';
      } else {
        return v;
      }
    }
  }

  String _str(dynamic v) => v is double && v == v.roundToDouble() ? '${v.toInt()}' : '${v ?? ''}';

  dynamic _mul() {
    var v = _unary();
    while (true) {
      if (_eat('*')) {
        v = _num(v) * _num(_unary());
      } else if (_eat('/')) {
        final d = _num(_unary());
        if (d == 0) return '#DIV/0';
        v = _num(v) / d;
      } else if (_eat('^')) {
        v = pow(_num(v), _num(_unary())).toDouble();
      } else {
        return v;
      }
    }
  }

  dynamic _unary() {
    if (_eat('-')) return -_num(_unary());
    return _atom();
  }

  dynamic _atom() {
    _ws();
    if (_eat('(')) {
      final v = _compare();
      if (!_eat(')')) throw const FormatException(')');
      return v;
    }
    if (i < s.length && s[i] == '"') {
      final end = s.indexOf('"', i + 1);
      final v = s.substring(i + 1, end);
      i = end + 1;
      return v;
    }
    final m = RegExp(r'^[0-9]+(\.[0-9]+)?').firstMatch(s.substring(i));
    if (m != null) {
      i += m.group(0)!.length;
      return double.parse(m.group(0)!);
    }
    final w = RegExp(r'^\$?([A-Z]+)\$?([0-9]*)').firstMatch(s.substring(i));
    if (w == null) throw const FormatException('token');
    final name = w.group(1)!;
    final rowPart = w.group(2)!;
    if (rowPart.isEmpty) {
      i += w.group(0)!.length;
      if (name == 'TRUE') return true;
      if (name == 'FALSE') return false;
      if (!_eat('(')) throw const FormatException('(');
      final args = <List<dynamic>>[];
      if (!_eat(')')) {
        do {
          args.add(_arg());
        } while (_eat(','));
        if (!_eat(')')) throw const FormatException(')');
      }
      return _fn(name, args);
    }
    i += w.group(0)!.length;
    final ref = '$name$rowPart';
    if (_eat(':')) {
      throw const FormatException('range outside function');
    }
    return lookup(ref);
  }

  /// Function argument: a range (expanded) or a single expression.
  List<dynamic> _arg() {
    _ws();
    final m = RegExp(r'^\$?([A-Z]+)\$?([0-9]+):\$?([A-Z]+)\$?([0-9]+)').firstMatch(s.substring(i));
    if (m != null) {
      i += m.group(0)!.length;
      final c1 = m.group(1)!.codeUnitAt(0), c2 = m.group(3)!.codeUnitAt(0);
      final r1 = int.parse(m.group(2)!), r2 = int.parse(m.group(4)!);
      return [
        for (var c = min(c1, c2); c <= max(c1, c2); c++)
          for (var r = min(r1, r2); r <= max(r1, r2); r++) lookup('${String.fromCharCode(c)}$r'),
      ];
    }
    return [_compare()];
  }

  dynamic _fn(String name, List<List<dynamic>> args) {
    final flat = args.expand((a) => a).toList();
    final nums = flat.whereType<double>().toList();
    switch (name) {
      case 'SUM':
        return nums.fold<double>(0, (a, b) => a + b);
      case 'AVERAGE':
        return nums.isEmpty ? '#DIV/0' : nums.reduce((a, b) => a + b) / nums.length;
      case 'MIN':
        return nums.isEmpty ? 0.0 : nums.reduce(min);
      case 'MAX':
        return nums.isEmpty ? 0.0 : nums.reduce(max);
      case 'COUNT':
        return nums.length.toDouble();
      case 'COUNTA':
        return flat.where((v) => v != null && '$v'.isNotEmpty).length.toDouble();
      case 'ROUND':
        final v = _num(args[0].first);
        final d = args.length > 1 ? _num(args[1].first).toInt() : 0;
        final f = pow(10, d);
        return (v * f).roundToDouble() / f;
      case 'IF':
        final cond = args[0].first;
        final truthy = cond is bool ? cond : _num(cond) != 0;
        return truthy ? (args.length > 1 ? args[1].first : true) : (args.length > 2 ? args[2].first : false);
      case 'ABS':
        return _num(args[0].first).abs();
      default:
        throw const FormatException('fn');
    }
  }
}
