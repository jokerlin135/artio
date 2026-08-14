// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ad_reward_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$adRewardNotifierHash() => r'968017cf5b1b16b97f058bf58e665f4d1a14917c';

/// Manages the nonce-verified ad-watch → server-reward → UI-refresh flow.
///
/// State is the number of ads remaining today (0–10).
///
/// Flow:
/// 1. Request one-time nonce from server (validates daily limit)
/// 2. Set SSV options on ad with nonce as custom_data
/// 3. Show the ad — user must complete it
/// 4. Claim reward with nonce — server validates nonce is valid + unexpired
///
/// Copied from [AdRewardNotifier].
@ProviderFor(AdRewardNotifier)
final adRewardNotifierProvider =
    AutoDisposeAsyncNotifierProvider<AdRewardNotifier, int>.internal(
      AdRewardNotifier.new,
      name: r'adRewardNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$adRewardNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AdRewardNotifier = AutoDisposeAsyncNotifier<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
