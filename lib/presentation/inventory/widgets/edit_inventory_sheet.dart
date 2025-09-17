import 'package:elfouad_admin/presentation/inventory/providers.dart';
import 'package:flutter/material.dart';

class EditInventorySheet extends StatefulWidget {
  final InventoryRow row;
  const EditInventorySheet({super.key, required this.row});

  @override
  State<EditInventorySheet> createState() => _EditInventorySheetState();
}

class _EditInventorySheetState extends State<EditInventorySheet> {
  late final TextEditingController _name;
  late final TextEditingController _variant;
  late final TextEditingController _stock;
  late final TextEditingController _sellPerKg;
  late final TextEditingController _minLevel;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.row.name);
    _variant = TextEditingController(text: widget.row.variant);
    _stock = TextEditingController(text: widget.row.stockG.toStringAsFixed(0));
    _sellPerKg = TextEditingController(
      text: widget.row.sellPerKg.toStringAsFixed(2),
    );
    _minLevel = TextEditingController(
      text: widget.row.minLevelG.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _variant.dispose();
    _stock.dispose();
    _sellPerKg.dispose();
    _minLevel.dispose();
    super.dispose();
  }

  double _d(String s) => double.tryParse(s.replaceAll(',', '.').trim()) ?? 0.0;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await updateInventoryRow(
        widget.row,
        name: _name.text.trim(),
        variant: _variant.text.trim(),
        stockG: _d(_stock.text),
        sellPerKg: _d(_sellPerKg.text),
        minLevelG: _d(_minLevel.text),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات')));
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
    final title = widget.row.variant.isEmpty
        ? widget.row.name
        : '${widget.row.name} — ${widget.row.variant}';

    final maxH = MediaQuery.of(context).size.height * 0.9;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, c) => ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),

                _tf(_name, 'الاسم'),
                const SizedBox(height: 10),
                _tf(_variant, 'درجة التحميص (اختياري)'),
                const SizedBox(height: 10),
                _tf(_stock, 'المخزون (جرامات)', number: true),
                const SizedBox(height: 10),
                _tf(_sellPerKg, 'سعر البيع/كجم', number: true),
                const SizedBox(height: 10),
                _tf(_minLevel, 'حد أدنى تحذيري (جم)', number: true),

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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tf(TextEditingController c, String label, {bool number = false}) {
    return TextField(
      controller: c,
      textAlign: TextAlign.center,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        isDense: true,
        border: const OutlineInputBorder(),
        labelText: label,
      ),
    );
  }
}
