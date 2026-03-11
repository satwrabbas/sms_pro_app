import 'package:supabase_flutter/supabase_flutter.dart';

/// هذا الكلاس مسؤول عن التحدث مع Supabase فقط
class CloudStorageClient {
  // نقوم بتمرير الـ client للكلاس (هذا ممتاز من أجل الـ Testing لاحقاً)
  CloudStorageClient({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? Supabase.instance.client;

  final SupabaseClient _supabaseClient;

  // ==========================================
  // قسم المصادقة (Authentication)
  // ==========================================

  /// تسجيل الدخول
  Future<void> signIn({required String email, required String password}) async {
    await _supabaseClient.auth.signInWithPassword(email: email, password: password);
  }

  /// إنشاء حساب جديد
  Future<void> signUp({required String email, required String password}) async {
    await _supabaseClient.auth.signUp(email: email, password: password);
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    await _supabaseClient.auth.signOut();
  }

  /// مراقبة حالة المستخدم (هل هو مسجل دخول أم لا؟)
  Stream<AuthState> get authStateChanges => _supabaseClient.auth.onAuthStateChange;
  
  /// جلب بيانات المستخدم الحالي
  Session? get currentSession => _supabaseClient.auth.currentSession;

  // سيتم إضافة دوال المزامنة (جلب المجموعات والرسائل) هنا لاحقاً!
}