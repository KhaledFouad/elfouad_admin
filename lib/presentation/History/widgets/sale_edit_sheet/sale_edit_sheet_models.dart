part of '../sale_edit_sheet.dart';

/// Mutable UI draft model for each invoice line item.
class _InvoiceItemDraft {
  _InvoiceItemDraft({
    required this.raw,
    required this.label,
    required this.unit,
    required this.showGrams,
    required this.showQty,
    required this.useGrams,
    required this.spicedEnabled,
    required this.spiced,
    required this.showGinseng,
    required this.unitCost,
    required this.baseLineCost,
    required this.priceCtrl,
    required this.qtyCtrl,
    required this.gramsCtrl,
    required this.ginsengCtrl,
  });

  final Map<String, dynamic> raw;
  final String label;
  final String unit;
  final bool showGrams;
  final bool showQty;
  final bool useGrams;
  final bool spicedEnabled;
  bool spiced;
  final bool showGinseng;
  final double unitCost;
  final double baseLineCost;
  final TextEditingController priceCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController gramsCtrl;
  final TextEditingController ginsengCtrl;

  bool get usesMeasure => showGrams || showQty;

  void dispose() {
    priceCtrl.dispose();
    qtyCtrl.dispose();
    gramsCtrl.dispose();
    ginsengCtrl.dispose();
  }
}
