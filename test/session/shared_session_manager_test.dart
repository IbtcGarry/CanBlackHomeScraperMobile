import 'package:flutter_test/flutter_test.dart';
import 'package:canblackhomescraper_mobile/models/sso_session.dart';
import 'package:canblackhomescraper_mobile/session/shared_session_manager.dart';
import 'package:canblackhomescraper_mobile/storage/secure_credential_store.dart';

void main() {
  group('SharedSessionManager', () {
    test('returns null when nothing has been saved for a key yet', () async {
      final manager = SharedSessionManager(InMemoryCredentialStore());
      expect(await manager.loadSession('school sso'), isNull);
    });

    test('round trips a saved session', () async {
      final manager = SharedSessionManager(InMemoryCredentialStore());
      final captured = DateTime.utc(2026, 9, 24, 12);
      await manager.saveSession(
        SsoSession(
          key: 'school sso',
          cookieHeader: 'JSESSIONID=abc123; other=value',
          capturedAt: captured,
        ),
      );

      final loaded = await manager.loadSession('school sso');
      expect(loaded, isNotNull);
      expect(loaded!.cookieHeader, 'JSESSIONID=abc123; other=value');
      expect(loaded.capturedAt, captured);
    });

    test('sessions under different keys do not affect each other', () async {
      final manager = SharedSessionManager(InMemoryCredentialStore());
      await manager.saveSession(
        SsoSession(
          key: 'school sso',
          cookieHeader: 'shared session cookie',
          capturedAt: DateTime.utc(2026, 9, 24),
        ),
      );
      await manager.saveSession(
        SsoSession(
          key: 'gradescope only',
          cookieHeader: 'gradescope only cookie',
          capturedAt: DateTime.utc(2026, 9, 24),
        ),
      );

      expect(
        (await manager.loadSession('school sso'))?.cookieHeader,
        'shared session cookie',
      );
      expect(
        (await manager.loadSession('gradescope only'))?.cookieHeader,
        'gradescope only cookie',
      );
    });

    test('clearSession removes a saved session entirely', () async {
      final manager = SharedSessionManager(InMemoryCredentialStore());
      await manager.saveSession(
        SsoSession(
          key: 'school sso',
          cookieHeader: 'a cookie',
          capturedAt: DateTime.utc(2026, 9, 24),
        ),
      );

      await manager.clearSession('school sso');

      expect(await manager.loadSession('school sso'), isNull);
    });

    test('saving a new session under the same key replaces the old one', () async {
      final manager = SharedSessionManager(InMemoryCredentialStore());
      final key = 'school sso';
      await manager.saveSession(
        SsoSession(
          key: key,
          cookieHeader: 'first cookie',
          capturedAt: DateTime.utc(2026, 9, 24, 9),
        ),
      );
      await manager.saveSession(
        SsoSession(
          key: key,
          cookieHeader: 'second cookie',
          capturedAt: DateTime.utc(2026, 9, 24, 10),
        ),
      );

      final loaded = await manager.loadSession(key);
      expect(loaded!.cookieHeader, 'second cookie');
      expect(loaded.capturedAt, DateTime.utc(2026, 9, 24, 10));
    });
  });
}
