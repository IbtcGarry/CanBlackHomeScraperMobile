import 'package:flutter_test/flutter_test.dart';
import 'package:canblackhomescraper_mobile/storage/secure_credential_store.dart';

void main() {
  group('InMemoryCredentialStore', () {
    test('returns null for a key that was never written', () async {
      final store = InMemoryCredentialStore();
      expect(await store.read(CredentialKeys.canvasToken), isNull);
    });

    test('round trips a written value', () async {
      final store = InMemoryCredentialStore();
      await store.write(CredentialKeys.canvasToken, 'a token value');
      expect(await store.read(CredentialKeys.canvasToken), 'a token value');
    });

    test('a later write replaces the earlier value', () async {
      final store = InMemoryCredentialStore();
      await store.write(CredentialKeys.canvasToken, 'first');
      await store.write(CredentialKeys.canvasToken, 'second');
      expect(await store.read(CredentialKeys.canvasToken), 'second');
    });

    test('delete removes a written value', () async {
      final store = InMemoryCredentialStore();
      await store.write(CredentialKeys.canvasToken, 'a token value');
      await store.delete(CredentialKeys.canvasToken);
      expect(await store.read(CredentialKeys.canvasToken), isNull);
    });

    test('different keys do not affect each other', () async {
      final store = InMemoryCredentialStore();
      await store.write(CredentialKeys.canvasToken, 'token value');
      await store.write(CredentialKeys.canvasIcalUrl, 'feed url value');

      expect(await store.read(CredentialKeys.canvasToken), 'token value');
      expect(await store.read(CredentialKeys.canvasIcalUrl), 'feed url value');
    });
  });
}
