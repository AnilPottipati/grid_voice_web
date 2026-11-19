import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/chat_item.dart';

String _inr(Object? n) {
  final v = n is num ? n : num.tryParse('$n') ?? 0;
  final negative = v < 0;
  final fixed = v.abs().toStringAsFixed(v.abs() % 1 == 0 ? 0 : 2);
  final parts = fixed.split('.');
  var whole = parts[0];
  // Indian grouping: last three digits, then pairs.
  if (whole.length > 3) {
    final tail = whole.substring(whole.length - 3);
    var head = whole.substring(0, whole.length - 3);
    final groups = <String>[];
    while (head.length > 2) {
      groups.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) groups.insert(0, head);
    whole = '${groups.join(',')},$tail';
  }
  return '${negative ? '-' : ''}₹$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
}

String _str(Object? v) => v == null ? '' : '$v';

List<Map<String, dynamic>> _rows(Object? v) => [
  for (final r in (v as List? ?? const []))
    if (r is Map<String, dynamic>) r,
];

/// Draws one card the server sent (target, orders, schemes…).
class CardView extends StatelessWidget {
  const CardView({required this.item, super.key});

  final CardItem item;

  @override
  Widget build(BuildContext context) {
    final c = item.data;
    final body = _body(c);
    if (body == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GridColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GridColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _str(c['title']).toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 0.9,
              color: GridColors.soft,
            ),
          ),
          const SizedBox(height: 10),
          ...body,
        ],
      ),
    );
  }

  List<Widget>? _body(Map<String, dynamic> c) {
    switch (c['kind']) {
      case 'target':
        return _target(c);
      case 'orders':
        return [
          for (final o in _rows(c['rows']))
            _line(
              _str(o['date']),
              '${_str(o['id'])} · ${_str(o['items'])} ${o['items'] == 1 ? 'item' : 'items'}',
              _inr(o['total']),
            ),
        ];
      case 'month':
        return _month(c);
      case 'items' || 'draft':
        return [
          for (final i in _rows(c['rows']))
            _line(
              _str(i['name']),
              '${_str(i['qty'])} × ${_inr(i['each'])}',
              _inr(i['total']),
            ),
          _line('Total', null, _inr(c['total']), bold: true),
          if (c['kind'] == 'draft')
            _chip('Not placed yet: say yes to confirm', warn: true),
        ];
      case 'schemes':
        return [
          for (final s in _rows(c['rows']))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _str(s['name']),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  _chip('Valid ${_str(s['valid'])}'),
                  for (final sl in _rows(s['slabs']))
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 70,
                            child: Text(
                              _str(sl['units'] ?? sl['tier']),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _str(sl['benefit']),
                              style: const TextStyle(
                                fontSize: 13,
                                color: GridColors.soft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ];
      case 'people':
        return [
          for (final p in _rows(c['rows']))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: GridColors.accent,
                    child: Text(
                      _initials(_str(p['name'])),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _str(p['name']),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _str(p['role']),
                          style: const TextStyle(
                            fontSize: 12,
                            color: GridColors.soft,
                          ),
                        ),
                        Wrap(
                          children: [
                            for (final t in (p['tags'] as List? ?? const []))
                              _chip('$t'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ];
      case 'products':
        return [
          for (final p in _rows(c['rows']))
            _line(_str(p['name']), _str(p['brand']), _inr(p['price'])),
        ];
      case 'price':
        return [_big(_inr(c['price']), _str(c['source']))];
      case 'done':
        return [_big('Done', ''), _chip(_str(c['note']), warn: true)];
      case 'table':
        return [_table(c)];
    }
    return null;
  }

  List<Widget> _target(Map<String, dynamic> c) {
    final pct = c['pct'];
    final shown = pct == null ? _inr(c['achieved']) : '$pct%';
    final fill = pct is num ? (pct / 100).clamp(0.0, 1.0).toDouble() : 0.0;
    final gap = c['gap'] is num ? c['gap'] as num : 0;
    return [
      _big(shown, 'of target'),
      const SizedBox(height: 8),
      _bar(fill),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _pair('Achieved', _inr(c['achieved'])),
          _pair('Target', _inr(c['target'])),
          _pair(gap > 0 ? 'Still to go' : 'Ahead by', _inr(gap.abs())),
        ],
      ),
    ];
  }

  List<Widget> _month(Map<String, dynamic> c) {
    final top = _rows(c['top']);
    final max = top.fold<double>(
      1,
      (a, t) => (t['value'] is num && (t['value'] as num) > a)
          ? (t['value'] as num).toDouble()
          : a,
    );
    final orders = c['orders'];
    return [
      _big(_inr(c['total']), '$orders ${orders == 1 ? 'order' : 'orders'}'),
      const SizedBox(height: 8),
      for (final t in top)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(_str(t['name']))),
                  Text(_inr(t['value'])),
                ],
              ),
              const SizedBox(height: 4),
              _bar(((t['value'] as num? ?? 0) / max).toDouble()),
            ],
          ),
        ),
    ];
  }

  Widget _table(Map<String, dynamic> c) {
    final columns = [for (final x in (c['columns'] as List? ?? const [])) '$x'];
    final rows = [
      for (final r in (c['rows'] as List? ?? const []))
        if (r is List) r,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        horizontalMargin: 0,
        headingRowHeight: 28,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 36,
        columns: [
          for (final x in columns)
            DataColumn(
              label: Text(
                x.toUpperCase(),
                style: const TextStyle(fontSize: 11, color: GridColors.soft),
              ),
            ),
        ],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                for (final v in r)
                  DataCell(
                    Text(
                      v is num ? _inr(v).replaceFirst('₹', '') : '$v',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static String _initials(String name) => name
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0])
      .join()
      .toUpperCase();

  static Widget _big(String value, String small) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
      ),
      if (small.isNotEmpty) ...[
        const SizedBox(width: 6),
        Text(
          small,
          style: const TextStyle(fontSize: 13, color: GridColors.soft),
        ),
      ],
    ],
  );

  static Widget _bar(double fraction) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: SizedBox(
      height: 10,
      child: Stack(
        children: [
          const ColoredBox(color: GridColors.line, child: SizedBox.expand()),
          FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [GridColors.accent, GridColors.accent2],
                ),
              ),
              child: SizedBox.expand(),
            ),
          ),
        ],
      ),
    ),
  );

  static Widget _pair(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 13, color: GridColors.soft)),
      Text(value, style: const TextStyle(fontSize: 15)),
    ],
  );

  static Widget _line(
    String name,
    String? sub,
    String right, {
    bool bold = false,
  }) => Container(
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: GridColors.line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              if (sub != null && sub.isNotEmpty)
                Text(
                  sub,
                  style: const TextStyle(fontSize: 12, color: GridColors.soft),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          right,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    ),
  );

  static Widget _chip(String text, {bool warn = false}) {
    final color = warn ? GridColors.warn : GridColors.accent2;
    return Container(
      margin: const EdgeInsets.only(top: 4, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}
