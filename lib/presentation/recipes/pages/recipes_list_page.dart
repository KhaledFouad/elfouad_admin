import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/home/nav_state.dart';
import 'package:elfouad_admin/presentation/inventory/bloc/inventory_cubit.dart';
import 'package:elfouad_admin/presentation/recipes/bloc/recipes_cubit.dart';
import 'package:elfouad_admin/presentation/recipes/models/recipe_price_cost.dart';
import 'package:elfouad_admin/presentation/recipes/utils/recipes_utils.dart';
import 'package:elfouad_admin/presentation/recipes/widgets/recipe_edit_sheet.dart';
import 'package:elfouad_admin/presentation/recipes/widgets/recipe_prepare_sheet.dart';
import 'package:elfouad_admin/presentation/recipes/pages/recipe_prep_log_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';

const String _recipesGatePassword = '1825';

class RecipesListPage extends StatefulWidget {
  const RecipesListPage({super.key});

  @override
  State<RecipesListPage> createState() => _RecipesListPageState();
}

class _RecipesListPageState extends State<RecipesListPage>
    with WidgetsBindingObserver {
  static bool _unlockedOnce = false;
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureUnlocked());
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _deleteRecipe(String id, String displayName) async {
    final cubit = context.read<RecipesCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppStrings.deleteRecipeTitle),
        content: Text(AppStrings.deleteRecipeConfirm(displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await cubit.deleteRecipe(id);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(AppStrings.recipeDeleted(displayName))),
    );
  }

  void _openEdit([String? recipeId]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<InventoryCubit>(),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: RecipeEditSheet(recipeId: recipeId),
        ),
      ),
    );
  }

  void _openPrepare(String recipeId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RecipePrepareSheet(recipeId: recipeId),
      ),
    );
  }

  void _openPrepLog() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecipePrepLogPage()),
    );
  }

  Future<void> _ensureUnlocked() async {
    if (_unlockedOnce || _unlocking || !mounted) return;
    _unlocking = true;
    final ok = await _openPasswordGate();
    _unlocking = false;
    if (!mounted) return;
    if (ok) {
      _unlockedOnce = true;
      return;
    }
    context.read<NavCubit>().setTab(AppTab.home);
  }

  Future<bool> _openPasswordGate() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _RecipePasswordGate()),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RecipesCubit>().state;
    final breakpoints = ResponsiveBreakpoints.of(context);
    final isPhone = breakpoints.smallerThan(TABLET);
    final isWide = breakpoints.largerThan(TABLET);
    final contentMaxWidth = isWide ? 1100.0 : double.infinity;
    final horizontalPadding = isPhone ? 10.0 : 16.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
            child: AppBar(
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: const Icon(Icons.home_rounded, color: Colors.white),
                onPressed: () => context.read<NavCubit>().setTab(AppTab.home),
                tooltip: AppStrings.tabHome,
              ),
              title: const Text(
                AppStrings.recipesTitle,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 35,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: AppStrings.recipePrepLogTitle,
                  onPressed: _openPrepLog,
                ),
              ],
              elevation: 8,
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5D4037), Color(0xFF795548)],
                  ),
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'recipes_fab',
          onPressed: () => _openEdit(),
          icon: const Icon(Icons.add),
          label: const Text(AppStrings.newRecipeTitle),
        ),
        body: Builder(
          builder: (context) {
            if (state.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null) {
              return Center(
                child: Text(AppStrings.loadFailedSimple(state.error!)),
              );
            }
            if (state.items.isEmpty) {
              return const Center(child: Text(AppStrings.noRecipesYet));
            }

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    100,
                  ),
                  itemCount: state.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final item = state.items[i];
                    final comps = item.components;
                    final title = item.title;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.brown.shade100),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsetsDirectional.only(
                          start: 12,
                          end: 8,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          12,
                          0,
                          12,
                          12,
                        ),
                        title: Text(
                          title.isEmpty ? AppStrings.unnamedLabel : title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          AppStrings.componentsCount(comps.length),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: item.isComplete ? Colors.green : Colors.red,
                          ),
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: comps.map((c) {
                                final t = c.variant.isEmpty
                                    ? c.name
                                    : '${c.name} - ${c.variant}';
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(' '),
                                    Text(
                                      AppStrings.componentPercentSummary(
                                        t,
                                        c.percent,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 8),

                          FutureBuilder<RecipePriceCost>(
                            future: calcRecipePriceCost(item),
                            builder: (ctx, ps) {
                              if (ps.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  child: LinearProgressIndicator(minHeight: 2),
                                );
                              }
                              final pc =
                                  ps.data ??
                                  const RecipePriceCost(
                                    pricePerKg: 0,
                                    costPerKg: 0,
                                  );
                              return Row(
                                children: [
                                  const Icon(Icons.payments_outlined, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppStrings.pricePerKgInline(pc.pricePerKg),
                                  ),
                                  const SizedBox(width: 18),
                                  const Icon(
                                    Icons.calculate_outlined,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppStrings.costPerKgInline(pc.costPerKg),
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  icon: const Icon(Icons.scale_outlined),
                                  label: const Text(
                                    AppStrings.prepareBlendLabel,
                                  ),
                                  onPressed: () => _openPrepare(item.id),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                tooltip: AppStrings.actionEdit,
                                icon: const Icon(Icons.edit),
                                onPressed: () => _openEdit(item.id),
                              ),
                              const SizedBox(width: 6),
                              IconButton.filledTonal(
                                tooltip: AppStrings.actionDelete,
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteRecipe(item.id, title),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RecipePasswordGate extends StatefulWidget {
  const _RecipePasswordGate();

  @override
  State<_RecipePasswordGate> createState() => _RecipePasswordGateState();
}

class _RecipePasswordGateState extends State<_RecipePasswordGate> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_busy) return;
    setState(() => _busy = true);
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _error = AppStrings.recipesPasswordHint;
        _busy = false;
      });
      return;
    }
    if (raw != _recipesGatePassword) {
      setState(() {
        _error = AppStrings.recipesPasswordWrong;
        _busy = false;
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.recipesPasswordTitle),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF5D4037), Color(0xFF795548)],
              ),
            ),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.lock, size: 56, color: Colors.brown),
                      const SizedBox(height: 12),
                      const Text(
                        AppStrings.recipesPasswordSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _controller,
                        autofocus: true,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: AppStrings.recipesPasswordHint,
                          errorText: _error,
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _check(),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _check,
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(AppStrings.actionUnlock),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed:
                            _busy ? null : () => Navigator.of(context).pop(false),
                        child: const Text(AppStrings.actionCancel),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
