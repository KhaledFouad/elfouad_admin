import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/inventory/bloc/inventory_cubit.dart';
import 'package:elfouad_admin/presentation/inventory/models/inventory_row.dart';
import 'package:elfouad_admin/presentation/inventory/utils/inventory_log.dart';
import 'package:elfouad_admin/presentation/manage/bloc/tahwiga_cubit.dart';
import 'package:elfouad_admin/presentation/manage/models/extra_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'product_edit_sheet/product_edit_sheet_models.dart';
part 'product_edit_sheet/product_edit_sheet_state.dart';
part 'product_edit_sheet/product_edit_sheet_init_helpers.dart';
part 'product_edit_sheet/product_edit_sheet_actions.dart';
part 'product_edit_sheet/product_edit_sheet_form_widgets.dart';
part 'product_edit_sheet/product_edit_sheet_drink_helpers.dart';
part 'product_edit_sheet/product_edit_sheet_mapper_helpers.dart';
part 'product_edit_sheet/product_edit_sheet_validators.dart';

/// Sheet used to edit an existing product document.
class ProductEditSheet extends StatefulWidget {
  final String collection;
  final DocumentSnapshot<Map<String, dynamic>> snap;

  const ProductEditSheet({
    super.key,
    required this.collection,
    required this.snap,
  });

  @override
  State<ProductEditSheet> createState() => _ProductEditSheetState();
}
