import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// The AI switch from More. Off until the owner turns it on.
final aiEnabledProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(dataRepositoryProvider).aiEnabled(),
  retry: (_, _) => null,
);
