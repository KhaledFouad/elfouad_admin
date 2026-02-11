part of '../add_item_sheet.dart';

/// Mutable editing models for create-item forms.
enum NewItemType { single, blend, drink, extra, tahwiga }

class _OptionEntry {
  _OptionEntry(this.id, {String initial = ''})
    : controller = TextEditingController(text: initial);

  final String id;
  final TextEditingController controller;

  String get name => controller.text.trim();

  void dispose() {
    controller.dispose();
  }
}

class _DrinkPriceEntry {
  _DrinkPriceEntry({required this.variantId, required this.roastId})
    : sellCtrl = TextEditingController(text: '0.0'),
      costCtrl = TextEditingController(text: '0.0'),
      spicedSellCtrl = TextEditingController(text: '0.0'),
      spicedCostCtrl = TextEditingController(text: '0.0');

  final String variantId;
  final String roastId;
  final TextEditingController sellCtrl;
  final TextEditingController costCtrl;
  final TextEditingController spicedSellCtrl;
  final TextEditingController spicedCostCtrl;

  void dispose() {
    sellCtrl.dispose();
    costCtrl.dispose();
    spicedSellCtrl.dispose();
    spicedCostCtrl.dispose();
  }
}

class _RoastUsageEntry {
  _RoastUsageEntry() : gramsCtrl = TextEditingController();

  final TextEditingController gramsCtrl;
  final Map<String, TextEditingController> variantGramsCtrls = {};
  InventoryRow? item;
  String? coll;

  void syncVariants(Set<String> activeIds) {
    for (final id in activeIds) {
      variantGramsCtrls.putIfAbsent(id, () => TextEditingController());
    }
    final removeIds = variantGramsCtrls.keys
        .where((id) => !activeIds.contains(id))
        .toList();
    for (final id in removeIds) {
      variantGramsCtrls[id]?.dispose();
      variantGramsCtrls.remove(id);
    }
  }

  TextEditingController gramsFor(String variantId) {
    return variantGramsCtrls.putIfAbsent(
      variantId,
      () => TextEditingController(),
    );
  }

  void dispose() {
    gramsCtrl.dispose();
    for (final ctrl in variantGramsCtrls.values) {
      ctrl.dispose();
    }
  }
}

class _ItemRoastEntry {
  _ItemRoastEntry(this.id)
    : nameCtrl = TextEditingController(),
      stockCtrl = TextEditingController(text: '0'),
      sellCtrl = TextEditingController(text: '0.0'),
      costCtrl = TextEditingController(text: '0.0');

  final String id;
  final TextEditingController nameCtrl;
  final TextEditingController stockCtrl;
  final TextEditingController sellCtrl;
  final TextEditingController costCtrl;

  String get name => nameCtrl.text.trim();

  void dispose() {
    nameCtrl.dispose();
    stockCtrl.dispose();
    sellCtrl.dispose();
    costCtrl.dispose();
  }
}
