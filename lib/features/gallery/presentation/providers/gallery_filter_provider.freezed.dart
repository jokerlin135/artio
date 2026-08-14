// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gallery_filter_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$GalleryFilterState {
  String get searchQuery => throw _privateConstructorUsedError;
  bool get onlyFavorites => throw _privateConstructorUsedError;
  GalleryStatusFilter get statusFilter => throw _privateConstructorUsedError;

  /// Create a copy of GalleryFilterState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GalleryFilterStateCopyWith<GalleryFilterState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GalleryFilterStateCopyWith<$Res> {
  factory $GalleryFilterStateCopyWith(
    GalleryFilterState value,
    $Res Function(GalleryFilterState) then,
  ) = _$GalleryFilterStateCopyWithImpl<$Res, GalleryFilterState>;
  @useResult
  $Res call({
    String searchQuery,
    bool onlyFavorites,
    GalleryStatusFilter statusFilter,
  });
}

/// @nodoc
class _$GalleryFilterStateCopyWithImpl<$Res, $Val extends GalleryFilterState>
    implements $GalleryFilterStateCopyWith<$Res> {
  _$GalleryFilterStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GalleryFilterState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? searchQuery = null,
    Object? onlyFavorites = null,
    Object? statusFilter = null,
  }) {
    return _then(
      _value.copyWith(
            searchQuery: null == searchQuery
                ? _value.searchQuery
                : searchQuery // ignore: cast_nullable_to_non_nullable
                      as String,
            onlyFavorites: null == onlyFavorites
                ? _value.onlyFavorites
                : onlyFavorites // ignore: cast_nullable_to_non_nullable
                      as bool,
            statusFilter: null == statusFilter
                ? _value.statusFilter
                : statusFilter // ignore: cast_nullable_to_non_nullable
                      as GalleryStatusFilter,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GalleryFilterStateImplCopyWith<$Res>
    implements $GalleryFilterStateCopyWith<$Res> {
  factory _$$GalleryFilterStateImplCopyWith(
    _$GalleryFilterStateImpl value,
    $Res Function(_$GalleryFilterStateImpl) then,
  ) = __$$GalleryFilterStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String searchQuery,
    bool onlyFavorites,
    GalleryStatusFilter statusFilter,
  });
}

/// @nodoc
class __$$GalleryFilterStateImplCopyWithImpl<$Res>
    extends _$GalleryFilterStateCopyWithImpl<$Res, _$GalleryFilterStateImpl>
    implements _$$GalleryFilterStateImplCopyWith<$Res> {
  __$$GalleryFilterStateImplCopyWithImpl(
    _$GalleryFilterStateImpl _value,
    $Res Function(_$GalleryFilterStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GalleryFilterState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? searchQuery = null,
    Object? onlyFavorites = null,
    Object? statusFilter = null,
  }) {
    return _then(
      _$GalleryFilterStateImpl(
        searchQuery: null == searchQuery
            ? _value.searchQuery
            : searchQuery // ignore: cast_nullable_to_non_nullable
                  as String,
        onlyFavorites: null == onlyFavorites
            ? _value.onlyFavorites
            : onlyFavorites // ignore: cast_nullable_to_non_nullable
                  as bool,
        statusFilter: null == statusFilter
            ? _value.statusFilter
            : statusFilter // ignore: cast_nullable_to_non_nullable
                  as GalleryStatusFilter,
      ),
    );
  }
}

/// @nodoc

class _$GalleryFilterStateImpl implements _GalleryFilterState {
  const _$GalleryFilterStateImpl({
    this.searchQuery = '',
    this.onlyFavorites = false,
    this.statusFilter = GalleryStatusFilter.all,
  });

  @override
  @JsonKey()
  final String searchQuery;
  @override
  @JsonKey()
  final bool onlyFavorites;
  @override
  @JsonKey()
  final GalleryStatusFilter statusFilter;

  @override
  String toString() {
    return 'GalleryFilterState(searchQuery: $searchQuery, onlyFavorites: $onlyFavorites, statusFilter: $statusFilter)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GalleryFilterStateImpl &&
            (identical(other.searchQuery, searchQuery) ||
                other.searchQuery == searchQuery) &&
            (identical(other.onlyFavorites, onlyFavorites) ||
                other.onlyFavorites == onlyFavorites) &&
            (identical(other.statusFilter, statusFilter) ||
                other.statusFilter == statusFilter));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, searchQuery, onlyFavorites, statusFilter);

  /// Create a copy of GalleryFilterState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GalleryFilterStateImplCopyWith<_$GalleryFilterStateImpl> get copyWith =>
      __$$GalleryFilterStateImplCopyWithImpl<_$GalleryFilterStateImpl>(
        this,
        _$identity,
      );
}

abstract class _GalleryFilterState implements GalleryFilterState {
  const factory _GalleryFilterState({
    final String searchQuery,
    final bool onlyFavorites,
    final GalleryStatusFilter statusFilter,
  }) = _$GalleryFilterStateImpl;

  @override
  String get searchQuery;
  @override
  bool get onlyFavorites;
  @override
  GalleryStatusFilter get statusFilter;

  /// Create a copy of GalleryFilterState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GalleryFilterStateImplCopyWith<_$GalleryFilterStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
