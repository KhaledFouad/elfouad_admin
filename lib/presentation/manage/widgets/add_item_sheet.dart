import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/inventory/bloc/inventory_cubit.dart';
import 'package:elfouad_admin/presentation/inventory/models/inventory_row.dart';
import 'package:elfouad_admin/presentation/inventory/utils/inventory_log.dart';
import 'package:elfouad_admin/presentation/manage/bloc/extras_cubit.dart';
import 'package:elfouad_admin/presentation/manage/bloc/tahwiga_cubit.dart';
import 'package:elfouad_admin/presentation/manage/models/extra_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'add_item_sheet/add_item_sheet_models.dart';
part 'add_item_sheet/add_item_sheet_state.dart';
part 'add_item_sheet/add_item_sheet_form_common.dart';
part 'add_item_sheet/add_item_sheet_form_drink.dart';
part 'add_item_sheet/add_item_sheet_drink_helpers.dart';
part 'add_item_sheet/add_item_sheet_actions.dart';
part 'add_item_sheet/add_item_sheet_validators.dart';

/// Sheet used to add new items across supported product types.
class AddItemSheet extends StatefulWidget {
  final NewItemType initialType;

  const AddItemSheet({super.key, this.initialType = NewItemType.blend});

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}
