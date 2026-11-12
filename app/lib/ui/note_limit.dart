import 'package:flutter/services.dart';

/// Keeps a note within the database's 500-character limit, counted the way Postgres counts (code points), so a
/// note with emoji or Arabic marks never passes the field and then fails to save.
class NoteLimit extends TextInputFormatter {
  const NoteLimit([this.max = 500]);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.runes.length <= max) return newValue;
    // Keep the old text when the new one would be too long (typing past the end, or a long paste).
    return oldValue.text.runes.length <= max
        ? oldValue
        : newValue.copyWith(
            text: String.fromCharCodes(newValue.text.runes.take(max)),
            selection: TextSelection.collapsed(
              offset: String.fromCharCodes(newValue.text.runes.take(max))
                  .length,
            ),
          );
  }
}
