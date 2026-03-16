import 'dart:io' show Platform;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// 🌟 استدعاء حزمة الذاكرة الدائمة
import 'package:shared_preferences/shared_preferences.dart'; 

part 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({required CrmRepository repository})
      : _repository = repository,
        super(DashboardLoading());

  final CrmRepository _repository;

  // ==========================================
  // 1. تحميل بيانات لوحة التحكم (وقراءة حالة الزر المحفوظة)
  // ==========================================
  Future<void> loadDashboard() async {
    try {
      final contacts = await _repository.getContacts();
      final groups = await _repository.getGroups();
      final schedules = await _repository.getSchedules();
      final logs = await _repository.getMessageLogs();

      // 🌟 السحر هنا: قراءة حالة المحرك من ذاكرة الهاتف
      final prefs = await SharedPreferences.getInstance();
      final isRunning = prefs.getBool('is_engine_running') ?? false;

      emit(DashboardLoaded(
        contactsCount: contacts.length,
        groupsCount: groups.length,
        schedulesCount: schedules.length,
        recentLogs: logs,
        isEngineRunning: isRunning, // 🌟 نمرر الحالة المحفوظة
      ));
    } catch (e) {
      // تجاهل الأخطاء البسيطة
    }
  }

  // ==========================================
  // 2. 🌟 ربط/فصل الهاتف بالسحابة (FCM) وحفظ الحالة
  // ==========================================
  Future<void> toggleEngine() async {
    if (state is DashboardLoaded) {
      final currentState = state as DashboardLoaded;
      final isRunning = !currentState.isEngineRunning; // عكس الحالة الحالية

      emit(DashboardLoaded(
        contactsCount: currentState.contactsCount,
        groupsCount: currentState.groupsCount,
        schedulesCount: currentState.schedulesCount,
        recentLogs: currentState.recentLogs,
        isEngineRunning: isRunning,
        engineStatusMessage: isRunning 
            ? '🔄 جاري الاتصال بالسحابة...' 
            : '🛑 تم فك ارتباط الهاتف.',
      ));

      final prefs = await SharedPreferences.getInstance();

      if (isRunning) {
        try {
          // 1. طلب الصلاحية
          FirebaseMessaging messaging = FirebaseMessaging.instance;
          await messaging.requestPermission(
            alert: false, badge: false, sound: false, provisional: false,
          );

          // 2. جلب المفتاح وإرساله للسحابة
          final fcmToken = await messaging.getToken();
          if (fcmToken != null) {
            await _repository.saveFcmToken(fcmToken);
          }

          // 🌟 3. حفظ الحالة في الذاكرة الدائمة (لكي لا تُنسى أبداً)
          await prefs.setBool('is_engine_running', true);

          emit(DashboardLoaded(
            contactsCount: currentState.contactsCount,
            groupsCount: currentState.groupsCount,
            schedulesCount: currentState.schedulesCount,
            recentLogs: currentState.recentLogs,
            isEngineRunning: true,
            engineStatusMessage: '📡 الهاتف متصل بالسحابة وجاهز للإرسال!',
          ));

        } catch (e) {
          // في حال الفشل، نعيد الزر لحالته المغلقة
          await prefs.setBool('is_engine_running', false);
          emit(DashboardLoaded(
            contactsCount: currentState.contactsCount,
            groupsCount: currentState.groupsCount,
            schedulesCount: currentState.schedulesCount,
            recentLogs: currentState.recentLogs,
            isEngineRunning: false,
            engineStatusMessage: '❌ فشل الاتصال بالسحابة: $e',
          ));
        }
      } else {
        // 🛑 المستخدم قرر فك ارتباط هذا الهاتف
        try {
          // 1. مسح المفتاح من السحابة (لن تصله أي أوامر بعد الآن)
          await _repository.removeFcmToken();
          
          // 2. حفظ الحالة الجديدة في ذاكرة الهاتف
          await prefs.setBool('is_engine_running', false);

          emit(DashboardLoaded(
            contactsCount: currentState.contactsCount,
            groupsCount: currentState.groupsCount,
            schedulesCount: currentState.schedulesCount,
            recentLogs: currentState.recentLogs,
            isEngineRunning: false,
            engineStatusMessage: '🛑 تم فك ارتباط الهاتف بنجاح. لن يرسل رسائل بعد الآن.',
          ));
        } catch (e) {
          // إذا فشل الاتصال بالإنترنت أثناء فك الارتباط
          emit(DashboardLoaded(
            contactsCount: currentState.contactsCount,
            groupsCount: currentState.groupsCount,
            schedulesCount: currentState.schedulesCount,
            recentLogs: currentState.recentLogs,
            isEngineRunning: true, // نتركه متصلاً لأننا لم ننجح في إخبار السحابة
            engineStatusMessage: '❌ فشل فك الارتباط، تأكد من اتصال الإنترنت.',
          ));
        }
      }
    }
  }

  // ==========================================
  // 3. 🔄 المزامنة الشاملة مع السحابة (رفع وتنزيل)
  // ==========================================
  Future<void> syncDataToCloud() async {
    if (state is DashboardLoaded) {
      final currentState = state as DashboardLoaded;
      
      emit(DashboardLoaded(
        contactsCount: currentState.contactsCount,
        groupsCount: currentState.groupsCount,
        schedulesCount: currentState.schedulesCount,
        recentLogs: currentState.recentLogs,
        isEngineRunning: currentState.isEngineRunning, 
        engineStatusMessage: '🔄 جاري المزامنة الشاملة...',
      ));

      try {
        await _repository.syncAllToCloud();
        await _repository.downloadAllFromCloud();
        await loadDashboard(); 
        
        final newState = state as DashboardLoaded;
        emit(DashboardLoaded(
          contactsCount: newState.contactsCount,
          groupsCount: newState.groupsCount,
          schedulesCount: newState.schedulesCount,
          recentLogs: newState.recentLogs,
          isEngineRunning: newState.isEngineRunning,
          engineStatusMessage: '✅ تمت المزامنة بنجاح!',
        ));
      } catch (e) {
        emit(DashboardLoaded(
          contactsCount: currentState.contactsCount,
          groupsCount: currentState.groupsCount,
          schedulesCount: currentState.schedulesCount,
          recentLogs: currentState.recentLogs,
          isEngineRunning: currentState.isEngineRunning,
          engineStatusMessage: '❌ فشلت المزامنة: $e',
        ));
      }
    }
  }
}