import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/sso_session.dart';

/// A full screen WebView the student uses to complete their school's
/// single sign on login by hand, including any two factor step, the
/// same manual, one time login the desktop tool's own visible browser
/// window asks for.
///
/// Once [isSignedIn] recognizes the url this WebView has navigated to
/// as meaning the login finished, this screen reads back the cookies
/// the platform's own cookie store collected during that login and
/// returns a SsoSession to whoever pushed this screen. A session
/// cookie is normally marked http only, invisible to JavaScript's
/// document.cookie, but that restriction only applies to script
/// running inside the page; the platform's native cookie manager,
/// which WebViewCookieManager reads from here, is not limited by it,
/// so it can still see the cookie.
///
/// Closing this screen without a successful login (for example the
/// student backs out) returns null instead.
class SsoWebviewLoginScreen extends StatefulWidget {
  /// Which identity provider key the resulting session is saved under,
  /// see schoolSsoSessionKey in source_config.dart.
  final String sessionKey;

  /// Where the WebView starts, normally a source's general login
  /// redirector url, the same kind of entry point the desktop tool's
  /// own login flow uses.
  final Uri entryUrl;

  /// True once the WebView has navigated to a url that means the
  /// student is signed in, for example back on the source's own
  /// dashboard rather than still sitting on a login page.
  final bool Function(Uri url) isSignedIn;

  /// Which host's cookies to capture once signed in, normally the
  /// entry url's own host, the service that ultimately sets the
  /// session cookie once the identity provider hands control back to
  /// it.
  final String cookieDomain;

  const SsoWebviewLoginScreen({
    super.key,
    required this.sessionKey,
    required this.entryUrl,
    required this.isSignedIn,
    required this.cookieDomain,
  });

  @override
  State<SsoWebviewLoginScreen> createState() => _SsoWebviewLoginScreenState();
}

class _SsoWebviewLoginScreenState extends State<SsoWebviewLoginScreen> {
  late final WebViewController _controller;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: _onPageFinished),
      )
      ..loadRequest(widget.entryUrl);
  }

  Future<void> _onPageFinished(String url) async {
    if (_completing) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !widget.isSignedIn(uri)) return;

    _completing = true;
    final session = await _captureSession();
    if (mounted) Navigator.of(context).pop(session);
  }

  /// Reads back every cookie the platform's cookie store holds for
  /// [SsoWebviewLoginScreen.cookieDomain] and joins them into a single
  /// raw Cookie request header value, the same shape a plain network
  /// request needs to present a session to a server.
  Future<SsoSession> _captureSession() async {
    final cookies = await WebViewCookieManager().getCookies(
      domain: Uri.https(widget.cookieDomain, '/'),
    );
    final cookieHeader = cookies.map((c) => '${c.name}=${c.value}').join('; ');
    return SsoSession(
      key: widget.sessionKey,
      cookieHeader: cookieHeader,
      capturedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
