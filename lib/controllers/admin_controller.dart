import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/admin_models.dart';
import '../repositories/admin_repository.dart';
import '../services/admin_user_service.dart';

class AdminController extends ChangeNotifier {
  AdminController({
    required AdminRepository repository,
    required AdminUserService userService,
    required this.actorUid,
  })  : _repository = repository,
        _userService = userService {
    _listen();
  }

  final AdminRepository _repository;
  final AdminUserService _userService;
  final String actorUid;

  AdminSection section = AdminSection.institutions;
  String query = '';
  bool loading = true;
  Object? error;
  List<Object> items = const [];
  StreamSubscription<List<Object>>? _subscription;

  void selectSection(AdminSection value) {
    if (section == value) return;
    section = value;
    query = '';
    _listen();
    notifyListeners();
  }

  void search(String value) {
    query = value.trim().toLowerCase();
    notifyListeners();
  }

  List<Object> get filteredItems =>
      items.where(_matches).toList(growable: false);

  bool _matches(Object item) {
    if (query.isEmpty) return true;
    final fields = switch (item) {
      Institution(:final name) => [name],
      Professional(
        :final name,
        :final registrationNumber,
      ) =>
        [name, registrationNumber ?? ''],
      LocalNetwork(:final name, :final description) => [
          name,
          description ?? ''
        ],
      AdminUser(:final name, :final email) => [name, email],
      AdminParameter(:final title, :final items) => [title, ...items],
      _ => const <String>[],
    };
    return fields.any((value) => value.toLowerCase().contains(query));
  }

  void retry() => _listen();

  void _listen() {
    _subscription?.cancel();
    loading = true;
    error = null;
    items = const [];
    final stream = switch (section) {
      AdminSection.institutions => _repository.watchInstitutions(),
      AdminSection.professionals => _repository.watchProfessionals(),
      AdminSection.localNetwork => _repository.watchLocalNetworks(),
      AdminSection.users => _repository.watchUsers(),
      AdminSection.parameters => _repository.watchParameters(),
    };
    _subscription = stream.map<List<Object>>((values) => values).listen(
      (values) {
        items = List.unmodifiable(values);
        loading = false;
        error = null;
        notifyListeners();
      },
      onError: (Object value) {
        loading = false;
        error = value;
        notifyListeners();
      },
    );
  }

  Future<List<Institution>> activeInstitutions() =>
      _repository.getActiveInstitutions();
  Future<List<Institution>> institutions() => _repository.getInstitutions();
  Future<List<Professional>> professionals() => _repository.getProfessionals();
  Future<List<AdminUser>> users() => _repository.getUsers();

  Future<String> saveUser(AdminUser? user, UserFormData value) async {
    if (user != null) {
      await _repository.updateUser(user, value, actorUid: actorUid);
      return 'Usuário atualizado com sucesso.';
    }

    final result = await _userService.createAccount(
      email: value.normalizedEmail,
      displayName: value.fullName,
      createProfile: (uid) => _repository.createUserProfile(
        uid,
        value,
        actorUid: actorUid,
      ),
    );
    return result.invitationSent
        ? 'Usuário criado. Um e-mail para definição de senha foi enviado.'
        : 'Usuário criado, mas o e-mail de definição de senha não foi enviado. Use “Esqueci minha senha” na tela de login.';
  }

  Future<String> deleteUser(AdminUser user) async {
    await _repository.deleteUser(user, actorUid: actorUid);
    return 'Usuário excluído e acesso removido com sucesso.';
  }

  Future<void> saveInstitution(Institution value) =>
      _repository.saveInstitution(value, actorUid: actorUid);
  Future<void> saveProfessional(Professional value) =>
      _repository.saveProfessional(value, actorUid: actorUid);
  Future<void> saveLocalNetwork(LocalNetwork value) =>
      _repository.saveLocalNetwork(value, actorUid: actorUid);
  Future<void> saveParameter(AdminParameter value) =>
      _repository.saveParameter(value, actorUid: actorUid);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
