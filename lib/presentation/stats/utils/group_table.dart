import 'package:elfouad_admin/presentation/stats/utils/group_row.dart';
import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';

class GroupTable extends StatelessWidget {
  final String title;
  final List<GroupRow> rows;

  const GroupTable({super.key, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: rows.isEmpty
            ? const SizedBox(
                height: 100,
                child: Center(child: Text(AppStrings.noDataForSection)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 36,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 48,
                      columns: const [
                        DataColumn(label: Text(AppStrings.groupCategoryLabel)),
                        DataColumn(label: Text(AppStrings.quantityLabelShort)),
                        DataColumn(label: Text(AppStrings.salesLabelDefinite)),
                        DataColumn(label: Text(AppStrings.costLabelDefinite)),
                        DataColumn(label: Text(AppStrings.profitLabelDefinite)),
                        DataColumn(label: Text(AppStrings.averageLabel)),
                      ],
                      rows: rows.map((r) {
                        return DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 160,
                                child: Text(
                                  r.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(r.amountText)),
                            DataCell(Text(r.sales.toStringAsFixed(2))),
                            DataCell(Text(r.cost.toStringAsFixed(2))),
                            DataCell(Text(r.profit.toStringAsFixed(2))),
                            DataCell(
                              Text(
                                '${r.avg.toStringAsFixed(2)}'
                                '${r.metric == GroupMetric.grams ? AppStrings.avgPerKgSuffix : AppStrings.avgPerCupSuffix}',
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
