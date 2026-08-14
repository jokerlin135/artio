import 'package:artio/features/gallery/domain/entities/gallery_item.dart';
import 'package:artio/features/gallery/presentation/providers/gallery_provider.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gallery_filter_provider.freezed.dart';
part 'gallery_filter_provider.g.dart';

enum GalleryStatusFilter {
  all,
  completed,
  generating,
  failed,
}

@freezed
class GalleryFilterState with _$GalleryFilterState {
  const factory GalleryFilterState({
    @Default('') String searchQuery,
    @Default(false) bool onlyFavorites,
    @Default(GalleryStatusFilter.all) GalleryStatusFilter statusFilter,
  }) = _GalleryFilterState;
}

@riverpod
class GalleryFilterNotifier extends _$GalleryFilterNotifier {
  @override
  GalleryFilterState build() {
    return const GalleryFilterState();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleOnlyFavorites() {
    state = state.copyWith(onlyFavorites: !state.onlyFavorites);
  }

  void setOnlyFavorites({required bool onlyFavorites}) {
    state = state.copyWith(onlyFavorites: onlyFavorites);
  }

  void setStatusFilter(GalleryStatusFilter filter) {
    state = state.copyWith(statusFilter: filter);
  }

  void reset() {
    state = const GalleryFilterState();
  }
}

@riverpod
List<GalleryItem> filteredGallery(FilteredGalleryRef ref) {
  final galleryAsync = ref.watch(galleryStreamProvider);
  final filter = ref.watch(galleryFilterNotifierProvider);

  return galleryAsync.maybeWhen(
    data: (items) {
      final filteredList = items.where((item) {
        // 1. Search Query filter
        if (filter.searchQuery.isNotEmpty) {
          final query = filter.searchQuery.toLowerCase();
          final matchesPrompt = item.prompt?.toLowerCase().contains(query) ?? false;
          final matchesTemplate = item.templateName.toLowerCase().contains(query);
          if (!matchesPrompt && !matchesTemplate) return false;
        }

        // 2. Favorites filter
        if (filter.onlyFavorites && !item.isFavorite) {
          return false;
        }

        // 3. Status filter
        switch (filter.statusFilter) {
          case GalleryStatusFilter.all:
            break;
          case GalleryStatusFilter.completed:
            if (item.status != GenerationStatus.completed) return false;
          case GalleryStatusFilter.generating:
            if (item.status != GenerationStatus.pending &&
                item.status != GenerationStatus.generating &&
                item.status != GenerationStatus.processing) {
              return false;
            }
          case GalleryStatusFilter.failed:
            if (item.status != GenerationStatus.failed) return false;
        }

        return true;
      }).toList();

      return filteredList..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    },
    orElse: () => [],
  );
}
