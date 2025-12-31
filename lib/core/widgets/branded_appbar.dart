import 'package:flutter/material.dart';
import 'package:elfouad_admin/core/app_strings.dart';
import 'package:elfouad_admin/presentation/home/nav_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BrandedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final bool showHome;

  const BrandedAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = false,
    this.showHome = false,
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
          leading: showHome
              ? IconButton(
                  icon: const Icon(Icons.home_rounded, color: Colors.white),
                  onPressed: () =>
                      context.read<NavCubit>().setTab(AppTab.home),
                  tooltip: AppStrings.tabHome,
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
