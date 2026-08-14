import 'package:artio/core/design_system/app_spacing.dart';
import 'package:artio/core/state/auth_view_model_provider.dart';
import 'package:artio/core/state/subscription_state_provider.dart';
import 'package:artio/core/utils/app_exception_mapper.dart';
import 'package:artio/features/gallery/presentation/providers/gallery_filter_provider.dart';
import 'package:artio/features/gallery/presentation/providers/gallery_provider.dart';
import 'package:artio/features/gallery/presentation/widgets/empty_gallery_state.dart';
import 'package:artio/features/gallery/presentation/widgets/masonry_image_grid.dart';
import 'package:artio/features/gallery/presentation/widgets/shimmer_grid.dart';
import 'package:artio/routing/routes/app_routes.dart';
import 'package:artio/shared/widgets/error_state_widget.dart';
import 'package:artio/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final galleryAsync = ref.watch(galleryStreamProvider);
    final filteredItems = ref.watch(filteredGalleryProvider);
    final filterState = ref.watch(galleryFilterNotifierProvider);

    final isLoggedIn = ref
        .watch(authViewModelProvider)
        .maybeMap(authenticated: (_) => true, orElse: () => false);
    final showWatermark = ref
        .watch(subscriptionNotifierProvider)
        .maybeWhen(data: (status) => status.isFree, orElse: () => true);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Gallery'),
        actions: [
          if (filterState.searchQuery.isNotEmpty ||
              filterState.onlyFavorites ||
              filterState.statusFilter != GalleryStatusFilter.all)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                _searchController.clear();
                ref.read(galleryFilterNotifierProvider.notifier).reset();
              },
              tooltip: 'Reset Filters',
            ),
        ],
      ),
      body: galleryAsync.when(
        loading: () => const ShimmerGrid(),
        error: (error, stackTrace) => ErrorStateWidget(
          message: AppExceptionMapper.toUserMessage(error),
          onRetry: () => ref.invalidate(galleryStreamProvider),
        ),
        data: (rawItems) {
          if (rawItems.isEmpty) {
            return EmptyGalleryState(isLoggedIn: isLoggedIn);
          }

          return Column(
            children: [
              // ── Search & Filters ──────────────────────────────────────
              _buildSearchAndFilters(context, filterState),

              // ── Grid content ─────────────────────────────────────────
              Expanded(
                child: filteredItems.isEmpty
                    ? _buildNoResultsState()
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(galleryStreamProvider);
                        },
                        child: MasonryImageGrid(
                          items: filteredItems,
                          showWatermark: showWatermark,
                          onItemTap: (item, index) {
                            if (item.imageUrl == null) return;
                            GalleryImageRoute(
                              $extra: GalleryImageExtra(
                                items: filteredItems,
                                initialIndex: index,
                              ),
                            ).push<void>(context);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context, GalleryFilterState filter) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkBackground.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.white05 : Colors.grey[200]!,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Search Bar ───────────────────────────────────────────────
          TextField(
            controller: _searchController,
            onChanged: (val) => ref
                .read(galleryFilterNotifierProvider.notifier)
                .setSearchQuery(val),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Search prompts or templates...',
              hintStyle: TextStyle(
                color: isDark ? AppColors.textMuted : Colors.grey[400],
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: isDark ? AppColors.textSecondary : Colors.grey[500],
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        ref
                            .read(galleryFilterNotifierProvider.notifier)
                            .setSearchQuery('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? AppColors.white05 : Colors.grey[100],
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Filter Chips ─────────────────────────────────────────────
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Filter: Favorites
                _FilterChip(
                  label: '❤️ Favorites',
                  selected: filter.onlyFavorites,
                  onSelected: (_) => ref
                      .read(galleryFilterNotifierProvider.notifier)
                      .toggleOnlyFavorites(),
                ),
                const SizedBox(width: AppSpacing.xs),

                // Filter Status: All
                _FilterChip(
                  label: 'All',
                  selected: filter.statusFilter == GalleryStatusFilter.all &&
                      !filter.onlyFavorites,
                  onSelected: (_) {
                    ref
                        .read(galleryFilterNotifierProvider.notifier)
                        .setStatusFilter(GalleryStatusFilter.all);
                    ref
                        .read(galleryFilterNotifierProvider.notifier)
                        .setOnlyFavorites(onlyFavorites: false);
                  },
                ),
                const SizedBox(width: AppSpacing.xs),

                // Filter Status: Completed
                _FilterChip(
                  label: '🟢 Completed',
                  selected: filter.statusFilter == GalleryStatusFilter.completed,
                  onSelected: (_) => ref
                      .read(galleryFilterNotifierProvider.notifier)
                      .setStatusFilter(GalleryStatusFilter.completed),
                ),
                const SizedBox(width: AppSpacing.xs),

                // Filter Status: Generating
                _FilterChip(
                  label: '🔄 Generating',
                  selected: filter.statusFilter == GalleryStatusFilter.generating,
                  onSelected: (_) => ref
                      .read(galleryFilterNotifierProvider.notifier)
                      .setStatusFilter(GalleryStatusFilter.generating),
                ),
                const SizedBox(width: AppSpacing.xs),

                // Filter Status: Failed
                _FilterChip(
                  label: '❌ Failed',
                  selected: filter.statusFilter == GalleryStatusFilter.failed,
                  onSelected: (_) => ref
                      .read(galleryFilterNotifierProvider.notifier)
                      .setStatusFilter(GalleryStatusFilter.failed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_search_rounded,
            size: 64,
            color: isDark ? AppColors.white20 : Colors.grey[300],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No matching creations found',
            style: TextStyle(
              color: isDark ? AppColors.textPrimary : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              color: isDark ? AppColors.textMuted : Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected
              ? Colors.white
              : isDark
                  ? AppColors.textSecondary
                  : Colors.grey[700],
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: AppColors.primaryCta,
      backgroundColor: isDark ? AppColors.white05 : Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? Colors.transparent
              : isDark
                  ? AppColors.white10
                  : Colors.grey[300]!,
        ),
      ),
      showCheckmark: false,
    );
  }
}
