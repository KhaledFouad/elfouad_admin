import 'package:elfouad_admin/core/utils/app_strings.dart';

enum GroupMetric { cups, grams }

class GroupRow {
  /// اسم المجموعة (مثلاً: "تركي" أو "برازيلي - وسط")
  final String label;

  /// نوع القياس: أكواب أو جرامات
  final GroupMetric metric;

  /// القيمة المجُمَّعة:
  /// - لو Cups: عدد الأكواب
  /// - لو Grams: إجمالي الجرامات
  final double amount;

  /// إجمالي المبيعات والتكلفة للمجموعة
  final double sales;
  final double cost;

  const GroupRow({
    required this.label,
    required this.metric,
    required this.amount,
    required this.sales,
    required this.cost,
  });

  double get profit => sales - cost;

  /// متوسط السعر:
  /// - لو Grams: متوسط السعر لكل كيلوجرام
  /// - لو Cups : متوسط السعر للكوب
  double get avg {
    if (amount <= 0) return 0;
    return metric == GroupMetric.grams
        ? (sales / amount) * 1000.0
        : (sales / amount);
  }

  String get avgLabel => metric == GroupMetric.grams
      ? AppStrings.averagePerKgLabel
      : AppStrings.averagePerCupLabel;

  String get amountText => metric == GroupMetric.grams
      ? AppStrings.gramsAmount(amount)
      : amount.toStringAsFixed(0);
}
