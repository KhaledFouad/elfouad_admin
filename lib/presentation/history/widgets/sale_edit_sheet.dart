import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/sales_history_utils.dart';
import '../utils/sales_history_utils.dart' show fetchSpiceRatesForSale;

class SaleEditSheet extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> snap;
  const SaleEditSheet({super.key, required this.snap});

  @override
  State<SaleEditSheet> createState() => _SaleEditSheetState();
}

class _SaleEditSheetState extends State<SaleEditSheet> {
  late Map<String, dynamic> _m;
  late String _type;

  final TextEditingController _totalPriceCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _gramsCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController(); // ملاحظة
  bool _isComplimentary = false;
  bool _isSpiced = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _m = widget.snap.data() ?? {};
    _type = (_m['type'] ?? 'unknown').toString();

    _totalPriceCtrl.text = numD(_m['total_price']).toStringAsFixed(2);
    _noteCtrl.text = ((_m['note'] ?? _m['notes'] ?? '') as Object).toString();

    if (_type == 'drink') {
      final qRaw = _m['quantity'];
      final q = (qRaw is num) ? qRaw.toDouble() : double.tryParse('$qRaw') ?? 1;
      _qtyCtrl.text = q.toStringAsFixed(q == q.roundToDouble() ? 0 : 2);
    } else {
      final g = numD(_m['grams']);
      if (g > 0) _gramsCtrl.text = g.toStringAsFixed(0);
    }

    _isComplimentary = (_m['is_complimentary'] ?? false) == true;
    _isSpiced = (_m['is_spiced'] ?? false) == true;
  }

  @override
  void dispose() {
    _totalPriceCtrl.dispose();
    _qtyCtrl.dispose();
    _gramsCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ======= استخراج عمليات الخصم من المخزون من عملية البيع =======
  Map<DocumentReference<Map<String, dynamic>>, double> _opsFromSale(
    Map<String, dynamic> m,
  ) {
    final db = FirebaseFirestore.instance;
    final out = <DocumentReference<Map<String, dynamic>>, double>{};

    double _d(v) =>
        (v is num) ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0.0;

    void _acc(String? coll, dynamic id, double grams) {
      if (coll == null || id == null || grams <= 0) return;
      final ref = db.collection(coll).doc(id.toString());
      out[ref] = (out[ref] ?? 0) + grams;
    }

    final type = '${m['type'] ?? ''}';

    if (type == 'single' || type == 'ready_blend') {
      final coll = (type == 'single') ? 'singles' : 'blends';
      final id = m['single_id'] ?? m['blend_id'] ?? m['item_id'] ?? m['id'];
      final grams = _d(m['grams']);
      _acc(coll, id, grams);
      return out;
    }

    if (type == 'custom_blend') {
      List<Map<String, dynamic>> _asList(dynamic v) {
        if (v is List) {
          return v
              .map(
                (e) => (e is Map)
                    ? e.cast<String, dynamic>()
                    : <String, dynamic>{},
              )
              .toList();
        }
        return const [];
      }

      final rows = [
        ..._asList(m['components']),
        ..._asList(m['items']),
        ..._asList(m['lines']),
      ];

      for (final r in rows) {
        final grams = _d(r['grams']);
        String? coll = (r['coll'] ?? r['collection'])?.toString();
        dynamic id = r['id'] ?? r['item_id'] ?? r['single_id'] ?? r['blend_id'];

        coll ??= (r['blend_id'] != null)
            ? 'blends'
            : (r['single_id'] != null)
            ? 'singles'
            : null;

        _acc(coll, id, grams);
      }
      return out;
    }

    // drinks/unknown → لا تأثير على المخزون
    return out;
  }

  /// ترانزاكشن: عدّل المخزون بالفرق + اكتب التعديلات مرة واحدة
  Future<void> _applyStockDeltaAndUpdate(Map<String, dynamic> updates) async {
    final saleRef = widget.snap.reference;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final oldSnap = await tx.get(saleRef);
      final oldSale = oldSnap.data() ?? <String, dynamic>{};

      final newSale = {...oldSale, ...updates};

      final oldOps = _opsFromSale(oldSale);
      final newOps = _opsFromSale(newSale);

      final refs = {...oldOps.keys, ...newOps.keys};
      for (final r in refs) {
        final oldG = oldOps[r] ?? 0.0;
        final newG = newOps[r] ?? 0.0;
        final diff = newG - oldG;
        if (diff.abs() > 0.0001) {
          tx.update(r, {'stock': FieldValue.increment(-diff)});
        }
      }

      tx.update(saleRef, updates);
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final updates = <String, dynamic>{};

      String type = _type; // drink | single | ready_blend | custom_blend
      bool isCompl = _isComplimentary;
      bool isSpiced = _isSpiced;

      double numOf(dynamic v) =>
          (v is num) ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0.0;

      final oldTotalPrice = numOf(_m['total_price']);
      final oldTotalCost = numOf(_m['total_cost']);

      final listPrice = numOf(_m['list_price']);
      final unitPrice = numOf(_m['unit_price']);
      final unitCost = numOf(_m['unit_cost']) > 0
          ? numOf(_m['unit_cost'])
          : numOf(_m['list_cost']);

      final pricePerKg = numOf(_m['price_per_kg']);
      final costPerKg = numOf(_m['cost_per_kg']);
      final pricePerG = pricePerKg > 0
          ? pricePerKg / 1000.0
          : numOf(_m['price_per_g']);
      final costPerG = costPerKg > 0
          ? costPerKg / 1000.0
          : numOf(_m['cost_per_g']);

      final linesAmount = numOf(_m['lines_amount']);
      final totalGramsSaved = numOf(_m['total_grams']);

      final uiTotalPrice =
          double.tryParse(_totalPriceCtrl.text.replaceAll(',', '.')) ??
          oldTotalPrice;
      double qty =
          double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ??
          numOf(_m['quantity']);
      double grams =
          double.tryParse(_gramsCtrl.text.replaceAll(',', '.')) ??
          numOf(_m['grams']);

      // هل أجل غير مدفوع؟
      final bool isDeferred = (_m['is_deferred'] ?? false) == true;
      final bool paid = (_m['paid'] ?? (!isDeferred)) == true;
      bool freezeProfit = isDeferred && !paid;

      // دايمًا خزّن الملاحظة و أعلام الحالة
      updates['note'] = _noteCtrl.text.trim();
      updates['is_complimentary'] = isCompl;
      updates['is_spiced'] = isSpiced;

      // لو ضيافة → نجبر الربح على صفر حتى لو العملية أجل غير مدفوع
      if (isCompl) freezeProfit = false;

      final bool manualOverride =
          !isCompl && (uiTotalPrice - oldTotalPrice).abs() > 0.0005;

      double newTotalPrice = oldTotalPrice;
      double newTotalCost = oldTotalCost;

      if (type == 'drink') {
        qty = qty <= 0 ? 1 : qty;
        updates['quantity'] = qty;

        if (isCompl) {
          // ضيافة: مبيعات=0، ربح=0، تكلفة الخامات فقط
          newTotalPrice = 0.0;
          newTotalCost = unitCost * qty;
          updates['unit_price'] = 0.0;
          updates['unit_cost'] = unitCost;

          updates['total_price'] = newTotalPrice;
          updates['total_cost'] = newTotalCost;
          updates['profit_total'] = 0.0; // إجبار الربح صفر
        } else if (manualOverride) {
          final u = (qty > 0) ? (uiTotalPrice / qty) : uiTotalPrice;
          updates['unit_price'] = u;
          updates['unit_cost'] = unitCost;
          newTotalPrice = uiTotalPrice;
          newTotalCost = unitCost * qty;
          updates['manual_override'] = true;
          updates['discount_amount'] = (listPrice * qty) - newTotalPrice;

          updates['total_price'] = newTotalPrice;
          updates['total_cost'] = newTotalCost;
          if (!freezeProfit)
            updates['profit_total'] = newTotalPrice - newTotalCost;
        } else {
          final unitPriceEffective = unitPrice > 0 ? unitPrice : listPrice;
          updates['unit_price'] = unitPriceEffective;
          updates['unit_cost'] = unitCost;
          newTotalPrice = unitPriceEffective * qty;
          newTotalCost = unitCost * qty;

          updates['total_price'] = newTotalPrice;
          updates['total_cost'] = newTotalCost;
          if (!freezeProfit)
            updates['profit_total'] = newTotalPrice - newTotalCost;
        }
      } else if (type == 'single' || type == 'ready_blend') {
        grams = grams > 0 ? grams : numOf(_m['grams']);
        updates['grams'] = grams;

        // أساس البن
        final beansAmount = pricePerG * grams;
        final beansCost = costPerG * grams;

        // معدلات التحويج + Fallback
        final saleForRates = {..._m, 'type': type};
        final rates = await fetchSpiceRatesForSale(saleForRates);
        double spicePricePerKg = rates.pricePerKg;
        double spiceCostPerKg = rates.costPerKg;
        if (spicePricePerKg <= 0) {
          final name =
              (_m['name'] ?? _m['single_name'] ?? _m['blend_name'] ?? '')
                  .toString();
          spicePricePerKg = (type == 'single')
              ? spiceRatePerKgForSingle(name)
              : 40.0;
        }
        if (spiceCostPerKg < 0) spiceCostPerKg = 0.0;

        double spiceAmount = 0.0;
        double spiceCostAmount = 0.0;

        if (isCompl) {
          // ضيافة: صفر مبيعات/ربح، صِفر تحويج، تكلفة = تكلفة البن فقط
          newTotalPrice = 0.0;
          newTotalCost = beansCost;

          updates['beans_amount'] = 0.0;
          updates['spice_rate_per_kg'] = 0.0;
          updates['spice_cost_per_kg'] = 0.0;
          updates['spice_amount'] = 0.0;
          updates['spice_cost_amount'] = 0.0;

          updates['total_price'] = newTotalPrice;
          updates['total_cost'] = newTotalCost;
          updates['profit_total'] = 0.0; // إجبار الربح صفر
        } else if (manualOverride) {
          if (isSpiced) {
            spiceAmount = (grams / 1000.0) * spicePricePerKg;
            spiceCostAmount = (grams / 1000.0) * spiceCostPerKg;
          }
          final beansAmountFromUi = (uiTotalPrice - spiceAmount).clamp(
            0.0,
            double.infinity,
          );
          newTotalPrice = uiTotalPrice;
          newTotalCost = beansCost + spiceCostAmount;

          updates['beans_amount'] = beansAmountFromUi;
          updates['spice_rate_per_kg'] = isSpiced ? spicePricePerKg : 0.0;
          updates['spice_cost_per_kg'] = isSpiced ? spiceCostPerKg : 0.0;
          updates['spice_amount'] = spiceAmount;
          updates['spice_cost_amount'] = spiceCostAmount;

          final autoPrice = beansAmount + (isSpiced ? spiceAmount : 0.0);
          updates['manual_override'] = true;
          updates['discount_amount'] = (autoPrice - newTotalPrice);

          updates['total_price'] = newTotalPrice;
          updates['total_cost'] = newTotalCost;
          if (!freezeProfit)
            updates['profit_total'] = newTotalPrice - newTotalCost;
        } else {
          if (isSpiced) {
            spiceAmount = (grams / 1000.0) * spicePricePerKg;
            spiceCostAmount = (grams / 1000.0) * spiceCostPerKg;
          }

          newTotalPrice = beansAmount + spiceAmount;
          newTotalCost = beansCost + spiceCostAmount;

          updates['beans_amount'] = beansAmount;
          updates['spice_rate_per_kg'] = isSpiced ? spicePricePerKg : 0.0;
          updates['spice_cost_per_kg'] = isSpiced ? spiceCostPerKg : 0.0;
          updates['spice_amount'] = spiceAmount;
          updates['spice_cost_amount'] = spiceCostAmount;

          updates['total_price'] = newTotalPrice;
          updates['total_cost'] = newTotalCost;
          if (!freezeProfit)
            updates['profit_total'] = newTotalPrice - newTotalCost;
        }

        // ثوابت مرجعية
        updates['price_per_kg'] = pricePerKg;
        updates['price_per_g'] = pricePerG;
        updates['cost_per_kg'] = costPerKg;
        updates['cost_per_g'] = costPerG;
      } else if (type == 'custom_blend') {
        final gramsAll = totalGramsSaved > 0
            ? totalGramsSaved
            : numOf(_m['total_grams']);

        double spiceAmount = 0.0;
        if (isSpiced && !isCompl) {
          final rates = await fetchSpiceRatesForSale({..._m, 'type': type});
          final spiceRatePerKg = (rates.pricePerKg > 0)
              ? rates.pricePerKg
              : 50.0;
          spiceAmount = (gramsAll / 1000.0) * spiceRatePerKg;
          updates['spice_rate_per_kg'] = spiceRatePerKg;
          updates['spice_amount'] = spiceAmount;
        } else {
          updates['spice_rate_per_kg'] = 0.0;
          updates['spice_amount'] = 0.0;
        }

        final autoPrice = linesAmount + spiceAmount;
        if (isCompl) {
          newTotalPrice = 0.0;
        } else if (manualOverride) {
          newTotalPrice = uiTotalPrice;
          updates['manual_override'] = true;
          updates['discount_amount'] = (autoPrice - newTotalPrice);
        } else {
          newTotalPrice = autoPrice;
        }

        newTotalCost = numOf(_m['total_cost']); // محفوظ مسبقًا

        updates['total_price'] = newTotalPrice;
        updates['total_cost'] = newTotalCost;
        if (isCompl) {
          updates['profit_total'] = 0.0; // إجبار الربح صفر
        } else if (!freezeProfit) {
          updates['profit_total'] = newTotalPrice - newTotalCost;
        }
      } else {
        // unknown
        if (isCompl) {
          newTotalPrice = 0.0;
          newTotalCost = oldTotalCost;
          updates['total_price'] = newTotalPrice;
          updates['total_cost'] = newTotalCost;
          updates['profit_total'] = 0.0; // إجبار الربح صفر
        } else {
          newTotalPrice = uiTotalPrice;
          newTotalCost = oldTotalCost;
          updates['total_price'] = newTotalPrice;
          updates['total_cost'] = newTotalCost;
          if (!freezeProfit)
            updates['profit_total'] = newTotalPrice - newTotalCost;
          updates['manual_override'] = true;
        }
      }

      // كتابة كل شيء + تسوية المخزون داخل ترانزاكشن واحدة
      await _applyStockDeltaAndUpdate(updates);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ التعديل')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_m['name'] ?? 'عملية بيع').toString();
    final createdAt = (_m['created_at'] as Timestamp?)?.toDate();
    final when = createdAt != null
        ? '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}  '
              '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '';

    final isDrink = _type == 'drink';
    final isWeighted = _type == 'single' || _type == 'ready_blend';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 16 + bottomInset,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 42,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                if (when.isNotEmpty)
                  Text(when, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _totalPriceCtrl,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'السعر الإجمالي (total_price)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),

                if (isDrink) ...[
                  TextFormField(
                    controller: _qtyCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'عدد الأكواب (quantity)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                if (isWeighted) ...[
                  TextFormField(
                    controller: _gramsCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الكمية بالجرامات (grams)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // حقل الملاحظة
                TextFormField(
                  controller: _noteCtrl,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة (اختياري)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),

                const SizedBox(height: 10),
                CheckboxListTile(
                  value: _isComplimentary,
                  onChanged: (v) =>
                      setState(() => _isComplimentary = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('ضيافة'),
                ),

                if (_type == 'single' ||
                    _type == 'ready_blend' ||
                    _m.containsKey('is_spiced'))
                  CheckboxListTile(
                    value: _isSpiced,
                    onChanged: (v) => setState(() => _isSpiced = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('محوّج'),
                  ),

                const SizedBox(height: 8),
                const Text(
                  'ملاحظة: ربح الأجل غير المدفوع لا يتغير حتى التسوية.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: const Text('حفظ'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
