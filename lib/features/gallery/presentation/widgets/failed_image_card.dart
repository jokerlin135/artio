import 'package:artio/core/design_system/app_dimensions.dart';
import 'package:artio/core/design_system/app_spacing.dart';
import 'package:artio/features/gallery/presentation/providers/gallery_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FailedImageCard extends ConsumerWidget {
  const FailedImageCard({required this.jobId, super.key});
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: AppDimensions.cardRadius,
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5)
            : null,
      ),
      padding: AppSpacing.cardPadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
            size: AppDimensions.iconLg,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Generation Failed',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onErrorContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () {
              ref
                  .read(galleryActionsNotifierProvider.notifier)
                  .retryGeneration(jobId);
            },
            icon: Icon(
              Icons.refresh,
              size: AppDimensions.iconSm,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            label: Text(
              'Retry',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              minimumSize: const Size(
                AppDimensions.touchTargetMin,
                AppDimensions.touchTargetMin,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
