import 'dart:convert';
import 'package:cryptography/cryptography.dart';

void main() async {
  final cipher = AesGcm.with256bits();
  final secretKey = await cipher.newSecretKey();

  final dataBytes = utf8.encode('{"hello":"world"}');
  final nonce = cipher.newNonce();
  final box = await cipher.encrypt(
    dataBytes,
    secretKey: secretKey,
    nonce: nonce,
  );
  // ignore: avoid_print
  print('Encrypted successfully: ${box.cipherText.length} bytes');
}
