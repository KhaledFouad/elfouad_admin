import 'package:elfouad_admin/presentation/stats/utils/group_row.dart';
import 'package:flutter/material.dart';

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
                child: Center(child: Text('لا توجد بيانات لهذا القسم')),
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
                        DataColumn(label: Text('الفئة')),
                        DataColumn(label: Text('الكمية')),
                        DataColumn(label: Text('المبيعات')),
                        DataColumn(label: Text('التكلفة')),
                        DataColumn(label: Text('الربح')),
                        DataColumn(label: Text('المتوسط')),
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
                                '${r.metric == GroupMetric.grams ? ' /كجم' : ' /كوب'}',
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
