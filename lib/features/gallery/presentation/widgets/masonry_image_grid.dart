import 'package:artio/core/design_system/app_animations.dart';
import 'package:artio/core/design_system/app_spacing.dart';
import 'package:artio/core/services/storage_url_service.dart';
import 'package:artio/features/gallery/domain/entities/gallery_item.dart';
import 'package:artio/features/gallery/presentation/widgets/interactive_gallery_item.dart';
import 'package:artio/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

/// Masonry image grid with staggered appear animations,
/// shimmer placeholders, and timeline grouping.
class MasonryImageGrid extends ConsumerStatefulWidget {
  const MasonryImageGrid({
    required this.items,
    required this.onItemTap,
    this.showWatermark = false,
    super.key,
  });
  final List<GalleryItem> items;
  final void Function(GalleryItem item, int index) onItemTap;
  final bool showWatermark;

  @override
  ConsumerState<MasonryImageGrid> createState() => _MasonryImageGridState();
}

class _MasonryImageGridState extends ConsumerState<MasonryImageGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _staggerController;
  // Stable list instance: only replaced when item URLs actually change.
  // Prevents gallerySignedUrlsProvider from re-firing on every rebuild
  // because Riverpod family uses List identity equality.
  late List<String> _paths;

  static List<String> _extractPaths(List<GalleryItem> items) =>
      items.map((i) => i.imageUrl).whereType<String>().toList();

  static bool _pathsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _formatGroupDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) {
      return 'Today';
    } else if (itemDate == yesterday) {
      return 'Yesterday';
    } else {
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final monthStr = months[date.month - 1];
      if (date.year == now.year) {
        return '$monthStr ${date.day}';
      } else {
        return '$monthStr ${date.day}, ${date.year}';
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _paths = _extractPaths(widget.items);
    _staggerController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds:
            AppAnimations.normal.inMilliseconds +
            (AppAnimations.staggerDelay.inMilliseconds *
                widget.items.length.clamp(0, AppAnimations.maxStaggerItems)),
      ),
    )..forward();
  }

  @override
  void didUpdateWidget(MasonryImageGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) {
      final newPaths = _extractPaths(widget.items);
      if (!_pathsEqual(_paths, newPaths)) {
        // Only update state (and invalidate provider) when URLs actually changed
        setState(() => _paths = newPaths);
      }
    }
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final int crossAxisCount;
    if (width > 900) {
      crossAxisCount = 4;
    } else if (width > 600) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 2;
    }

    // Nhóm các items theo Ngày
    final groupedItems = <String, List<GalleryItem>>{};
    for (final item in widget.items) {
      final key = _formatGroupDate(item.createdAt.toLocal());
      groupedItems.putIfAbsent(key, () => []).add(item);
    }

    // Batch-resolve all image URLs in a single Supabase API call.
    // _paths is a stable instance — only changes when item URLs actually change.
    final signedUrlMap =
        ref.watch(gallerySignedUrlsProvider(_paths)).valueOrNull ?? {};

    final slivers = <Widget>[];

    for (final entry in groupedItems.entries) {
      final groupTitle = entry.key;
      final groupList = entry.value;

      // 1. Tiêu đề Phân nhóm Ngày & 2. Staggered Grid cho nhóm đó
      slivers
        ..add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.lg,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                groupTitle,
                style: TextStyle(
                  color: isDark ? AppColors.textPrimary : Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        )
        ..add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
            childCount: groupList.length,
            itemBuilder: (context, index) {
              final item = groupList[index];
              final globalIndex = widget.items.indexOf(item);

              // Stagger animation based on global index
              const maxItems = AppAnimations.maxStaggerItems;
              final clampedItemCount = widget.items.length.clamp(0, maxItems);
              final staggerIndex = globalIndex.clamp(0, maxItems);
              final totalStaggerTime =
                  AppAnimations.staggerDelay.inMilliseconds * clampedItemCount;
              final totalDuration =
                  AppAnimations.normal.inMilliseconds + totalStaggerTime;
              final startFrac =
                  (staggerIndex * AppAnimations.staggerDelay.inMilliseconds) /
                  totalDuration;
              final endFrac =
                  (staggerIndex * AppAnimations.staggerDelay.inMilliseconds +
                      AppAnimations.normal.inMilliseconds) /
                  totalDuration;

              final itemAnim = Tween<double>(begin: 0, end: 1).animate(
                CurvedAnimation(
                  parent: _staggerController,
                  curve: Interval(
                    startFrac.clamp(0.0, 1.0),
                    endFrac.clamp(0.0, 1.0),
                    curve: AppAnimations.defaultCurve,
                  ),
                ),
              );

              return AnimatedBuilder(
                animation: itemAnim,
                builder: (context, child) => Opacity(
                  opacity: itemAnim.value,
                  child: Transform.scale(
                    scale: 0.9 + (0.1 * itemAnim.value),
                    child: child,
                  ),
                ),
                child: InteractiveGalleryItem(
                  item: item,
                  onTap: () => widget.onItemTap(item, globalIndex),
                  showWatermark: widget.showWatermark,
                  resolvedUrl: item.imageUrl != null
                      ? signedUrlMap[item.imageUrl]
                      : null,
                ),
              );
            },
          ),
        ),
      );
    }

    // Khoảng trống dưới cùng
    slivers.add(
      const SliverToBoxAdapter(
        child: SizedBox(height: AppSpacing.xl),
      ),
    );

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: slivers,
    );
  }
}
