import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/flatpak_certificates_io.dart';

void main() {
  test('ignores host bundle outside Flatpak', () {
    loadFlatpakHostCertificates(
      environment: {'HAPPY_HOST_CA_BUNDLE': '/does/not/exist'},
    );
  });

  test('keeps default trust when no host export is available', () {
    loadFlatpakHostCertificates(environment: {'FLATPAK_ID': 'test'});
  });

  test('imports a host CA and still rejects untrusted TLS', () async {
    // The test binding installs a mock HttpClient that never performs a TLS
    // handshake; this test needs the real one.
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previousOverrides);
    final directory = Directory.systemTemp.createTempSync('happy-ca-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final certificate = '${directory.path}/certificate.pem';
    final key = '${directory.path}/key.pem';
    final result = await Process.run('openssl', [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-days',
      '1',
      '-subj',
      '/CN=localhost',
      '-addext',
      'subjectAltName=DNS:localhost,IP:127.0.0.1',
      '-addext',
      'extendedKeyUsage=serverAuth',
      '-keyout',
      key,
      '-out',
      certificate,
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    final serverContext = SecurityContext()
      ..useCertificateChain(certificate)
      ..usePrivateKey(key);
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      serverContext,
    );
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response.write('trusted');
      request.response.close();
    });
    final uri = Uri.parse('https://127.0.0.1:${server.port}/');
    final context = SecurityContext(withTrustedRoots: false);
    final untrusted = HttpClient(context: context);
    addTearDown(() => untrusted.close(force: true));
    await expectLater(
      untrusted.getUrl(uri),
      throwsA(isA<HandshakeException>()),
    );

    final export = File(certificate).copySync('${directory.path}/host.pem');
    loadFlatpakHostCertificates(
      environment: {
        'FLATPAK_ID': 'io.github.denysvitali.happy_flutter',
        'HAPPY_HOST_CA_BUNDLE': export.path,
      },
      context: context,
    );
    expect(export.existsSync(), isFalse);
    final trusted = HttpClient(context: context);
    addTearDown(() => trusted.close(force: true));
    final response = await (await trusted.getUrl(uri)).close();
    expect(response.statusCode, HttpStatus.ok);
    await response.drain<void>();

    // A separate context still rejects this certificate: no global bypass.
    final other = HttpClient(context: SecurityContext(withTrustedRoots: false));
    addTearDown(() => other.close(force: true));
    await expectLater(other.getUrl(uri), throwsA(isA<HandshakeException>()));
  }, skip: !Platform.isLinux);

  test('rejects and removes a malformed export', () {
    final directory = Directory.systemTemp.createTempSync('happy-ca-bad-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final export = File('${directory.path}/host.pem')..writeAsStringSync('bad');
    expect(
      () => loadFlatpakHostCertificates(
        environment: {
          'FLATPAK_ID': 'test',
          'HAPPY_HOST_CA_BUNDLE': export.path,
        },
        context: SecurityContext(withTrustedRoots: false),
      ),
      throwsA(isA<TlsException>()),
    );
    expect(export.existsSync(), isFalse);
  }, skip: !Platform.isLinux);
}
