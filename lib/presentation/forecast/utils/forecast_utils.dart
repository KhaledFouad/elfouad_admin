import 'package:elfouad_admin/core/utils/app_strings.dart';
import '../../stats/utils/op_day.dart';

class BeanDailySeries {
  BeanDailySeries({
    required this.key,
    required this.name,
    required this.type,
    required this.dailyGrams,
  });

  final String key;
  final String name;
  final String type;
  final List<double> dailyGrams;

  double get totalGrams => dailyGrams.fold<double>(0.0, (sum, g) => sum + g);
}

class ForecastSeriesStats {
  const ForecastSeriesStats({
    required this.totalGrams,
    required this.forecastGrams,
    required this.avgDailyForecast,
  });

  final double totalGrams;
  final double forecastGrams;
  final double avgDailyForecast;
}

Map<String, BeanDailySeries> buildBeanDailySeries(
  List<Map<String, dynamic>> data, {
  required DateTime startUtc,
  required DateTime endUtc,
  required int analysisDays,
}) {
  final baseDay = opDayKeyUtc(startUtc);
  final out = <String, _SeriesBuilder>{};

  for (final m in data) {
    final type = _resolveType(m);
    if (type != 'single' && type != 'ready_blend') continue;

    final grams = _num(m['grams'] ?? m['weight'] ?? m['total_grams']);
    if (grams <= 0) continue;

    final prodUtc = _productionUtc(m);
    if (!_inRangeUtc(prodUtc, startUtc, endUtc)) continue;

    final dayKey = opDayKeyUtc(prodUtc);
    final index = dayKey.difference(baseDay).inDays;
    if (index < 0 || index >= analysisDays) continue;

    final name = _buildBeanTitle(m);
    final key = normalizeKey(name);
    if (key.isEmpty) continue;

    final builder = out.putIfAbsent(
      key,
      () => _SeriesBuilder(name: name, type: type, length: analysisDays),
    );
    builder.add(index, grams);
  }

  final result = <String, BeanDailySeries>{};
  out.forEach((key, builder) {
    result[key] = builder.toSeries(key);
  });
  return result;
}

ForecastSeriesStats forecastSeries(List<double> series, int coverageDays) {
  final total = series.fold<double>(0.0, (sum, v) => sum + v);
  if (series.isEmpty || coverageDays <= 0) {
    return ForecastSeriesStats(
      totalGrams: total,
      forecastGrams: 0.0,
      avgDailyForecast: 0.0,
    );
  }

  final alpha = _alphaFor(series.length);
  final beta = _betaFor(alpha);

  double level = series.first;
  double trend = series.length > 1 ? series[1] - series[0] : 0.0;

  for (var i = 1; i < series.length; i++) {
    final value = series[i];
    final prevLevel = level;
    level = (alpha * value) + ((1 - alpha) * (level + trend));
    trend = (beta * (level - prevLevel)) + ((1 - beta) * trend);
  }

  double forecastTotal = 0.0;
  for (var m = 1; m <= coverageDays; m++) {
    final next = level + (trend * m);
    if (next > 0) {
      forecastTotal += next;
    }
  }

  final avg = forecastTotal / coverageDays;
  return ForecastSeriesStats(
    totalGrams: total,
    forecastGrams: forecastTotal,
    avgDailyForecast: avg,
  );
}

String normalizeKey(String input) {
  final cleaned = input.trim().toLowerCase();
  return cleaned.replaceAll(RegExp(r'\s+'), ' ');
}

String _buildBeanTitle(Map<String, dynamic> m) {
  final name =
      ('${m['name'] ?? m['single_name'] ?? m['blend_name'] ?? m['item_name'] ?? m['product_name'] ?? ''}')
          .trim();
  final variant = ('${m['variant'] ?? m['roast'] ?? m['size'] ?? ''}').trim();
  final label = name.isEmpty ? AppStrings.noNameLabel : name;
  return variant.isEmpty ? label : '$label - $variant';
}

String _resolveType(Map<String, dynamic> m) {
  final raw = (m['type'] ?? '').toString();
  if (raw.isNotEmpty) return raw;
  return (m['lines_type'] ?? '').toString();
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '0') ?? 0.0;
}

DateTime _asUtc(dynamic v) {
  if (v is DateTime) return v.toUtc();
  try {
    if (v != null && v.toDate != null) {
      final dt = v.toDate();
      if (dt is DateTime) return dt.toUtc();
    }
  } catch (_) {}
  if (v is num) {
    final raw = v.toInt();
    final ms = raw < 10000000000 ? raw * 1000 : raw;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }
  if (v is String) {
    return DateTime.tryParse(v)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

DateTime _productionUtc(Map<String, dynamic> m) {
  final orig = m['original_created_at'];
  final origUtc = orig == null ? null : _asUtc(orig);
  if (origUtc != null && origUtc.millisecondsSinceEpoch > 0) return origUtc;
  return _asUtc(m['created_at']);
}

bool _inRangeUtc(DateTime ts, DateTime start, DateTime end) {
  final afterOrEqual = ts.isAtSameMomentAs(start) || ts.isAfter(start);
  final before = ts.isBefore(end);
  return afterOrEqual && before;
}

double _alphaFor(int n) {
  final span = n < 10 ? n.toDouble() : 10 + (n - 10) * 0.2;
  final raw = (2 / (span + 1)) * 3;
  return raw.clamp(0.2, 0.6);
}

double _betaFor(double alpha) {
  return (alpha * 0.35).clamp(0.05, 0.35);
}

class _SeriesBuilder {
  _SeriesBuilder({required this.name, required this.type, required int length})
    : _series = List<double>.filled(length, 0.0);

  final String name;
  final String type;
  final List<double> _series;

  void add(int index, double grams) {
    if (index < 0 || index >= _series.length) return;
    _series[index] += grams;
  }

  BeanDailySeries toSeries(String key) {
    return BeanDailySeries(
      key: key,
      name: name,
      type: type,
      dailyGrams: List<double>.from(_series),
    );
  }
}
