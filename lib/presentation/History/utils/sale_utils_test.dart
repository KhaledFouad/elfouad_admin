// ignore_for_file: depend_on_referenced_packages

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/History/models/sale_component.dart';
import 'package:elfouad_admin/presentation/History/utils/sale_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaleUtils Tests', () {
    group('Date and Time Utils', () {
      test('parseDate handles Timestamps, DateTime, and Strings', () {
        final now = DateTime.now();
        final timestamp = Timestamp.fromDate(now);
        final dateString = now.toIso8601String();

        expect(parseDate(timestamp), equals(now));
        expect(parseDate(now), equals(now));
        expect(parseDate(dateString), equals(now));
        expect(
          parseDate('invalid-date'),
          equals(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal()),
        );
      });

      test('computeEffectiveTime logic is correct', () {
        final createdAt = DateTime(2023, 1, 1, 10);
        final settledAt = DateTime(2023, 1, 1, 12);

        // Paid and settled
        expect(
          computeEffectiveTime(
            createdAt: createdAt,
            settledAt: settledAt,
            isDeferred: false,
            isPaid: true,
          ),
          equals(settledAt),
        );

        // Not deferred, not paid (regular sale)
        expect(
          computeEffectiveTime(
            createdAt: createdAt,
            settledAt: null,
            isDeferred: false,
            isPaid: false,
          ),
          equals(createdAt),
        );

        // Deferred and unpaid -> should be now at a specific hour
        final now = DateTime.now();
        final expectedDeferredTime = DateTime(now.year, now.month, now.day, 5);
        expect(
          computeEffectiveTime(
            createdAt: createdAt,
            settledAt: null,
            isDeferred: true,
            isPaid: false,
          ),
          equals(expectedDeferredTime),
        );

        // Deferred but paid
        expect(
          computeEffectiveTime(
            createdAt: createdAt,
            settledAt: settledAt,
            isDeferred: true,
            isPaid: true,
          ),
          equals(settledAt),
        );
      });

      test('formatTime returns hh:mm format', () {
        final dt = DateTime(2023, 5, 1, 7, 9);
        expect(formatTime(dt), equals('07:09'));
      });
    });

    group('detectSaleType', () {
      test('detects "drink" type correctly', () {
        expect(detectSaleType({'drink_id': '123'}), equals('drink'));
        expect(detectSaleType({'drink_name': 'Espresso'}), equals('drink'));
      });

      test('detects "single" type correctly', () {
        expect(detectSaleType({'single_id': '456'}), equals('single'));
        expect(
          detectSaleType({
            'items': [
              {'grams': 100},
            ],
          }),
          equals('single'),
        );
      });

      test('detects "ready_blend" type correctly', () {
        expect(detectSaleType({'blend_id': '789'}), equals('ready_blend'));
      });

      test('detects "custom_blend" type correctly', () {
        expect(
          detectSaleType({
            'components': [
              {'name': 'Brazil', 'grams': 50},
            ],
          }),
          equals('custom_blend'),
        );
      });

      test('detects "extra" type correctly', () {
        expect(detectSaleType({'type': 'extra'}), equals('extra'));
        expect(detectSaleType({'extra_id': '101'}), equals('extra'));
      });

      test('returns "unknown" for unidentified types', () {
        expect(detectSaleType({'foo': 'bar'}), equals('unknown'));
      });
    });

    group('extractComponents', () {
      test('extracts from "components" list if present', () {
        final data = {
          'components': [
            {
              'name': 'Component A',
              'variant': 'V1',
              'grams': 100.0,
              'qty': 0.0,
              'unit': 'g',
              'line_total_price': 50.0,
              'line_total_cost': 25.0,
            },
          ],
        };
        final components = extractComponents(data, 'custom_blend');
        expect(components, isA<List<SaleComponent>>());
        expect(components.length, 1);
        expect(components.first.name, 'Component A');
        expect(components.first.grams, 100.0);
      });

      test('extracts from "items" list as fallback', () {
        final data = {
          'items': [
            {
              'item_name': 'Item B',
              'roast': 'Dark',
              'weight': 250.0,
              'count': 0.0,
              'unit': 'g',
              'total_price': 120.0,
              'total_cost': 60.0,
            },
          ],
        };
        final components = extractComponents(data, 'invoice');
        expect(components.length, 1);
        expect(components.first.name, 'Item B');
        expect(components.first.variant, 'Dark');
        expect(components.first.grams, 250.0);
      });

      test('creates component for "drink" type from root fields', () {
        final data = {
          'drink_name': 'Turkish Coffee',
          'roast': 'Light',
          'quantity': 2.0,
          'unit': 'cup',
          'unit_price': 15.0,
          'unit_cost': 8.0,
        };
        final components = extractComponents(data, 'drink');
        expect(components.length, 1);
        expect(components.first.name, 'Turkish Coffee');
        expect(components.first.quantity, 2.0);
        expect(components.first.lineTotalPrice, 30.0); // 2 * 15
        expect(components.first.lineTotalCost, 16.0); // 2 * 8
      });

      test('creates component for "single" type from root fields', () {
        final data = {
          'name': 'Colombian',
          'variant': 'Washed',
          'grams': 250.0,
          'total_price': 150.0,
          'total_cost': 70.0,
        };
        final components = extractComponents(data, 'single');
        expect(components.length, 1);
        expect(components.first.name, 'Colombian');
        expect(components.first.grams, 250.0);
        expect(components.first.lineTotalPrice, 150.0);
      });

      test('returns empty list for unknown type with no component lists', () {
        final data = {'product': 'Some other product'};
        final components = extractComponents(data, 'unknown');
        expect(components, isEmpty);
      });
    });

    group('buildTitleLine', () {
      test('formats title for "drink"', () {
        final data = {'quantity': 2, 'drink_name': 'Espresso'};
        expect(buildTitleLine(data, 'drink'), 'مشروب - 2 Espresso');
      });

      test('formats title for "invoice"', () {
        final data = {
          'items': [{}, {}],
          'total_price': 125.5,
        };
        expect(
          buildTitleLine(data, 'invoice'),
          AppStrings.saleTitleInvoice(2, '125.50'),
        );
      });

      test('formats title for "invoice" with number', () {
        final data = {'invoice_number': 3};
        expect(
          buildTitleLine(data, 'invoice'),
          AppStrings.saleTitleInvoiceNumber(3),
        );
      });

      test('formats title for "single"', () {
        final data = {'grams': 250, 'name': 'Yemeni'};
        expect(buildTitleLine(data, 'single'), 'صنف منفرد - 250 جم Yemeni');
      });

      test('formats title for "custom_blend"', () {
        expect(buildTitleLine({}, 'custom_blend'), 'توليفة العميل');
      });
    });
  });
}
