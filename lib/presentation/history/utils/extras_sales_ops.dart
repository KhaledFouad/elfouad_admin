import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/core/app_strings.dart';

/// تعديل كمية عملية بيع extras مع ضبط المخزون والحسابات
Future<void> updateExtraSaleQuantity({
  required String saleId,
  required int newQty,
}) async {
  final db = FirebaseFirestore.instance;
  final saleRef = db.collection('sales').doc(saleId);

  await db.runTransaction((tx) async {
    // ===== READS =====
    final saleSnap = await tx.get(saleRef);
    if (!saleSnap.exists) throw AppStrings.extraSaleNotFound;
    final sale = saleSnap.data() as Map<String, dynamic>;
    final type = (sale['type'] ?? '').toString();
    if (type != 'extra') throw AppStrings.extraSaleWrongType;

    final extraId = (sale['extra_id'] ?? '').toString();
    if (extraId.isEmpty) throw AppStrings.extraSaleMissingId;

    final oldQty = (sale['quantity'] is num)
        ? (sale['quantity'] as num).toInt()
        : int.tryParse('${sale['quantity'] ?? 0}') ?? 0;

    double unitPrice = 0, unitCost = 0;
    unitPrice = (sale['unit_price'] is num)
        ? (sale['unit_price'] as num).toDouble()
        : double.tryParse('${sale['unit_price'] ?? 0}') ?? 0.0;

    unitCost = (sale['unit_cost'] is num)
        ? (sale['unit_cost'] as num).toDouble()
        : 0.0;
    if (unitCost <= 0) {
      final tc = (sale['total_cost'] is num)
          ? (sale['total_cost'] as num).toDouble()
          : 0.0;
      unitCost = (oldQty > 0) ? tc / oldQty : 0.0;
    }

    final delta = newQty - oldQty; // + معناها هنخصم من المخزون

    final extraRef = db.collection('extras').doc(extraId);
    final extraSnap = await tx.get(extraRef);
    if (!extraSnap.exists) throw AppStrings.extraNotFound;
    final extra = extraSnap.data() as Map<String, dynamic>;
    final curStock = (extra['stock_units'] is num)
        ? (extra['stock_units'] as num).toInt()
        : int.tryParse('${extra['stock_units'] ?? 0}') ?? 0;

    if (delta > 0 && curStock < delta) {
      throw AppStrings.insufficientStockAvailable(curStock);
    }

    // ===== WRITES =====
    tx.update(extraRef, {
      'stock_units': curStock - delta,
      'updated_at': FieldValue.serverTimestamp(),
    });

    final newTotalPrice = unitPrice * newQty;
    final newTotalCost = unitCost * newQty;
    final newProfit = newTotalPrice - newTotalCost;

    tx.update(saleRef, {
      'quantity': newQty,
      'total_price': newTotalPrice,
      'total_cost': newTotalCost,
      'profit_total': newProfit,
      'updated_at': FieldValue.serverTimestamp(),
    });
  });
}

/// حذف عملية extras مع **إرجاع** القطع للمخزون
Future<void> deleteSaleAndUndoIfExtra({required String saleId}) async {
  final db = FirebaseFirestore.instance;
  final saleRef = db.collection('sales').doc(saleId);

  await db.runTransaction((tx) async {
    final saleSnap = await tx.get(saleRef);
    if (!saleSnap.exists) return;
    final sale = saleSnap.data() as Map<String, dynamic>;
    final type = (sale['type'] ?? '').toString();
    final qty = (sale['quantity'] is num)
        ? (sale['quantity'] as num).toInt()
        : int.tryParse('${sale['quantity'] ?? 0}') ?? 0;

    if (type == 'extra' && qty > 0) {
      final extraId = (sale['extra_id'] ?? '').toString();
      if (extraId.isNotEmpty) {
        final extraRef = db.collection('extras').doc(extraId);
        final extraSnap = await tx.get(extraRef);
        if (extraSnap.exists) {
          final extra = extraSnap.data() as Map<String, dynamic>;
          final curStock = (extra['stock_units'] is num)
              ? (extra['stock_units'] as num).toInt()
              : int.tryParse('${extra['stock_units'] ?? 0}') ?? 0;
          tx.update(extraRef, {
            'stock_units': curStock + qty,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }
    }
    tx.delete(saleRef);
  });
}
