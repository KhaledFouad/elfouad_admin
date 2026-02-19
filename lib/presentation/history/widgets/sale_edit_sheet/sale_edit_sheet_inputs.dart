// ignore_for_file: invalid_use_of_protected_member
part of '../sale_edit_sheet.dart';

/// Input and section widgets for invoice-specific controls.
extension _SaleEditSheetInputs on _SaleEditSheetState {
  Widget _buildInvoiceHeaderSection() {
    final showDue = _isDeferred || _dueAmountCtrl.text.trim().isNotEmpty;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                value: _isDeferred,
                onChanged: (v) {
                  setState(() {
                    _isDeferred = v ?? false;
                    if (!_isDeferred) {
                      _isPaid = true;
                      _dueAmountCtrl.text = '0.00';
                    } else {
                      _isComplimentary = false;
                    }
                    _syncInvoiceTotals();
                  });
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(AppStrings.deferredLabel),
              ),
            ),
            Expanded(
              child: CheckboxListTile(
                value: _isPaid,
                onChanged: (v) {
                  setState(() {
                    _isPaid = v ?? false;
                    if (!_isPaid) {
                      _isDeferred = true;
                      _isComplimentary = false;
                      if (_numOf(_dueAmountCtrl.text) <= 0) {
                        _dueAmountCtrl.text = _invoiceTotalPrice
                            .toStringAsFixed(2);
                      }
                    } else {
                      _dueAmountCtrl.text = '0.00';
                    }
                    _syncInvoiceTotals();
                  });
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(AppStrings.paidLabel),
              ),
            ),
          ],
        ),
        if (showDue) ...[
          const SizedBox(height: 6),
          TextFormField(
            controller: _dueAmountCtrl,
            enabled: _isDeferred && !_isPaid,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: AppStrings.labelAmountDue,
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInvoiceItemCard(_InvoiceItemDraft item, int index) {
    final linePrice = _invoiceLinePrice(
      item,
      applyComplimentary: _isComplimentary,
    );
    final lineCost = _invoiceLineCost(item);
    final showMeasureField = item.useGrams ? item.showGrams : item.showQty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: AppStrings.actionDelete,
                onPressed: _busy ? null : () => _removeInvoiceItem(index),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          if (showMeasureField) ...[
            TextFormField(
              controller: item.useGrams ? item.gramsCtrl : item.qtyCtrl,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: item.useGrams
                    ? AppStrings.gramsQuantityLabel
                    : AppStrings.quantityLabelShort,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextFormField(
            controller: item.priceCtrl,
            enabled: !_isComplimentary,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: AppStrings.lineTotalPriceLabel,
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${AppStrings.totalLabel}: ${linePrice.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${AppStrings.costLabelDefinite}: ${lineCost.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.invoiceItemsLabel,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (_invoiceItems.isEmpty)
          const Text(AppStrings.noItems)
        else
          ..._invoiceItems.asMap().entries.map(
            (entry) => _buildInvoiceItemCard(entry.value, entry.key),
          ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${AppStrings.totalLabel}: ${_invoiceTotalPrice.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${AppStrings.costLabelDefinite}: ${_invoiceTotalCost.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ],
    );
  }
}
