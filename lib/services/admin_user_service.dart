import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../app/firebase_config.dart';

class AdminAccountCreationResult {
  const AdminAccountCreationResult({
    required this.uid,
    required this.invitationSent,
  });

  final String uid;
  final bool invitationSent;
}

class AdminUserServiceException implements Exception {
  const AdminUserServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class AdminUserService {
  Future<AdminAccountCreationResult> createAccount({
    required String email,
    required String displayName,
    required Future<void> Function(String uid) createProfile,
  });

  /// Reenvia o e-mail de ativação (definição de senha). Não altera a sessão.
  Future<void> sendActivation(String email);
}

class FirebaseAdminUserService implements AdminUserService {
  FirebaseAdminUserService({FirebaseAuth? auth}) : _auth = auth;

  final FirebaseAuth? _auth;

  @override
  Future<void> sendActivation(String email) async {
    try {
      await (_auth ?? FirebaseAuth.instance)
          .sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (error) {
      throw AdminUserServiceException(_messageFor(error));
    }
  }

  @override
  Future<AdminAccountCreationResult> createAccount({
    required String email,
    required String displayName,
    required Future<void> Function(String uid) createProfile,
  }) async {
    final auth = await _secondaryAuth();

    User? createdUser;
    var profileCreated = false;
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: _temporaryPassword(),
      );
      createdUser = credential.user;
      if (createdUser == null) {
        throw const AdminUserServiceException(
          'Não foi possível recuperar a conta criada.',
        );
      }
      await createdUser.updateDisplayName(displayName.trim());
      await createProfile(createdUser.uid);
      profileCreated = true;

      var invitationSent = true;
      try {
        await auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
      } catch (_) {
        invitationSent = false;
      }
      return AdminAccountCreationResult(
        uid: createdUser.uid,
        invitationSent: invitationSent,
      );
    } on FirebaseAuthException catch (error) {
      await _rollback(createdUser, profileCreated);
      throw AdminUserServiceException(_messageFor(error));
    } catch (error) {
      await _rollback(createdUser, profileCreated);
      rethrow;
    } finally {
      // A instância secundária é reutilizada (não é apagada): no Android,
      // apagar um FirebaseApp secundário quebra a próxima instância secundária.
      await auth.signOut().catchError((_) {});
    }
  }

  static const _secondaryAppName = 'caminho-azul-admin-accounts';
  static FirebaseAuth? _cachedSecondaryAuth;

  /// Instância secundária e isolada do Auth: criar contas nela não altera a
  /// sessão do administrador na instância principal.
  Future<FirebaseAuth> _secondaryAuth() async {
    final cached = _cachedSecondaryAuth;
    if (cached != null) return cached;
    final existing =
        Firebase.apps.where((app) => app.name == _secondaryAppName).firstOrNull;
    final app = existing ??
        await Firebase.initializeApp(
          name: _secondaryAppName,
          options: Firebase.app().options,
        );
    final auth = FirebaseAuth.instanceFor(app: app);
    await configureFirebaseAuth(auth);
    return _cachedSecondaryAuth = auth;
  }

  /// Desfaz a identidade criada quando o perfil não foi gravado. Se não for
  /// possível, orienta a remoção manual (falha parcial Auth × Firestore).
  Future<void> _rollback(User? createdUser, bool profileCreated) async {
    if (createdUser == null || profileCreated) return;
    try {
      await createdUser.delete();
    } catch (_) {
      throw const AdminUserServiceException(
        'A conta foi criada no Authentication, mas o perfil não foi salvo e não '
        'foi possível desfazer automaticamente. Remova a conta no Console do '
        'Firebase antes de tentar novamente.',
      );
    }
  }

  String _temporaryPassword() {
    const alphabet =
        r'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%';
    final random = Random.secure();
    final characters = <String>[
      'A',
      'a',
      '2',
      '!',
      ...List.generate(
        28,
        (_) => alphabet[random.nextInt(alphabet.length)],
      ),
    ];
    characters.shuffle(random);
    return characters.join();
  }

  String _messageFor(FirebaseAuthException error) => switch (error.code) {
        'email-already-in-use' => 'Este e-mail já está cadastrado.',
        'invalid-email' => 'Digite um e-mail válido.',
        'weak-password' =>
          'A política de senhas do Firebase recusou a senha temporária.',
        'operation-not-allowed' =>
          'O login por e-mail e senha não está habilitado no Firebase.',
        'network-request-failed' =>
          'Não foi possível conectar ao Firebase. Verifique sua internet.',
        'too-many-requests' =>
          'Muitas tentativas foram realizadas. Aguarde e tente novamente.',
        _ => 'Não foi possível criar o usuário. Tente novamente.',
      };
}
