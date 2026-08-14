// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gallery_filter_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$filteredGalleryHash() => r'd54cd5d9d35b20d70abf9d62a37e4f7565b04020';

/// See also [filteredGallery].
@ProviderFor(filteredGallery)
final filteredGalleryProvider = AutoDisposeProvider<List<GalleryItem>>.internal(
  filteredGallery,
  name: r'filteredGalleryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$filteredGalleryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FilteredGalleryRef = AutoDisposeProviderRef<List<GalleryItem>>;
String _$galleryFilterNotifierHash() =>
    r'19b853d97fdcfe19851c49c37620a8095cee9453';

/// See also [GalleryFilterNotifier].
@ProviderFor(GalleryFilterNotifier)
final galleryFilterNotifierProvider =
    AutoDisposeNotifierProvider<
      GalleryFilterNotifier,
      GalleryFilterState
    >.internal(
      GalleryFilterNotifier.new,
      name: r'galleryFilterNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$galleryFilterNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$GalleryFilterNotifier = AutoDisposeNotifier<GalleryFilterState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
