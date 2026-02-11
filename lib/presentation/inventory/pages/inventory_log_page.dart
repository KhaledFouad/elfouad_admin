import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/inventory/utils/inventory_log.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:responsive_framework/responsive_framework.dart';

class InventoryLogPage extends StatelessWidget {
  const InventoryLogPage({super.key});

  double? _numOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final raw = '${v ?? ''}'.replaceAll(',', '.').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  Map<String, dynamic> _mapOf(dynamic v) {
    if (v is Map) return v.cast<String, dynamic>();
    return const <String, dynamic>{};
  }

  String _formatNumber(num? value, {int decimals = 2}) {
    if (value == null) return '--';
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(decimals);
  }

  String _formatStock(num? value, String unit) {
    if (value == null) return '--';
    final formatted = _formatNumber(value, decimals: 0);
    final trimmedUnit = unit.trim();
    if (trimmedUnit.isEmpty) return formatted;
    return '$formatted $trimmedUnit';
  }

  bool _isFieldChanged(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
    String key,
  ) {
    final hasBefore = before.containsKey(key);
    final hasAfter = after.containsKey(key);
    if (!hasBefore && !hasAfter) return false;
    return !_valueEquals(before[key], after[key]);
  }

  bool _valueEquals(dynamic a, dynamic b) {
    final an = _numOrNull(a);
    final bn = _numOrNull(b);
    if (an != null && bn != null) {
      return (an - bn).abs() <= 0.0001;
    }

    if (a is String || b is String) {
      final sa = (a ?? '').toString().trim();
      final sb = (b ?? '').toString().trim();
      return sa == sb;
    }

    return a == b;
  }

  bool _hasTrackedChanges(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) {
    return _isFieldChanged(before, after, 'stock') ||
        _isFieldChanged(before, after, 'sell_per_kg') ||
        _isFieldChanged(before, after, 'cost_per_kg');
  }

  bool _shouldShowEntry(Map<String, dynamic> data) {
    final action = (data['action'] ?? '').toString();
    if (action != 'update') return true;
    final before = _mapOf(data['before']);
    final after = _mapOf(data['after']);
    return _hasTrackedChanges(before, after);
  }

  @override
  Widget build(BuildContext context) {
    final breakpoints = ResponsiveBreakpoints.of(context);
    final isPhone = breakpoints.smallerThan(TABLET);
    final contentMaxWidth = breakpoints.largerThan(TABLET)
        ? 1100.0
        : double.infinity;
    final horizontalPadding = isPhone ? 12.0 : 16.0;

    final stream = FirebaseFirestore.instance
        .collection(inventoryLogsCollection)
        .orderBy('changed_at', descending: true)
        .limit(120)
        .snapshots();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
            child: AppBar(
              centerTitle: true,
              title: const Text(
                AppStrings.inventoryLogTitle,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  color: Colors.white,
                ),
              ),
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5D4037), Color(0xFF795548)],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      AppStrings.loadFailedSimple(snapshot.error ?? 'unknown'),
                    ),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                final visibleDocs = docs
                    .where((doc) => _shouldShowEntry(doc.data()))
                    .toList();
                if (visibleDocs.isEmpty) {
                  return const Center(child: Text(AppStrings.noItems));
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    8,
                    horizontalPadding,
                    24,
                  ),
                  itemCount: visibleDocs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _buildLogCard(context, visibleDocs[index]),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final action = (data['action'] ?? '').toString();
    final name = (data['name'] ?? AppStrings.unnamedLabel).toString();
    final variant = (data['variant'] ?? '').toString();
    final unit = (data['unit'] ?? 'g').toString();
    final title = variant.isEmpty ? name : '$name - $variant';

    final ts = data['changed_at'] ?? data['created_at'] ?? data['updated_at'];
    final createdAt = ts is Timestamp ? ts.toDate() : null;
    final dateLabel = createdAt == null
        ? '--'
        : intl.DateFormat('yyyy/MM/dd - HH:mm').format(createdAt);

    final before = _mapOf(data['before']);
    final after = _mapOf(data['after']);

    final stockChanged = _isFieldChanged(before, after, 'stock');
    final sellChanged = _isFieldChanged(before, after, 'sell_per_kg');
    final costChanged = _isFieldChanged(before, after, 'cost_per_kg');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.brown.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                dateLabel,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _actionChip(action),
              if (stockChanged)
                _changeChip(
                  AppStrings.stockLabel,
                  _formatStock(
                    before.containsKey('stock')
                        ? _numOrNull(before['stock'])
                        : null,
                    unit,
                  ),
                  _formatStock(
                    after.containsKey('stock')
                        ? _numOrNull(after['stock'])
                        : null,
                    unit,
                  ),
                ),
              if (sellChanged)
                _changeChip(
                  AppStrings.pricePerKgLabel,
                  _formatNumber(
                    before.containsKey('sell_per_kg')
                        ? _numOrNull(before['sell_per_kg'])
                        : null,
                  ),
                  _formatNumber(
                    after.containsKey('sell_per_kg')
                        ? _numOrNull(after['sell_per_kg'])
                        : null,
                  ),
                ),
              if (costChanged)
                _changeChip(
                  AppStrings.costPerKgLabel,
                  _formatNumber(
                    before.containsKey('cost_per_kg')
                        ? _numOrNull(before['cost_per_kg'])
                        : null,
                  ),
                  _formatNumber(
                    after.containsKey('cost_per_kg')
                        ? _numOrNull(after['cost_per_kg'])
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionChip(String action) {
    String label;
    Color color;
    switch (action) {
      case 'create':
        label = AppStrings.inventoryLogCreate;
        color = Colors.green.shade600;
        break;
      case 'delete':
        label = AppStrings.inventoryLogDelete;
        color = Colors.red.shade600;
        break;
      case 'update':
      default:
        label = AppStrings.inventoryLogUpdate;
        color = Colors.blueGrey.shade600;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _changeChip(String label, String before, String after) {
    final showAfter = after != '--';
    final text = showAfter ? '$before -> $after' : before;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.brown.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
