import 'package:local_storage_api/local_storage_api.dart';
import 'package:cloud_storage_api/cloud_storage_api.dart'; // ☁️
import 'package:drift/drift.dart' as drift;

/// المدير المسؤول عن إدارة بيانات التطبيق (محلياً وسحابياً)
class CrmRepository {
  const CrmRepository({
    required AppDatabase localStorage,
    required CloudStorageClient cloudStorage,
  })  : _localStorage = localStorage,
        _cloudStorage = cloudStorage;

  final AppDatabase _localStorage;
  final CloudStorageClient _cloudStorage;

  // ==========================================
  // 1. قسم المصادقة (Authentication) ☁️
  // ==========================================
  
  Stream<AuthState> get authStateChanges => _cloudStorage.authStateChanges;
  
  Session? get currentSession => _cloudStorage.currentSession;

  Future<void> signIn({required String email, required String password}) async {
    await _cloudStorage.signIn(email: email, password: password);
  }

  Future<void> signUp({required String email, required String password}) async {
    await _cloudStorage.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await _cloudStorage.signOut();
  }

  // ==========================================
  // 2. قسم جهات الاتصال (Contacts) 💾
  // ==========================================
  
  Future<List<Contact>> getContacts() async {
    return await _localStorage.getAllContacts();
  }

  Future<void> saveSyncedContacts(List<Map<String, String>> phoneContacts) async {
    for (var contact in phoneContacts) {
      // لاحظ هنا: ContactsCompanion بدون .drift لأنها من حزمتنا
      final companion = ContactsCompanion(
        name: drift.Value(contact['name'] ?? 'بدون اسم'),
        phone: drift.Value(contact['phone'] ?? ''),
      );
      await _localStorage.insertContact(companion);
    }
  }

  Future<int> deleteContact(Contact contact) async {
    return await _localStorage.deleteContact(contact);
  }

  // ==========================================
  // 3. قسم المجموعات والحملات (Groups & Campaigns) 📅
  // ==========================================

  Future<List<Group>> getGroups() async {
    return await _localStorage.getAllGroups();
  }

  Future<int> addGroup(String name) async {
    // 🌟 التصحيح هنا: حذفنا drift. من قبل GroupsCompanion
    final companion = GroupsCompanion(
      name: drift.Value(name),
    );
    return await _localStorage.insertGroup(companion);
  }

  Future<List<Schedule>> getSchedules() async {
    return await _localStorage.getAllSchedules();
  }

  Future<int> addSchedule({
    required int groupId,
    required String message,
    required int sendDay,
  }) async {
    // 🌟 التصحيح هنا: حذفنا drift. من قبل SchedulesCompanion
    final companion = SchedulesCompanion(
      groupId: drift.Value(groupId),
      message: drift.Value(message),
      sendDay: drift.Value(sendDay),
    );
    return await _localStorage.insertSchedule(companion);
  }
}