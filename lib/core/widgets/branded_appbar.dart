import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BrandedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final double height;

  const BrandedAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = false,
    this.height = 72,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: preferredSize,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        child: AppBar(
          systemOverlayStyle:
              SystemUiOverlayStyle.light, // أيقونات شريط الحالة باللون الفاتح
          automaticallyImplyLeading: showBack,
          centerTitle: true,
          elevation: 6,
          shadowColor: Colors.black26,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent, // يمنع طبقة الـ M3 الرمادية
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: Colors.white,
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: actions,
          flexibleSpace: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF543824), // بني غامق
                  Color(0xFFC49A6C), // بيج فاتح
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
