import 'package:artio/features/gallery/domain/entities/gallery_item.dart';
import 'package:artio/features/gallery/presentation/providers/gallery_filter_provider.dart';
import 'package:artio/features/gallery/presentation/providers/gallery_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GalleryFilterProvider', () {
    late List<GalleryItem> testItems;

    setUp(() {
      testItems = [
        GalleryItem(
          id: '1',
          jobId: 'job-1',
          userId: 'user-1',
          templateId: 'temp-1',
          templateName: 'Cyberpunk Portrait',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          status: GenerationStatus.completed,
          imageUrl: 'url-1',
          prompt: 'A cool cyberpunk warrior',
        ),
        GalleryItem(
          id: '2',
          jobId: 'job-2',
          userId: 'user-1',
          templateId: 'temp-2',
          templateName: 'Anime Avatar',
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
          status: GenerationStatus.completed,
          imageUrl: 'url-2',
          prompt: 'Cute anime girl',
          isFavorite: true,
        ),
        GalleryItem(
          id: '3',
          jobId: 'job-3',
          userId: 'user-1',
          templateId: 'temp-1',
          templateName: 'Cyberpunk Landscape',
          createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
          status: GenerationStatus.pending,
          prompt: 'Neon streets of Tokyo',
        ),
        GalleryItem(
          id: '4',
          jobId: 'job-4',
          userId: 'user-1',
          templateId: 'temp-3',
          templateName: 'Oil Painting',
          createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
          status: GenerationStatus.failed,
          prompt: 'A beautiful lake',
          isFavorite: true,
        ),
      ];
    });

    ProviderContainer createContainer(List<GalleryItem> items) {
      return ProviderContainer(
        overrides: [
          galleryStreamProvider.overrideWith((ref) => Stream.value(items)),
        ],
      );
    }

    test('initial state has default filter values', () {
      final container = createContainer(testItems);
      addTearDown(container.dispose);

      final filter = container.read(galleryFilterNotifierProvider);
      expect(filter.searchQuery, '');
      expect(filter.onlyFavorites, false);
      expect(filter.statusFilter, GalleryStatusFilter.all);
    });

    test('filteredGallery returns all items ordered by newest by default', () async {
      final container = createContainer(testItems);
      addTearDown(container.dispose);

      // Wait for stream to emit
      await container.read(galleryStreamProvider.future);

      final filtered = container.read(filteredGalleryProvider);
      expect(filtered.length, 4);
      // Item 3 is created 1 minute ago (newest) -> should be first
      expect(filtered[0].id, '3');
      // Item 4 is created 20 minutes ago (oldest) -> should be last
      expect(filtered[3].id, '4');
    });

    test('filters by search query (prompt and template name)', () async {
      final container = createContainer(testItems);
      addTearDown(container.dispose);

      await container.read(galleryStreamProvider.future);

      // 1. Search by template name
      container
          .read(galleryFilterNotifierProvider.notifier)
          .setSearchQuery('cyberpunk');
      var filtered = container.read(filteredGalleryProvider);
      expect(filtered.length, 2);
      expect(filtered.every((item) => item.templateName.contains('Cyberpunk')), true);

      // 2. Search by prompt
      container
          .read(galleryFilterNotifierProvider.notifier)
          .setSearchQuery('girl');
      filtered = container.read(filteredGalleryProvider);
      expect(filtered.length, 1);
      expect(filtered[0].id, '2');
    });

    test('filters only favorites', () async {
      final container = createContainer(testItems);
      addTearDown(container.dispose);

      await container.read(galleryStreamProvider.future);

      container.read(galleryFilterNotifierProvider.notifier).toggleOnlyFavorites();

      final filtered = container.read(filteredGalleryProvider);
      expect(filtered.length, 2);
      expect(filtered.every((item) => item.isFavorite), true);
    });

    test('filters by generation status', () async {
      final container = createContainer(testItems);
      addTearDown(container.dispose);

      await container.read(galleryStreamProvider.future);

      // 1. Only Completed
      container
          .read(galleryFilterNotifierProvider.notifier)
          .setStatusFilter(GalleryStatusFilter.completed);
      var filtered = container.read(filteredGalleryProvider);
      expect(filtered.length, 2);
      expect(filtered.every((item) => item.status == GenerationStatus.completed), true);

      // 2. Only Generating
      container
          .read(galleryFilterNotifierProvider.notifier)
          .setStatusFilter(GalleryStatusFilter.generating);
      filtered = container.read(filteredGalleryProvider);
      expect(filtered.length, 1);
      expect(filtered[0].id, '3');

      // 3. Only Failed
      container
          .read(galleryFilterNotifierProvider.notifier)
          .setStatusFilter(GalleryStatusFilter.failed);
      filtered = container.read(filteredGalleryProvider);
      expect(filtered.length, 1);
      expect(filtered[0].id, '4');
    });
  });
}
