part of '../sale_edit_sheet.dart';

/// Stock delta derivation helpers used by save actions.
extension _SaleEditSheetStockHelpers on _SaleEditSheetState {
  Map<DocumentReference<Map<String, dynamic>>, double> _opsFromSale(
    Map<String, dynamic> m, {
    Map<String, dynamic>? usageSource,
  }) {
    final db = FirebaseFirestore.instance;
    final out = <DocumentReference<Map<String, dynamic>>, double>{};

    double d(v) =>
        (v is num) ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0.0;

    void acc(String? coll, dynamic id, double grams) {
      final normalized = _normalizeColl(coll);
      if (normalized == null || id == null || grams <= 0) return;
      final ref = db.collection(normalized).doc(id.toString());
      out[ref] = (out[ref] ?? 0) + grams;
    }

    Map<String, dynamic>? asMap(dynamic v) {
      if (v is Map) {
        return v.cast<String, dynamic>();
      }
      return null;
    }

    List<Map<String, dynamic>> asList(dynamic v) {
      if (v is List) {
        return v
            .map(
              (e) =>
                  (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
            )
            .toList();
      }
      return const [];
    }

    List<Map<String, dynamic>> lineItems(Map<String, dynamic> data) {
      return [
        ...asList(data['components']),
        ...asList(data['items']),
        ...asList(data['lines']),
        ...asList(data['cart_items']),
        ...asList(data['order_items']),
        ...asList(data['products']),
      ];
    }

    String? collFromRow(Map<String, dynamic> row) {
      final raw =
          row['coll'] ?? row['collection'] ?? row['coll_name'] ?? row['coll'];
      final normalized = _normalizeColl(raw?.toString());
      if (normalized != null) return normalized;

      if (row['blend_id'] != null || row['blendId'] != null) return 'blends';
      if (row['single_id'] != null || row['singleId'] != null) {
        return 'singles';
      }

      final type = (row['type'] ?? row['line_type'] ?? row['item_type'] ?? '')
          .toString();
      if (type == 'single') return 'singles';
      if (type == 'ready_blend' || type == 'blend') return 'blends';

      return null;
    }

    dynamic idFromRow(Map<String, dynamic> row) {
      return row['product_id'] ??
          row['productId'] ??
          row['single_id'] ??
          row['singleId'] ??
          row['blend_id'] ??
          row['blendId'] ??
          row['item_id'] ??
          row['itemId'] ??
          row['id'];
    }

    double gramsFromRow(Map<String, dynamic> row) {
      return d(
        row['grams'] ??
            row['weight'] ??
            row['grams_used'] ??
            row['used_grams'] ??
            row['usedGrams'],
      );
    }

    final rawType = (m['type'] ?? '').toString();
    final linesType = (m['lines_type'] ?? '').toString();
    final type = rawType.isNotEmpty
        ? rawType
        : (linesType.isNotEmpty ? linesType : detectSaleType(m)).toString();
    if (type == 'single' || type == 'ready_blend') {
      final coll = (type == 'single') ? 'singles' : 'blends';
      final id =
          m['product_id'] ??
          m['productId'] ??
          m['single_id'] ??
          m['blend_id'] ??
          m['item_id'] ??
          m['id'];
      final grams = d(m['grams']);
      acc(coll, id, grams);
    }

    if (out.isEmpty) {
      final rows = lineItems(m);
      for (final row in rows) {
        final grams = gramsFromRow(row);
        if (grams <= 0) continue;
        final coll = collFromRow(row);
        final id = idFromRow(row);
        acc(coll, id, grams);
      }
    }

    if (out.isEmpty && _isDrinkSale(m)) {
      final qtyRaw = m['quantity'] ?? m['qty'] ?? m['count'] ?? m['pieces'];
      var qty = d(qtyRaw);
      if (qty <= 0) qty = 1;

      final variant = (m['variant'] ?? m['drink_variant'] ?? m['size'] ?? '')
          .toString()
          .trim();
      final roast = (m['roast'] ?? m['roast_level'] ?? m['roastLevel'] ?? '')
          .toString()
          .trim();
      final variantKey = variant.toLowerCase();
      final roastKey = roast.toLowerCase();

      double amountFromVariant(Map<String, dynamic> byVariant) {
        if (variantKey.isEmpty) return 0.0;
        if (byVariant.containsKey(variant)) {
          return d(byVariant[variant]);
        }
        for (final entry in byVariant.entries) {
          if (entry.key.toString().trim().toLowerCase() == variantKey) {
            return d(entry.value);
          }
        }
        return 0.0;
      }

      Map<String, dynamic>? pickUsage(Map<String, dynamic> source) {
        final roastUsage = asList(
          source['roastUsage'] ?? source['roast_usage'],
        );
        if (roastUsage.isNotEmpty) {
          if (roastKey.isNotEmpty) {
            for (final entry in roastUsage) {
              final key = (entry['roast'] ?? entry['name'])
                  ?.toString()
                  .toLowerCase();
              if (key != null && key.trim() == roastKey) return entry;
            }
          }
          return roastUsage.first;
        }
        final usedItem = asMap(
          source['usedItem'] ??
              source['used_item'] ??
              source['ingredient'] ??
              source['item'],
        );
        return usedItem != null ? source : null;
      }

      void applyUsage(Map<String, dynamic> source) {
        if (out.isNotEmpty) return;
        final usage = pickUsage(source);
        if (usage == null) return;
        final item = asMap(
          usage['usedItem'] ??
              usage['used_item'] ??
              usage['ingredient'] ??
              usage['item'],
        );
        if (item == null) return;

        final rawColl =
            item['collection'] ?? item['coll'] ?? usage['collection'];
        final coll = _normalizeColl(rawColl?.toString());
        final id =
            item['id'] ??
            item['item_id'] ??
            item['itemId'] ??
            item['single_id'] ??
            item['blend_id'];
        if (coll == null || id == null) return;

        final byVariant = asMap(
          usage['usedAmountByVariant'] ??
              usage['used_amount_by_variant'] ??
              usage['usedAmounts'] ??
              usage['used_amounts'],
        );
        var amount = byVariant != null ? amountFromVariant(byVariant) : 0.0;
        if (amount <= 0) {
          amount = d(
            usage['usedAmount'] ??
                usage['used_amount'] ??
                usage['used_grams'] ??
                usage['grams_per_cup'] ??
                usage['gramsPerCup'],
          );
        }
        if (amount <= 0) return;
        acc(coll, id, amount * qty);
      }

      if (usageSource != null) {
        applyUsage(usageSource);
      } else {
        applyUsage(m);
      }
      if (out.isEmpty) {
        final meta = asMap(m['meta']);
        if (meta != null && meta != usageSource) {
          applyUsage(meta);
        }
      }
    }

    return out;
  }
}
