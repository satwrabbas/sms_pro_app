import 'dart:io' show Platform;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart';
import 'package:telephony/telephony.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
part 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({required CrmRepository repository})
      : _repository = repository,
        super(DashboardLoading());

  final CrmRepository _repository;
  final Telephony telephony = Telephony.instance;

  // ==========================================
  // 1. تحميل بيانات لوحة التحكم
  // ==========================================
  Future<void> loadDashboard() async {
    try {
      final contacts = await _repository.getContacts();
      final groups = await _repository.getGroups();
      final schedules = await _repository.getSchedules();
      final logs = await _repository.getMessageLogs();

      final isRunning = (state is DashboardLoaded) ? (state as DashboardLoaded).isEngineRunning : false;

      emit(DashboardLoaded(
        contactsCount: contacts.length,
        groupsCount: groups.length,
        schedulesCount: schedules.length,
        recentLogs: logs,
        isEngineRunning: isRunning,
      ));
    } catch (e) {
      // تجاهل الأخطاء البسيطة
    }
  }

// ==========================================
  // 2. 🌟 تفعيل العقل السحابي (FCM)
  // ==========================================
  Future<void> toggleEngine() async {
    if (state is DashboardLoaded) {
      final currentState = state as DashboardLoaded;
      final isRunning = !currentState.isEngineRunning; 

      emit(DashboardLoaded(
        contactsCount: currentState.contactsCount,
        groupsCount: currentState.groupsCount,
        schedulesCount: currentState.schedulesCount,
        recentLogs: currentState.recentLogs,
        isEngineRunning: isRunning,
        engineStatusMessage: isRunning 
            ? '🔄 جاري الاتصال بالسحابة...' 
            : '🛑 تم إيقاف المحرك.',
      ));

      if (isRunning) {
        try {
          // 1. طلب صلاحية استقبال الإشارات من فايربيس
          FirebaseMessaging messaging = FirebaseMessaging.instance;
          await messaging.requestPermission(
            alert: false, // لا نريد إشعارات مرئية مزعجة
            badge: false,
            sound: false,
            provisional: false,
          );

          // 2. جلب الـ Token الخاص بهذا الهاتف 📱🔑
          final fcmToken = await messaging.getToken();
          print("🔑 FCM TOKEN: $fcmToken");

          // 🌟 3. إرسال المفتاح فوراً إلى Supabase ليتم حفظه!
          if (fcmToken != null) {
            await _repository.saveFcmToken(fcmToken);
          }

          emit(DashboardLoaded(
            contactsCount: currentState.contactsCount,
            groupsCount: currentState.groupsCount,
            schedulesCount: currentState.schedulesCount,
            recentLogs: currentState.recentLogs,
            isEngineRunning: true,
            engineStatusMessage: '📡 الهاتف متصل بالسحابة وجاهز لاستقبال أوامر الـ SMS الصامتة!',
          ));

        } catch (e) {
          emit(DashboardLoaded(
            contactsCount: currentState.contactsCount,
            groupsCount: currentState.groupsCount,
            schedulesCount: currentState.schedulesCount,
            recentLogs: currentState.recentLogs,
            isEngineRunning: false,
            engineStatusMessage: '❌ فشل الاتصال بالسحابة: $e',
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
        isEngineRunning: currentState.isEngineRunning, // الحفاظ على حالة المحرك
        engineStatusMessage: '🔄 جاري المزامنة الشاملة (رفع وتنزيل)...',
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