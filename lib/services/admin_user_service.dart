import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

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
}

class FirebaseAdminUserService implements AdminUserService {
  @override
  Future<AdminAccountCreationResult> createAccount({
    required String email,
    required String displayName,
    required Future<void> Function(String uid) createProfile,
  }) async {
    final app = await Firebase.initializeApp(
      name: 'admin-user-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      const host = String.fromEnvironment(
        'FIREBASE_EMULATOR_HOST',
        defaultValue: '10.0.2.2',
      );
      await auth.useAuthEmulator(host, 9099);
    }

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
      if (createdUser != null && !profileCreated) {
        await createdUser.delete().catchError((_) {});
      }
      throw AdminUserServiceException(_messageFor(error));
    } catch (error) {
      if (createdUser != null && !profileCreated) {
        await createdUser.delete().catchError((_) {});
      }
      rethrow;
    } finally {
      await auth.signOut().catchError((_) {});
      await app.delete().catchError((_) {});
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
