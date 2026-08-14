import 'dart:async';

import 'package:artio/core/design_system/app_animations.dart';
import 'package:artio/core/design_system/app_dimensions.dart';
import 'package:artio/core/design_system/app_spacing.dart';
import 'package:artio/core/services/storage_url_service.dart';
import 'package:artio/core/state/subscription_state_provider.dart';
import 'package:artio/features/gallery/domain/entities/gallery_item.dart';
import 'package:artio/features/gallery/domain/providers/gallery_repository_provider.dart';
import 'package:artio/features/gallery/presentation/constants/gallery_strings.dart';
import 'package:artio/features/gallery/presentation/pages/image_viewer_action_helper.dart';
import 'package:artio/features/gallery/presentation/providers/gallery_provider.dart';
import 'package:artio/features/gallery/presentation/widgets/failed_image_card.dart';
import 'package:artio/shared/widgets/retry_text_button.dart';
import 'package:artio/shared/widgets/watermark_overlay.dart';
import 'package:artio/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

/// Gallery item with long-press scale effect.
class InteractiveGalleryItem extends ConsumerStatefulWidget {
  const InteractiveGalleryItem({
    required this.item,
    required this.onTap,
    this.showWatermark = false,

    /// Pre-resolved signed URL from a batch call. When provided, skips the
    /// per-item [signedStorageUrlProvider] to avoid N+1 API requests.
    this.resolvedUrl,
    super.key,
  });

  final GalleryItem item;
  final VoidCallback onTap;
  final bool showWatermark;
  final String? resolvedUrl;

  @override
  ConsumerState<InteractiveGalleryItem> createState() =>
      _InteractiveGalleryItemState();
}

class _InteractiveGalleryItemState extends ConsumerState<InteractiveGalleryItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  /// Incremented on retry to force [CachedNetworkImage] recreation via
  /// [ValueKey]. More reliable than depending on setState alone.
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: AppAnimations.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.95).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: AppAnimations.defaultCurve,
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: () => _showContextMenu(context),
        onLongPressStart: (_) => _pressController.forward(),
        onLongPressEnd: (_) => _pressController.reverse(),
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        child: _buildGalleryItem(context, widget.item),
      ),
    );
  }

  Widget _buildGalleryItem(BuildContext context, GalleryItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Handle Failed Status
    if (item.status == GenerationStatus.failed) {
      return AspectRatio(
        aspectRatio: 1,
        child: FailedImageCard(jobId: item.jobId),
      );
    }

    // Handle Pending/Processing Status
    if (item.status == GenerationStatus.pending ||
        item.status == GenerationStatus.generating ||
        item.status == GenerationStatus.processing) {
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
            borderRadius: AppDimensions.cardRadius,
            border: isDark
                ? Border.all(color: AppColors.white10, width: 0.5)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: AppDimensions.iconMd,
                height: AppDimensions.iconMd,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryCta.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.status == GenerationStatus.pending
                    ? 'Pending'
                    : 'Generating',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.textMuted
                      : AppColors.textMutedLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Handle Completed Status with Image
    if (item.imageUrl != null) {
      // Use pre-resolved URL from batch call if available,
      // otherwise fall back to per-item signed URL resolution.
      final signedUrlAsync = widget.resolvedUrl != null
          ? AsyncValue.data(widget.resolvedUrl)
          : ref.watch(signedStorageUrlProvider(item.imageUrl!));

      return signedUrlAsync.when(
        loading: () => AspectRatio(
          aspectRatio: 1,
          child: Shimmer.fromColors(
            baseColor: isDark ? AppColors.shimmerBase : const Color(0xFFE8EAF0),
            highlightColor: isDark
                ? AppColors.shimmerHighlight
                : const Color(0xFFF3F4F8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppDimensions.cardRadius,
              ),
            ),
          ),
        ),
        error: (_, __) => AspectRatio(
          aspectRatio: 1,
          child: _GalleryErrorPlaceholder(
            isDark: isDark,
            onRetry: () => ref.invalidate(
              signedStorageUrlProvider(item.imageUrl!),
            ),
          ),
        ),
        data: (signedUrl) {
          if (signedUrl == null) {
            return AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: AppDimensions.cardRadius,
                child: ColoredBox(
                  color: isDark
                      ? AppColors.darkSurface2
                      : AppColors.lightSurface2,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 32,
                    color: isDark
                        ? AppColors.textMuted
                        : AppColors.textMutedLight,
                  ),
                ),
              ),
            );
          }
          return Stack(
            children: [
              WatermarkOverlay(
                showWatermark: widget.showWatermark,
                child: Hero(
                  tag: 'gallery-image-${item.id}',
                  child: ClipRRect(
                    borderRadius: AppDimensions.cardRadius,
                    child: ColoredBox(
                      // White canvas so transparent-background PNGs
                      // (e.g. background-removal results) display cleanly.
                      color: Colors.white,
                      child: CachedNetworkImage(
                      key: ValueKey(_retryCount),
                      imageUrl: signedUrl,
                      // Use the stable storage path as cache key so the cached
                      // image survives signed URL expiry (signed URL rotates,
                      // but the content is the same file).
                      cacheKey: item.imageUrl,
                      placeholder: (context, url) => AspectRatio(
                        aspectRatio: 1,
                        child: Shimmer.fromColors(
                          baseColor: isDark
                              ? AppColors.shimmerBase
                              : const Color(0xFFE8EAF0),
                          highlightColor: isDark
                              ? AppColors.shimmerHighlight
                              : const Color(0xFFF3F4F8),
                          child: Container(color: Colors.white),
                        ),
                      ),
                      errorWidget: (context, url, error) => AspectRatio(
                        aspectRatio: 1,
                        child: _GalleryErrorPlaceholder(
                          isDark: isDark,
                          onRetry: () {
                            CachedNetworkImage.evictFromCache(
                              item.imageUrl!,
                            );
                            setState(() => _retryCount++);
                            if (widget.resolvedUrl == null) {
                              ref.invalidate(
                                signedStorageUrlProvider(item.imageUrl!),
                              );
                            }
                            // When resolvedUrl != null: _retryCount++
                            // changes ValueKey -> CachedNetworkImage
                            // fully recreated. Cache was evicted,
                            // so re-fetch happens naturally.
                          },
                        ),
                      ),
                      fit: BoxFit.cover,
                    ),
                    ), // ColoredBox
                  ),
                ),
              ),
              _buildFavoriteButton(context, item),
            ],
          );
        },
      );
    }

    // Fallback
    return const SizedBox.shrink();
  }

  Widget _buildFavoriteButton(BuildContext context, GalleryItem item) {
    return Positioned(
      top: AppSpacing.xs,
      right: AppSpacing.xs,
      child: GestureDetector(
        onTap: () {
          ref.read(galleryActionsNotifierProvider.notifier).toggleFavorite(
                item.id,
                isFavorite: !item.isFavorite,
              );
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1, end: item.isFavorite ? 1.2 : 1),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.4),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  item.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: item.isFavorite ? Colors.red : Colors.white,
                  size: 16,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    _pressController.reverse(); // Đảm bảo scale được đưa về 1.0 khi menu hiện lên.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface2 : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thanh kéo (Drag Indicator)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.white20 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Ảnh preview nhỏ + Prompt mờ
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    if (item.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: CachedNetworkImage(
                            imageUrl: widget.resolvedUrl ?? item.imageUrl!,
                            fit: BoxFit.cover,
                            cacheKey: item.imageUrl,
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.templateName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.prompt ?? 'No prompt',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? AppColors.textMuted : Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Nút thích
              ListTile(
                leading: Icon(
                  item.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: item.isFavorite ? Colors.red : (isDark ? Colors.white70 : Colors.black87),
                ),
                title: Text(item.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  ref.read(galleryActionsNotifierProvider.notifier).toggleFavorite(
                        item.id,
                        isFavorite: !item.isFavorite,
                      );
                },
              ),
              // Nút tải về (chỉ khi completed)
              if (item.status == GenerationStatus.completed && item.imageUrl != null) ...[
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Download to Gallery'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(_handleDownload(context, item));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded),
                  title: const Text('Share Creation'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(_handleShare(context, item));
                  },
                ),
              ],
              // Nút xóa (soft delete)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Delete Creation', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  ref.read(galleryActionsNotifierProvider.notifier).softDeleteImage(item.jobId);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleDownload(BuildContext context, GalleryItem item) async {
    if (item.imageUrl == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Downloading image...'),
        duration: Duration(seconds: 1),
      ),
    );
    
    try {
      final repository = ref.read(galleryRepositoryProvider);
      final isFree = ref.read(subscriptionNotifierProvider).maybeWhen(
            data: (status) => status.isFree,
            orElse: () => true,
          );
          
      final location = await ImageViewerActionHelper.download(
        repository,
        item.imageUrl!,
        isFreeUser: isFree,
      );
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to $location')),
      );
    } on Object catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save image')),
      );
    }
  }

  Future<void> _handleShare(BuildContext context, GalleryItem item) async {
    if (item.imageUrl == null) return;
    try {
      final repository = ref.read(galleryRepositoryProvider);
      final isFree = ref.read(subscriptionNotifierProvider).maybeWhen(
            data: (status) => status.isFree,
            orElse: () => true,
          );
          
      await ImageViewerActionHelper.share(
        repository,
        item.imageUrl!,
        isFreeUser: isFree,
      );
    } on Object catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to share image')),
      );
    }
  }
}

/// Shared error placeholder for gallery grid items.
/// Displays broken image icon, error text, and retry button.
class _GalleryErrorPlaceholder extends StatelessWidget {
  const _GalleryErrorPlaceholder({
    required this.isDark,
    required this.onRetry,
  });

  final bool isDark;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppDimensions.cardRadius,
      child: ColoredBox(
        color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_rounded,
              size: 32,
              color: isDark ? AppColors.textMuted : AppColors.textMutedLight,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              GalleryStrings.failedToLoad,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color:
                    isDark ? AppColors.textMuted : AppColors.textMutedLight,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            RetryTextButton(onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
