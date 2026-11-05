import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

const _charset =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';

/// A random one-time value for Sign in with Apple. Apple gets its SHA-256, Supabase gets the raw value and checks the
/// two match, so a stolen identity token cannot be replayed.
String newAppleNonce([int length = 32, Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(
    length,
    (_) => _charset[r.nextInt(_charset.length)],
  ).join();
}

String sha256Hex(String input) => sha256.convert(utf8.encode(input)).toString();
