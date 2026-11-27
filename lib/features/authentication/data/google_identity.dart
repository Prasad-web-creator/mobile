import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleIdentity {
  static Future<void>? _initialized;
  static const _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static bool get isSupported => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          (defaultTargetPlatform == TargetPlatform.iOS && _iosClientId.isNotEmpty));

  static Future<String?> requestIdToken(String serverClientId) async {
    final signIn = GoogleSignIn.instance;
    await (_initialized ??= signIn.initialize(
      serverClientId: serverClientId,
      clientId: defaultTargetPlatform == TargetPlatform.iOS ? _iosClientId : null,
    ));
    try {
      final account = await signIn.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }
}
