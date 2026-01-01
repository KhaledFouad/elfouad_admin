import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';
import '../state/grind_providers.dart';

class GrindConfirmSheet extends StatefulWidget {
  final InventoryRow row;
  const GrindConfirmSheet({super.key, required this.row});

  @override
  State<GrindConfirmSheet> createState() => _GrindConfirmSheetState();
}

class _GrindConfirmSheetState extends State<GrindConfirmSheet> {
  final _amountCtrl = TextEditingController(text: '0');
  bool _busy = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  double _n(String s) {
    return double.tryParse(s.replaceAll(',', '.')) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final title = r.variant.isEmpty ? r.name : '${r.name} — ${r.variant}';

    final entered = _n(_amountCtrl.text);
    final bool canConfirm =
        !(_busy || entered <= 0 || r.stockG <= 0 || entered > r.stockG);

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
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 10),

            Text(
              AppStrings.availableGrams(r.stockG),
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),

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
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: AppStrings.amountGramsLabel,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    IconButton(
                      tooltip: AppStrings.add100GramsTooltip,
                      onPressed: () {
                        final v = _n(_amountCtrl.text);
                        setState(() {
                          final next = (v + 100).clamp(0, r.stockG);
                          _amountCtrl.text = next.toStringAsFixed(0);
                        });
                      },
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      tooltip: AppStrings.sub100GramsTooltip,
                      onPressed: () {
                        final v = _n(_amountCtrl.text);
                        setState(() {
                          final next = (v - 100).clamp(0, r.stockG);
                          _amountCtrl.text = next.toStringAsFixed(0);
                        });
                      },
                      icon: const Icon(Icons.remove),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () {
                            FocusManager.instance.primaryFocus
                                ?.unfocus(); // ⬅️ اقفل الكيبورد

                            Navigator.pop(context);
                          },
                    child: const Text(AppStrings.actionCancel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canConfirm
                        ? () async {
                            FocusManager.instance.primaryFocus
                                ?.unfocus(); // ⬅️ اقفل الكيبورد

                            final grams = _n(_amountCtrl.text);
                            setState(() => _busy = true);
                            try {
                              await grindAndDeduct(
                                item: r,
                                grams: grams,
                                isSpiced: false,
                              );
                              if (!context.mounted) return;
                              Navigator.pop(context); // يقفل الشيت
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(AppStrings.stockDeducted),
                                ),
                              );
                            } on StateError catch (e) {
                              if (!context.mounted) return;
                              final msg = switch (e.message) {
                                'empty_stock' => AppStrings.noStockAvailable,
                                'insufficient_stock' =>
                                  AppStrings.quantityExceedsAvailable,
                                _ => AppStrings.deductFailed(e.message),
                              };
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(msg)));
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(AppStrings.deductFailed(e)),
                                ),
                              );
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          }
                        : null,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.done_all),
                    label: const Text(AppStrings.confirmDeduct),
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
}
