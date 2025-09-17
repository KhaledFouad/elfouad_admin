import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:flutter/material.dart';

class BrandedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  const BrandedAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: AppBar(
        // أهم سطرين عشان يختفي أي Tint أبيض ويبان الجRADIENT
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,

        elevation: 6,
        shadowColor: Colors.black26,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'القائمة',
          icon: const Icon(Icons.menu, color: Colors.brown),
          onPressed: () => AwesomeDrawerBar.of(context)?.toggle(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: Colors.brown,
          ),
        ),
        actions: actions,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3C2717), // بني غامق
                Color(0xFF966D41), // بني فاتح/بيج
              ],
            ),
          ),
        ),
      ),
    );
  }
}
