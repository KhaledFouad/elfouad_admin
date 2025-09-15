import 'package:flutter/material.dart';

class TopLists extends StatelessWidget {
  const TopLists({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: Card(child: SizedBox(height: 120, child: Center(child: Text('Top 5 Drinks (قريبًا)'))))),
        Expanded(child: Card(child: SizedBox(height: 120, child: Center(child: Text('Top 5 Beans (قريبًا)'))))),
      ],
    );
  }
}