import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AccessProfile {
  escola,
  familia,
  saude,
  administracao;

  UserRole get requiredRole {
    return switch (this) {
      AccessProfile.escola => UserRole.school,
      AccessProfile.familia => UserRole.family,
      AccessProfile.saude => UserRole.health,
      AccessProfile.administracao => UserRole.administration,
    };
  }
}

enum UserRole {
  school('escola', 'Escola', legacyValues: {'school'}),
  family('familia', 'Família', legacyValues: {'family'}),
  health('saude', 'Saúde', legacyValues: {'health'}),
  administration('admin', 'Administração');

  const UserRole(this.value, this.label, {this.legacyValues = const {}});

  final String value;
  final String label;
  final Set<String> legacyValues;

  static UserRole? fromValue(String? value) {
    for (final role in values) {
      if (role.value == value || role.legacyValues.contains(value)) {
        return role;
      }
    }
    return null;
  }

  static UserRole? fromClaim(Object? value) {
    return value is String ? fromValue(value) : null;
  }
}

enum SchoolRole {
  teacher('professor', 'Professor'),
  leadership('direcao', 'Direção');

  const SchoolRole(this.value, this.label);

  final String value;
  final String label;

  static SchoolRole? fromValue(String? value) {
    for (final role in values) {
      if (role.value == value) return role;
    }
    return null;
  }
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.name,
    this.firstName,
    this.lastName,
    this.professionalId,
    this.schoolRole,
    this.active = true,
  });

  final String uid;
  final String email;
  final UserRole role;
  final String? name;
  final String? firstName;
  final String? lastName;
  final String? professionalId;
  final SchoolRole? schoolRole;
  final bool active;
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class AuthService {
  Future<AppUser> signIn({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail({
    required String email,
  });

  Stream<AppUser?> adminSessionChanges();

  Stream<AppUser?> sessionChanges();

  Future<void> signOut();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      await signOut();
      throw const AuthException('Nao foi possivel recuperar o usuario.');
    }

    return _loadUserProfile(user);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
  }) {
    return _firebaseAuth.sendPasswordResetEmail(
      email: email.trim().toLowerCase(),
    );
  }

  @override
  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }

  @override
  Stream<AppUser?> adminSessionChanges() {
    return _firebaseAuth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream<AppUser?>.value(null);
      }

      return _adminProfileSnapshots(user);
    });
  }

  @override
  Stream<AppUser?> sessionChanges() {
    return _firebaseAuth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream<AppUser?>.value(null);
      }
      return _firestore.collection('users').doc(user.uid).snapshots().asyncMap(
            (snapshot) => _appUserFromProfileSnapshot(
              user: user,
              snapshot: snapshot,
            ),
          );
    });
  }

  Stream<AppUser?> _adminProfileSnapshots(User user) async* {
    yield* _firestore.collection('users').doc(user.uid).snapshots().asyncMap(
      (snapshot) async {
        return _appUserFromProfileSnapshot(
          user: user,
          snapshot: snapshot,
          requireAdmin: true,
        );
      },
    );
  }

  Future<AppUser> _loadUserProfile(User user) async {
    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    final appUser = await _appUserFromProfileSnapshot(
      user: user,
      snapshot: snapshot,
    );
    try {
      await snapshot.reference.update({
        'lastAccessAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      // O registro de acesso não deve impedir um login válido.
    }
    return appUser;
  }

  Future<AppUser> _appUserFromProfileSnapshot({
    required User user,
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
    bool requireAdmin = false,
  }) async {
    if (!snapshot.exists) {
      await signOut();
      throw const AuthException(
        'Usuario sem perfil cadastrado. Entre em contato com a administração.',
      );
    }

    final data = snapshot.data();
    if (data == null) {
      await signOut();
      throw const AuthException(
        'Perfil de usuario incompleto. Entre em contato com a administração.',
      );
    }

    final active = data['active'];
    if (active != true) {
      await signOut();
      throw const AuthException(
        'Este acesso foi desativado. Entre em contato com a administração.',
      );
    }

    final role = UserRole.fromValue(data['role'] as String?);
    if (role == null) {
      await signOut();
      throw const AuthException(
        'A conta nao corresponde ao perfil selecionado.',
      );
    }

    if (requireAdmin && role != UserRole.administration) {
      await signOut();
      throw const AuthException(
        'A sessao administrativa nao e valida.',
      );
    }

    final schoolRole = role == UserRole.school
        ? SchoolRole.fromValue(data['schoolRole'] as String?) ??
            SchoolRole.teacher
        : null;
    return AppUser(
      uid: user.uid,
      email: user.email ?? (data['email'] as String? ?? ''),
      name: data['name'] as String?,
      firstName: data['firstName'] as String?,
      lastName: data['lastName'] as String?,
      professionalId: data['professionalId'] as String?,
      role: role,
      schoolRole: schoolRole,
      active: active,
    );
  }
}

String mapFirebaseAuthError(FirebaseAuthException error) {
  return switch (error.code) {
    'invalid-email' => 'Digite um e-mail valido.',
    'invalid-credential' ||
    'user-not-found' ||
    'wrong-password' =>
      'E-mail ou senha invalidos.',
    'user-disabled' =>
      'Este acesso foi desativado. Entre em contato com a administração.',
    'too-many-requests' =>
      'Muitas tentativas foram realizadas. Aguarde alguns minutos e tente novamente.',
    'network-request-failed' =>
      'Nao foi possivel conectar ao servico. Verifique sua internet.',
    'operation-not-allowed' =>
      'O metodo de login nao esta habilitado no Firebase.',
    _ => 'Nao foi possivel entrar. Tente novamente.',
  };
}
