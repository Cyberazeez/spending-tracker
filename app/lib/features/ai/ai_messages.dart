import '../../l10n/app_localizations.dart';

/// Plain words for why an AI call did not give an answer.
String aiReasonText(AppLocalizations t, String? reason) => switch (reason) {
  'disabled' => t.aiReasonDisabled,
  'no_key' => t.aiReasonNoKey,
  'cap_reached' => t.aiReasonCap,
  'offline' => t.aiReasonOffline,
  _ => t.aiReasonFailed,
};
