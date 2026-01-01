// ignore_for_file: unused_element

import 'dart:ui';

import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/home/nav_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _columnsFor(double width) {
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    return 2;
  }

  double _aspectFor(int columns) {
    if (columns >= 4) return 1.25;
    if (columns == 3) return 1.15;
    return 1.0;
  }

  Animation<double> _buildItemAnimation(int index, int total) {
    final start = 0.15 + (index / total) * 0.5;
    final end = (start + 0.5).clamp(0.0, 1.0).toDouble();
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final columns = _columnsFor(size.width);
    final heroAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: const _TopBar()),
              SliverToBoxAdapter(child: _HeroCard(animation: heroAnimation)),
              const SliverToBoxAdapter(
                child: _SectionHeader(title: AppStrings.homeQuickAccess),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: _aspectFor(columns),
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final feature = _features[index];
                    return _FeatureCard(
                      feature: feature,
                      animation: _buildItemAnimation(index, _features.length),
                    );
                  }, childCount: _features.length),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF543824),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(35),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.dashboard_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppStrings.tabHome,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF3E2A1C),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(200),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withAlpha(160)),
            ),
            child: const Text(
              AppStrings.appTitle,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Color(0xFF543824),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Animation<double> animation;
  const _HeroCard({required this.animation});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      const Color(0xFF543824).withAlpha(235),
                      const Color(0xFFC49A6C).withAlpha(220),
                    ],
                  ),
                  border: Border.all(color: Colors.white.withAlpha(90)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.homeTitle,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                AppStrings.homeSubtitle,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFF5E7D8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 125,
                          height: 90,
                          child: Center(
                            child: Image.asset(
                              'assets/Group8.png',
                              width: 70,
                              height: 70,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // const SizedBox(height: 14),
                    // const Wrap(
                    //   spacing: 8,
                    //   runSpacing: 8,
                    //   children: [
                    //     _HeroPill(
                    //       icon: Icons.receipt_long,
                    //       label: AppStrings.tabHistory,
                    //     ),
                    //     _HeroPill(
                    //       icon: Icons.stacked_line_chart,
                    //       label: AppStrings.tabStats,
                    //     ),
                    //     _HeroPill(
                    //       icon: Icons.inventory_2_outlined,
                    //       label: AppStrings.tabInventory,
                    //     ),
                    //   ],
                    // ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(0xFF3E2A1C),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final _HomeFeature feature;
  final Animation<double> animation;

  const _FeatureCard({required this.feature, required this.animation});

  @override
  Widget build(BuildContext context) {
    final softenedTop = Color.lerp(feature.gradient.first, Colors.white, 0.78)!;
    final softenedBottom = Color.lerp(
      feature.gradient.last,
      Colors.white,
      0.62,
    )!;
    final borderColor = feature.accent.withAlpha(70);

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(animation),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              Feedback.forTap(context);
              context.read<NavCubit>().setTab(feature.tab);
            },
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [softenedTop, softenedBottom],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(220),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Icon(
                            feature.icon,
                            color: feature.accent.withAlpha(220),
                            size: 25,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_back_rounded,
                          color: feature.accent.withAlpha(180),
                        ),
                      ],
                    ),
                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
                    Text(
                      feature.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3A271A),
                      ),
                    ),
                    // const SizedBox(height: 6),
                    // Text(
                    //   AppStrings.homeCardHint,
                    //   style: TextStyle(
                    //     fontSize: 12,
                    //     fontWeight: FontWeight.w600,
                    //     color: feature.accent.withAlpha(140),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeFeature {
  final AppTab tab;
  final String title;
  final IconData icon;
  final Color accent;
  final List<Color> gradient;

  const _HomeFeature({
    required this.tab,
    required this.title,
    required this.icon,
    required this.accent,
    required this.gradient,
  });
}

const _features = <_HomeFeature>[
  _HomeFeature(
    tab: AppTab.history,
    title: AppStrings.tabHistory,
    icon: Icons.receipt_long,
    accent: Color(0xFF7A4E2E),
    gradient: [Color(0xFFFFF3E8), Color(0xFFF3DDCB)],
  ),
  _HomeFeature(
    tab: AppTab.stats,
    title: AppStrings.tabStats,
    icon: Icons.stacked_line_chart,
    accent: Color(0xFF3E5C76),
    gradient: [Color(0xFFEAF1F8), Color(0xFFD7E3F2)],
  ),
  _HomeFeature(
    tab: AppTab.forecast,
    title: AppStrings.tabForecast,
    icon: Icons.auto_graph_outlined,
    accent: Color(0xFF2F7A6D),
    gradient: [Color(0xFFE8F6F2), Color(0xFFCFEADF)],
  ),
  _HomeFeature(
    tab: AppTab.inventory,
    title: AppStrings.tabInventory,
    icon: Icons.inventory_2_outlined,
    accent: Color(0xFF6C5B3E),
    gradient: [Color(0xFFF2EEE8), Color(0xFFE1D7C8)],
  ),
  _HomeFeature(
    tab: AppTab.stocktake,
    title: AppStrings.tabStocktake,
    icon: Icons.fact_check_outlined,
    accent: Color(0xFF3C6E71),
    gradient: [Color(0xFFE9F4F4), Color(0xFFD2E6E7)],
  ),
  _HomeFeature(
    tab: AppTab.edits,
    title: AppStrings.tabEdits,
    icon: Icons.edit_note_outlined,
    accent: Color(0xFF8A4B55),
    gradient: [Color(0xFFF8EDEF), Color(0xFFE9D1D6)],
  ),
  _HomeFeature(
    tab: AppTab.recipes,
    title: AppStrings.tabRecipes,
    icon: Icons.menu_book_outlined,
    accent: Color(0xFF4F6F52),
    gradient: [Color(0xFFEAF4EC), Color(0xFFD8E9DA)],
  ),
  _HomeFeature(
    tab: AppTab.expenses,
    title: AppStrings.tabExpenses,
    icon: Icons.account_balance_wallet_outlined,
    accent: Color(0xFF7B6D3F),
    gradient: [Color(0xFFF5F0E0), Color(0xFFE6D9B7)],
  ),
  // Hidden per request: remove Grind tile from home.
  // _HomeFeature(
  //   tab: AppTab.grind,
  //   title: AppStrings.tabGrind,
  //   icon: Icons.coffee_outlined,
  //   accent: Color(0xFF4C3B2A),
  //   gradient: [Color(0xFFF4EEE7), Color(0xFFE5D6C6)],
  // ),
];
