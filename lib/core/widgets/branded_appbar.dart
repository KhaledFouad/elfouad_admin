import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/app_strings.dart';

class BrandedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final bool showMenu;

  const BrandedAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = false,
    this.showMenu = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: preferredSize,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        child: AppBar(
          automaticallyImplyLeading: false,
          leading: showMenu
              ? Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () {
                      final drawer = AwesomeDrawerBar.of(ctx);
                      if (drawer != null) {
                        drawer.toggle();
                        return;
                      }
                      final scaffold = Scaffold.maybeOf(ctx);
                      if (scaffold != null) {
                        scaffold.openDrawer();
                      }
                    },
                    tooltip: AppStrings.menuTooltip,
                  ),
                )
              : (showBack
                    ? IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.maybePop(context),
                      )
                    : null),
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: Colors.white,
          ),
          title: Text(title),
          centerTitle: true,
          elevation: 4,
          backgroundColor: Colors.transparent,
          actions: actions,
          flexibleSpace: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF543824), Color(0xFFC49A6C)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
