import 'package:elfouad_admin/presentation/grind/state/grind_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GrindConfirmSheet extends ConsumerStatefulWidget {
  final InventoryRow row;
  const GrindConfirmSheet({super.key, required this.row});

  @override
  ConsumerState<GrindConfirmSheet> createState() => _GrindConfirmSheetState();
}

class _GrindConfirmSheetState extends ConsumerState<GrindConfirmSheet> {
  final _amountCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final title = r.variant.trim().isEmpty
        ? r.name
        : '${r.name} — ${r.variant}';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
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
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              'المتاح: ${r.stockG.toStringAsFixed(0)} جم',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),

            // إدخال الكمية + stepper صغير
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}), // علشان يحدّث حالة الزر
                    decoration: InputDecoration(
                      labelText: 'الكمية (جم)',
                      helperText: 'المتاح: ${r.stockG.toStringAsFixed(0)} جم',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _stepBtn(Icons.remove, () {
                  final v = _n(_amountCtrl.text);
                  _amountCtrl.text = (v - 100)
                      .clamp(0, double.infinity)
                      .toStringAsFixed(0);
                  setState(() {});
                }),
                const SizedBox(width: 6),
                _stepBtn(Icons.add, () {
                  final v = _n(_amountCtrl.text);
                  _amountCtrl.text = (v + 100).toStringAsFixed(0);
                  setState(() {});
                }),
              ],
            ),

            const SizedBox(height: 14),
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
                    onPressed: _busy
                        ? null
                        : () async {
                            var grams = _n(_amountCtrl.text);
                            if (grams <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('من فضلك أدخل كمية أكبر من 0'),
                                ),
                              );
                              return;
                            }
                            // منع خصم أكبر من المتاح
                            if (grams > r.stockG) grams = r.stockG;

                            setState(() => _busy = true);
                            try {
                              await grindAndDeduct(
                                item: r,
                                grams: grams,
                                isSpiced: false, // اتشال من الواجهة، ثابت false
                              );
                              if (!mounted) return;
                              Navigator.pop(context); // يقفل الشيت
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم الخصم من المخزون'),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تعذر الخصم من المخزون: $e'),
                                ),
                              );
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.done_all),
                    label: const Text('تأكيد الخصم'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF5E3D28),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBtn(IconData i, VoidCallback onTap) => Ink(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.brown.shade200),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(i, size: 18),
      ),
    ),
  );

  double _n(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
  }
}
