import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:flutter/material.dart';

import '../models/sale_component.dart';
import '../utils/sale_utils.dart';
import '../utils/sales_history_utils.dart';

part 'sale_edit_sheet/sale_edit_sheet_state.dart';
part 'sale_edit_sheet/sale_edit_sheet_helpers.dart';
part 'sale_edit_sheet/sale_edit_sheet_stock_helpers.dart';
part 'sale_edit_sheet/sale_edit_sheet_actions.dart';
part 'sale_edit_sheet/sale_edit_sheet_inputs.dart';
part 'sale_edit_sheet/sale_edit_sheet_models.dart';

/// Edit sheet for sale records with type-specific forms.
class SaleEditSheet extends StatefulWidget {
  const SaleEditSheet({super.key, required this.snap});

  final DocumentSnapshot<Map<String, dynamic>> snap;

  @override
  State<SaleEditSheet> createState() => _SaleEditSheetState();
}
