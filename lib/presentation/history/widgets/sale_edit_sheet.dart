import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/sales_history_utils.dart';
import '../utils/sales_history_utils.dart' show applyStockDeltaOnSaleEdit;

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
  bool _isComplimentary = false;
  bool _isSpiced = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _m = widget.snap.data() ?? {};
    _type = (_m['type'] ?? 'unknown').toString();

    _totalPriceCtrl.text = numD(_m['total_price']).toStringAsFixed(2);

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
    super.dispose();
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
      double spiceRatePerKg = numOf(_m['spice_rate_per_kg']);
      final spiceAmountSaved = numOf(_m['spice_amount']);

      final uiTotalPrice =
          double.tryParse(_totalPriceCtrl.text.replaceAll(',', '.')) ??
          oldTotalPrice;
      double qty =
          double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ??
          numOf(_m['quantity']);
      double grams =
          double.tryParse(_gramsCtrl.text.replaceAll(',', '.')) ??
          numOf(_m['grams']);

      updates['is_complimentary'] = isCompl;
      if (_m.containsKey('is_spiced')) updates['is_spiced'] = isSpiced;

      final bool manualOverride =
          !isCompl && (uiTotalPrice - oldTotalPrice).abs() > 0.0005;

      double newTotalPrice = oldTotalPrice;
      double newTotalCost = oldTotalCost;

      if (type == 'drink') {
        qty = qty <= 0 ? 1 : qty;
        updates['quantity'] = qty;

        if (isCompl) {
          newTotalPrice = 0.0;
          newTotalCost = unitCost * qty;
          updates['unit_price'] = 0.0;
          updates['unit_cost'] = unitCost;
        } else if (manualOverride) {
          final u = (qty > 0) ? (uiTotalPrice / qty) : uiTotalPrice;
          updates['unit_price'] = u;
          updates['unit_cost'] = unitCost;
          newTotalPrice = uiTotalPrice;
          newTotalCost = unitCost * qty;
          updates['manual_override'] = true;
          updates['discount_amount'] = (listPrice * qty) - newTotalPrice;
        } else {
          final unitPriceEffective = unitPrice > 0 ? unitPrice : listPrice;
          updates['unit_price'] = isCompl ? 0.0 : unitPriceEffective;
          updates['unit_cost'] = unitCost;
          newTotalPrice = isCompl ? 0.0 : unitPriceEffective * qty;
          newTotalCost = unitCost * qty;
        }

        updates['total_price'] = newTotalPrice;
        updates['total_cost'] = newTotalCost;
        updates['profit_total'] = newTotalPrice - newTotalCost;
      } else if (type == 'single' || type == 'ready_blend') {
        grams = grams > 0 ? grams : numOf(_m['grams']);
        updates['grams'] = grams;

        newTotalCost = costPerG * grams;

        if (isCompl) {
          newTotalPrice = 0.0;
          updates['beans_amount'] = 0.0;
          if (_m.containsKey('spice_amount')) {
            updates['spice_amount'] = 0.0;
            updates['spice_rate_per_kg'] = 0.0;
          }
        } else if (manualOverride) {
          double spiceAmount = spiceAmountSaved;
          if (_m.containsKey('is_spiced')) {
            if (isSpiced) {
              if (spiceRatePerKg <= 0) {
                if (type == 'single') {
                  final name = (_m['name'] ?? '').toString();
                  spiceRatePerKg = spiceRatePerKgForSingle(name);
                } else {
                  spiceRatePerKg = 40.0;
                }
              }
              spiceAmount = (grams / 1000.0) * spiceRatePerKg;
            } else {
              spiceAmount = 0.0;
              spiceRatePerKg = 0.0;
            }
            updates['spice_rate_per_kg'] = spiceRatePerKg;
            updates['spice_amount'] = spiceAmount;
          }

          final beansAmount = (uiTotalPrice - spiceAmount).clamp(
            0.0,
            double.infinity,
          );
          updates['beans_amount'] = beansAmount;

          newTotalPrice = uiTotalPrice;
          final autoPrice =
              (pricePerG * grams) +
              (isSpiced ? ((grams / 1000.0) * spiceRatePerKg) : 0.0);
          updates['manual_override'] = true;
          updates['discount_amount'] = (autoPrice - newTotalPrice);
        } else {
          final beansAmount = pricePerG * grams;
          double spiceAmount = 0.0;
          if (_m.containsKey('is_spiced')) {
            if (isSpiced) {
              if (spiceRatePerKg <= 0) {
                if (type == 'single') {
                  final name = (_m['name'] ?? '').toString();
                  spiceRatePerKg = spiceRatePerKgForSingle(name);
                } else {
                  spiceRatePerKg = 40.0;
                }
              }
              spiceAmount = (grams / 1000.0) * spiceRatePerKg;
            } else {
              spiceRatePerKg = 0.0;
            }
            updates['spice_rate_per_kg'] = spiceRatePerKg;
            updates['spice_amount'] = spiceAmount;
          }
          updates['beans_amount'] = beansAmount;
          newTotalPrice = beansAmount + spiceAmount;
        }

        updates['price_per_kg'] = pricePerKg;
        updates['price_per_g'] = pricePerG;
        updates['cost_per_kg'] = costPerKg;
        updates['cost_per_g'] = costPerG;

        updates['total_price'] = newTotalPrice;
        updates['total_cost'] = newTotalCost;
        updates['profit_total'] = newTotalPrice - newTotalCost;
      } else if (type == 'custom_blend') {
        final gramsAll = totalGramsSaved > 0
            ? totalGramsSaved
            : numOf(_m['total_grams']);

        double spiceAmount = spiceAmountSaved;
        if (_m.containsKey('is_spiced')) {
          if (isSpiced) {
            spiceRatePerKg = spiceRatePerKg > 0 ? spiceRatePerKg : 50.0;
            spiceAmount = (gramsAll / 1000.0) * spiceRatePerKg;
          } else {
            spiceRatePerKg = 0.0;
            spiceAmount = 0.0;
          }
          updates['spice_rate_per_kg'] = spiceRatePerKg;
          updates['spice_amount'] = spiceAmount;
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

        newTotalCost = numOf(_m['total_cost']);
        updates['total_price'] = newTotalPrice;
        updates['total_cost'] = newTotalCost;
        updates['profit_total'] = newTotalPrice - newTotalCost;
      } else {
        newTotalPrice = isCompl ? 0.0 : uiTotalPrice;
        updates['total_price'] = newTotalPrice;
        updates['total_cost'] = oldTotalCost;
        updates['profit_total'] = newTotalPrice - oldTotalCost;
        updates['manual_override'] = true;
      }

      // 1) حدّث مستند البيع
      await widget.snap.reference.update(updates);

      // 2) طبّق فرق المخزون بناءً على (قبل/بعد)
      final after = <String, dynamic>{..._m, ...updates};
      await applyStockDeltaOnSaleEdit(before: _m, after: after);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ التعديل وتمت تسوية المخزون تلقائيًا'),
        ),
      );
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

                CheckboxListTile(
                  value: _isComplimentary,
                  onChanged: (v) =>
                      setState(() => _isComplimentary = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('ضيافة'),
                ),

                if (_m.containsKey('is_spiced'))
                  CheckboxListTile(
                    value: _isSpiced,
                    onChanged: (v) => setState(() => _isSpiced = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('محوّج'),
                  ),

                const SizedBox(height: 8),
                const Text(
                  'ملاحظة: تعديل عملية البيع يعيد تسوية المخزون تلقائيًا.',
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
