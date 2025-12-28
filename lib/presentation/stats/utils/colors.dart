import 'package:flutter/material.dart';

const kBrown = Color(0xFF543824);
const kBeige = Color(0xFFC49A6C);

Color kBeigeSoft([double o = .12]) {
  final alpha = (o.clamp(0.0, 1.0) * 255).round();
  return kBeige.withAlpha(alpha);
}
