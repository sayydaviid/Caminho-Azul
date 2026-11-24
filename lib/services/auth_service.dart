import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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

/// Valores persistidos canônicos em inglês (D-08). Os valores antigos em
/// português são reconhecidos só para exibição e normalização pelo admin;
/// nunca concedem acesso (sem fallback).
enum UserRole {
  school('school', 'Escola', legacyValue: 'escola'),
  family('family', 'Família', legacyValue: 'familia'),
  health('health', 'Saúde', legacyValue: 'saude'),
  administration('admin', 'Administração');

  const UserRole(this.value, this.label, {this.legacyValue});

  final String value;
  final String label;
  final String? legacyValue;

  /// Somente valores canônicos.
  static UserRole? fromValue(String? value) {
    for (final role in values) {
      if (role.value == value) return role;
    }
    return null;
  }

  /// Valor antigo em português, para a administração normalizar.
  static UserRole? fromLegacyValue(String? value) {
    for (final role in values) {
      if (role.legacyValue != null && role.legacyValue == value) return role;
    }
    return null;
  }
}

enum SchoolRole {
  teacher('teacher', 'Professor', legacyValue: 'professor'),
  director('director', 'Direção escolar', legacyValue: 'direcao');

  const SchoolRole(this.value, this.label, {required this.legacyValue});

  final String value;
  final String label;
  final String legacyValue;

  static SchoolRole? fromValue(String? value) {
    for (final role in values) {
      if (role.value == value) return role;
    }
    return null;
  }

  static SchoolRole? fromLegacyValue(String? value) {
    for (final role in values) {
      if (role.legacyValue == value) return role;
    }
    return null;
  }
}

enum HealthRole {
  ubsDirector('ubs_director', 'Direção da UBS'),
  psychologist('psychologist', 'Psicólogo(a)');

  const HealthRole(this.value, this.label);

  final String value;
  final String label;

  static HealthRole? fromValue(String? value) {
    for (final role in values) {
      if (role.value == value) return role;
    }
    return null;
  }
}

/// Rótulo em português do perfil completo (role + subrole).
String accessLabelFor(
  UserRole role, {
  SchoolRole? schoolRole,
  HealthRole? healthRole,
}) {
  return switch (role) {
    UserRole.school when schoolRole != null => 'Escola • ${schoolRole.label}',
    UserRole.health when healthRole != null => 'Saúde • ${healthRole.label}',
    _ => role.label,
  };
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
    this.healthRole,
    this.institutionIds = const [],
    this.studentIds = const [],
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
  final HealthRole? healthRole;
  final List<String> institutionIds;
  final List<String> studentIds;
  final bool active;

  String get accessLabel =>
      accessLabelFor(role, schoolRole: schoolRole, healthRole: healthRole);
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sessão válida de outro perfil ao abrir a área administrativa (D-A05):
/// o guard devolve o usuário à própria área em vez do login.
class NotAdminSessionException extends AuthException {
  const NotAdminSessionException(this.role)
      : super('A sessão administrativa não é válida.');

  final UserRole role;
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
    // A saída da conta navega para o login antes de terminar a limpeza do
    // Firestore (terminate + clearPersistence); entrar no meio dela falhava
    // com "Nao foi possivel entrar" (D-A03).
    await signOutBarrier.wait();
    // Descarta qualquer sessão persistida. Na Web, uma sessão antiga com token
    // invalidado (ex.: senha redefinida na ativação) faz a inicialização do
    // Auth falhar e a operação seguinte herdar o erro invalid-credential.
    // Por isso: aguarda a inicialização, encerra a sessão antiga e repete o
    // login uma única vez nesse código de erro.
    try {
      await _firebaseAuth
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Inicialização com sessão inválida: tratada abaixo.
    }
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException {
      // Sessão antiga inválida; nada a encerrar.
    }
    final normalizedEmail = email.trim().toLowerCase();
    Future<UserCredential> attempt() => _firebaseAuth.signInWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
    UserCredential credential;
    try {
      credential = await attempt();
    } on FirebaseAuthException catch (error) {
      if (error.code != 'invalid-credential') rethrow;
      credential = await attempt();
    }

    final user = credential.user;
    if (user == null) {
      await signOut();
      throw const AuthException('Não foi possível recuperar o usuário.');
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

  /// Compartilhada entre instâncias: o router cria um serviço por rota.
  static final signOutBarrier = PendingWork();

  @override
  Future<void> signOut() => signOutBarrier.run(() async {
        await _firebaseAuth.signOut();
        await clearLocalFirestoreCache(_firestore);
      });

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
        'Usuário sem perfil cadastrado. Entre em contato com a administração.',
      );
    }

    try {
      return appUserFromProfile(
        uid: user.uid,
        authEmail: user.email,
        data: snapshot.data(),
        requireAdmin: requireAdmin,
      );
    } on NotAdminSessionException {
      // Conta válida de outro perfil: mantém a sessão (o guard a devolve à
      // própria área). Encerrar aqui deslogava quem digitasse a URL (D-A05).
      rethrow;
    } on AuthException {
      await signOut();
      rethrow;
    }
  }
}

/// Valida o perfil `users/{uid}` (P1-17): ativo, role e subrole canônicas,
/// sem fallback. Lança [AuthException] com a mensagem para o usuário.
AppUser appUserFromProfile({
  required String uid,
  required String? authEmail,
  required Map<String, dynamic>? data,
  bool requireAdmin = false,
}) {
  if (data == null) {
    throw const AuthException(
      'Perfil de usuário incompleto. Entre em contato com a administração.',
    );
  }
  if (data['active'] != true) {
    throw const AuthException(
      'Este acesso foi desativado. Entre em contato com a administração.',
    );
  }

  final role = UserRole.fromValue(data['role'] as String?);
  final schoolRole = SchoolRole.fromValue(data['schoolRole'] as String?);
  final healthRole = HealthRole.fromValue(data['healthRole'] as String?);
  final complete = switch (role) {
    UserRole.school => schoolRole != null,
    UserRole.health => healthRole != null,
    UserRole.family || UserRole.administration => true,
    null => false,
  };
  if (!complete) {
    throw const AuthException(
      'O perfil desta conta está incompleto ou desatualizado. Entre em contato com a administração.',
    );
  }
  if (requireAdmin && role != UserRole.administration) {
    throw NotAdminSessionException(role!);
  }

  List<String> ids(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];
  // Vínculos obrigatórios (D-03, D-10, P1-10).
  final operational = role == UserRole.school || role == UserRole.health;
  if (operational &&
      (data['professionalId'] is! String || ids(data['institutionIds']).isEmpty)) {
    throw const AuthException(
      'Seu cadastro profissional ainda não está vinculado a uma instituição. Entre em contato com a administração.',
    );
  }
  if (role == UserRole.family && ids(data['studentIds']).isEmpty) {
    throw const AuthException(
      'Esta conta familiar ainda não está vinculada a um estudante. Entre em contato com a administração.',
    );
  }
  return AppUser(
    uid: uid,
    email: authEmail ?? (data['email'] as String? ?? ''),
    name: data['name'] as String?,
    firstName: data['firstName'] as String?,
    lastName: data['lastName'] as String?,
    professionalId: data['professionalId'] as String?,
    role: role!,
    schoolRole: role == UserRole.school ? schoolRole : null,
    healthRole: role == UserRole.health ? healthRole : null,
    institutionIds: ids(data['institutionIds']),
    studentIds: ids(data['studentIds']),
    active: true,
  );
}

/// Descarta o cache local do Firestore no logout, para que o próximo usuário
/// do aparelho não veja dados em cache da sessão anterior (privacidade).
/// A instância é recriada automaticamente, com as mesmas configurações, no
/// próximo uso.
/// Registra um trabalho assíncrono em andamento para que outro possa esperá-lo
/// (ex.: o login aguarda a limpeza da saída anterior). Erros não propagam para
/// quem apenas espera.
class PendingWork {
  Future<void>? _current;

  Future<void> run(Future<void> Function() work) {
    final future = work();
    final tracked = future.catchError((_) {});
    _current = tracked;
    tracked.whenComplete(() {
      if (identical(_current, tracked)) _current = null;
    });
    return future;
  }

  Future<void> wait() async {
    final pending = _current;
    if (pending != null) await pending;
  }

  bool get busy => _current != null;
}

/// Limpa o cache local do Firestore na saída da conta (Android).
///
/// Na Web não encerra a instância: o `cloud_firestore_web` guarda a instância
/// JS e não a recria após `terminate()`, então todo login seguinte falhava até
/// recarregar a página (D-A09). Na Web a persistência já está desligada e o SDK
/// separa o cache em memória por usuário quando a conta muda.
Future<void> clearLocalFirestoreCache(FirebaseFirestore firestore,
    {bool isWeb = kIsWeb}) async {
  if (isWeb) return;
  try {
    await firestore.terminate();
    await firestore.clearPersistence();
  } on FirebaseException {
    // Sem cache a limpar ou instância já encerrada.
  }
}

String mapFirebaseAuthError(FirebaseAuthException error) {
  return switch (error.code) {
    'invalid-email' => 'Digite um e-mail válido.',
    'invalid-credential' ||
    'user-not-found' ||
    'wrong-password' =>
      'E-mail ou senha inválidos.',
    'user-disabled' =>
      'Este acesso foi desativado. Entre em contato com a administração.',
    'too-many-requests' =>
      'Muitas tentativas foram realizadas. Aguarde alguns minutos e tente novamente.',
    'network-request-failed' =>
      'Não foi possível conectar ao serviço. Verifique sua internet.',
    'operation-not-allowed' =>
      'O método de login não está habilitado no Firebase.',
    _ => 'Não foi possível entrar. Tente novamente.',
  };
}
