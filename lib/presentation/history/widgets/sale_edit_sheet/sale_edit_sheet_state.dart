part of '../sale_edit_sheet.dart';

/// Holds state and top-level composition for the sale edit sheet.
class _SaleEditSheetState extends State<SaleEditSheet> {
  late Map<String, dynamic> _m;
  late String _type;

  final TextEditingController _totalPriceCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _gramsCtrl = TextEditingController();
  final TextEditingController _ginsengCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _dueAmountCtrl = TextEditingController();

  bool _isComplimentary = false;
  bool _isSpiced = false;
  bool _busy = false;
  bool _isDeferred = false;
  bool _isPaid = true;

  double _invoiceTotalPrice = 0.0;
  double _invoiceTotalCost = 0.0;
  final List<_InvoiceItemDraft> _invoiceItems = [];

  double _unitPriceCache = 0.0;
  double _unitCostCache = 0.0;
  bool _userEditedTotal = false;
  double? _lastNonComplPrice;

  @override
  void initState() {
    super.initState();
    _m = widget.snap.data() ?? {};
    final rawType = (_m['type'] ?? '').toString();
    final linesType = (_m['lines_type'] ?? '').toString();
    _type = rawType.isNotEmpty
        ? rawType
        : (linesType.isNotEmpty ? linesType : detectSaleType(_m)).toString();

    _totalPriceCtrl.text = _numOf(_m['total_price']).toStringAsFixed(2);
    _noteCtrl.text = ((_m['note'] ?? _m['notes'] ?? '') as Object).toString();

    _isComplimentary = (_m['is_complimentary'] ?? false) == true;
    _isSpiced = (_m['is_spiced'] ?? false) == true;
    final meta = _m['meta'];
    final ginsengMeta = meta is Map
        ? (meta['ginseng_grams'] ?? meta['ginsengGrams'])
        : null;
    final ginsengGrams = _intOf(
      _m['ginseng_grams'] ?? _m['ginsengGrams'] ?? ginsengMeta,
      0,
    );
    if (ginsengGrams > 0) {
      _ginsengCtrl.text = ginsengGrams.toString();
    }

    if (_type == 'drink') {
      final q = _numOf(_m['quantity'], 1);
      _qtyCtrl.text = (q == q.roundToDouble())
          ? q.toStringAsFixed(0)
          : q.toStringAsFixed(2);
    } else if (_type == 'single' || _type == 'ready_blend') {
      final g = _numOf(_m['grams']);
      if (g > 0) _gramsCtrl.text = g.toStringAsFixed(0);
    } else if (_type == 'extra') {
      final oldQty = _intOf(_m['quantity'], 1);
      _qtyCtrl.text = oldQty.toString();

      final unitPrice = _numOf(_m['unit_price']);
      final unitCost = _numOf(_m['unit_cost']);
      _unitPriceCache = unitPrice > 0
          ? unitPrice
          : (_numOf(_m['total_price']) / (oldQty > 0 ? oldQty : 1));
      _unitCostCache = unitCost > 0
          ? unitCost
          : (_numOf(_m['total_cost']) / (oldQty > 0 ? oldQty : 1));

      _totalPriceCtrl.addListener(() {
        _userEditedTotal = true;
      });

      _qtyCtrl.addListener(() {
        if (_isComplimentary) return;
        if (_userEditedTotal) return;
        final q = _intOf(_qtyCtrl.text, 1).clamp(1, 100000);
        final newTotal = _unitPriceCache * q;
        _setTotalPriceText(newTotal);
      });
    }

    if (_type == 'invoice') {
      _initInvoiceFields();
    }
  }

  @override
  void dispose() {
    for (final item in _invoiceItems) {
      item.dispose();
    }
    _totalPriceCtrl.dispose();
    _qtyCtrl.dispose();
    _gramsCtrl.dispose();
    _ginsengCtrl.dispose();
    _noteCtrl.dispose();
    _dueAmountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name =
        (_m['name'] ?? _m['drink_name'] ?? AppStrings.saleOperationLabel)
            .toString();
    final createdAt = (_m['created_at'] as Timestamp?)?.toDate();
    final when = createdAt != null
        ? '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}  '
              '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '';

    final isDrink = _type == 'drink';
    final isWeighted = _type == 'single' || _type == 'ready_blend';
    final isExtras = _type == 'extra';
    final isInvoice = _type == 'invoice';
    final canEditComplimentary = !(isInvoice && _isDeferred);
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
                  enabled: !_isComplimentary,
                  readOnly: isInvoice,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: AppStrings.totalPriceLabel,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                if (isInvoice) ...[
                  _buildInvoiceHeaderSection(),
                  const SizedBox(height: 10),
                  _buildInvoiceItemsSection(),
                  const SizedBox(height: 10),
                ],
                if (isDrink) ...[
                  TextFormField(
                    controller: _qtyCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: AppStrings.cupsCountLabel,
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
                      labelText: AppStrings.gramsQuantityLabel,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _ginsengCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: AppStrings.ginsengGramsLabel,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (isExtras) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _qtyCtrl,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: AppStrings.quantityLabel,
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          IconButton(
                            tooltip: AppStrings.increaseLabel,
                            onPressed: () {
                              final q = _intOf(_qtyCtrl.text, 1) + 1;
                              _qtyCtrl.text = q.toString();
                              if (!_isComplimentary && !_userEditedTotal) {
                                _setTotalPriceText(_unitPriceCache * q);
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          IconButton(
                            tooltip: AppStrings.decreaseLabel,
                            onPressed: () {
                              var q = _intOf(_qtyCtrl.text, 1);
                              q = (q > 1) ? q - 1 : 1;
                              _qtyCtrl.text = q.toString();
                              if (!_isComplimentary && !_userEditedTotal) {
                                _setTotalPriceText(_unitPriceCache * q);
                              }
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                TextFormField(
                  controller: _noteCtrl,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: AppStrings.noteOptionalLabel,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                if (canEditComplimentary)
                  CheckboxListTile(
                    value: _isComplimentary,
                    onChanged: (v) {
                      setState(() {
                        final nv = v ?? false;
                        _isComplimentary = nv;
                        if (isInvoice && nv) {
                          _isDeferred = false;
                          _isPaid = true;
                          _dueAmountCtrl.text = '0.00';
                          _syncInvoiceTotals();
                        }
                        if (isInvoice && !nv) {
                          _syncInvoiceTotals();
                        }
                        if (isExtras) {
                          if (nv) {
                            _lastNonComplPrice = double.tryParse(
                              _totalPriceCtrl.text.replaceAll(',', '.'),
                            );
                            _setTotalPriceText(0.0);
                          } else {
                            final q = _intOf(_qtyCtrl.text, 1).clamp(1, 100000);
                            final back =
                                _userEditedTotal && _lastNonComplPrice != null
                                ? _lastNonComplPrice!
                                : (_unitPriceCache * q);
                            _setTotalPriceText(back);
                          }
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(AppStrings.complimentaryLabel),
                  ),
                if (!isInvoice &&
                    ((_type == 'single' || _type == 'ready_blend') ||
                        (_m.containsKey('is_spiced') && !isExtras)))
                  CheckboxListTile(
                    value: _isSpiced,
                    onChanged: (v) => setState(() => _isSpiced = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(AppStrings.spicedLabel),
                  ),
                const SizedBox(height: 8),
                const Text(
                  AppStrings.deferredProfitNote,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        child: const Text(AppStrings.actionCancel),
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
                        label: const Text(AppStrings.actionSave),
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
