import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../utils/export_sales_csv.dart'; // تأكد من المسار عندك

class FilterAndExportSheet extends StatefulWidget {
  /// الرينج الحالي اللى الصفحة ماشية عليه دلوقتي
  final DateTimeRange initialRange;

  /// هيتنفذ لما المستخدم يختار "تطبيق" (هنبعتلك الرينج)
  final void Function(DateTimeRange range) onApply;

  /// نمرر context بتاع الصفحة الأم عشان نظهر SnackBar بعد ما نقفل الشيت
  final BuildContext hostContext;

  const FilterAndExportSheet({
    super.key,
    required this.initialRange,
    required this.onApply,
    required this.hostContext,
  });

  @override
  State<FilterAndExportSheet> createState() => _FilterAndExportSheetState();
}

class _FilterAndExportSheetState extends State<FilterAndExportSheet> {
  late DateTimeRange _range;
  bool _busyExport = false;

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange;
  }

  String _fmtDay(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _pickRange() async {
    final now = DateTime.now();
    // نحول الرينج المعروض لدات بيكر عادى (من غير 4 ص)
    final initStart = DateTime(
      _range.start.year,
      _range.start.month,
      _range.start.day,
    );
    final initEnd = DateTime(_range.end.year, _range.end.month, _range.end.day);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: initStart, end: initEnd),
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: ui.TextDirection.rtl, // ✅ بدّلناها
        child: child!,
      ),
    );

    if (picked != null) {
      // نُرجع الرينج بصيغة التشغيل (من 4 صباحاً → 4 صباحاً + يوم)
      final start = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
        4,
      );
      final end = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        4,
      ).add(const Duration(days: 1));
      setState(() => _range = DateTimeRange(start: start, end: end));
    }
  }

  Future<void> _apply() async {
    // نبلغ الصفحة بالرنج ونقفل فوراً
    widget.onApply(_range);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _exportCsv() async {
    if (_busyExport) return;
    setState(() => _busyExport = true);

    // نقفل الشيت الأول، وبعدها نعمل التصدير ونظهر رسالة في الصفحة الأم
    if (mounted) Navigator.pop(context);

    try {
      final filePath = await exportSalesCsv(
        _range,
      ); // ← لازم ترجع مسار الملف String

      final where = await exportSalesCsv(_range);
      ScaffoldMessenger.of(widget.hostContext).showSnackBar(
        SnackBar(
          content: Text('تم الحفظ: $filePath'),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'فتح',
            onPressed: () => OpenFilex.open(filePath),
          ),
        ),
      );
      await Clipboard.setData(ClipboardData(text: filePath));
      ScaffoldMessenger.of(widget.hostContext).showSnackBar(
        const SnackBar(
          content: Text('تم نسخ مسار الملف إلى الحافظة'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(widget.hostContext).showSnackBar(
        SnackBar(
          content: Text('تعذّر التصدير: $e'),
          duration: const Duration(seconds: 6), // ✅ مدة أطول
        ),
      );
    } finally {
      if (mounted) setState(() => _busyExport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dispStart = _fmtDay(_range.start);
    final dispEnd = _fmtDay(_range.end.subtract(const Duration(minutes: 1)));

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
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
          const Text(
            'تصفية وتصدير',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),

          // الرينج الحالى + زر اختيار
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.brown.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.brown.shade100),
                  ),
                  child: Text(
                    '$dispStart  →  $dispEnd',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range),
                label: const Text('اختيار المدى'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _apply, // ✅ يقفل الشيت تلقائياً
                  icon: const Icon(Icons.filter_alt),
                  label: const Text('تطبيق'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busyExport
                      ? null
                      : _exportCsv, // ✅ يقفل الشيت تلقائياً
                  icon: _busyExport
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_download),
                  label: const Text('تصدير Excel (CSV)'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
