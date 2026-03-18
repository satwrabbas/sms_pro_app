import 'dart:io' show Platform;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:android_id/android_id.dart'; // 🌟
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

      final prefs = await SharedPreferences.getInstance();
      final isRunning = prefs.getBool('is_engine_running') ?? false;

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
  // 2. 🌟 تسجيل الجهاز في السحابة أو فك ارتباطه
  // ==========================================
  Future<void> toggleEngine({String? deviceName}) async {
    if (state is DashboardLoaded) {
      final currentState = state as DashboardLoaded;
      final isRunning = !currentState.isEngineRunning;

      emit(DashboardLoaded(
        contactsCount: currentState.contactsCount,
        groupsCount: currentState.groupsCount,
        schedulesCount: currentState.schedulesCount,
        recentLogs: currentState.recentLogs,
        isEngineRunning: currentState.isEngineRunning, // ننتظر حتى ننجح
        engineStatusMessage: isRunning 
            ? '🔄 جاري تسجيل الجهاز في السحابة...' 
            : '🛑 جاري فك ارتباط هذا الجهاز...',
      ));

      final prefs = await SharedPreferences.getInstance();

      if (isRunning && deviceName != null) {
        try {
          // 1. الفحص الصارم: طلب صلاحية الـ SMS
          if (Platform.isAndroid) {
            final smsGranted = await telephony.requestPhoneAndSmsPermissions;
            if (smsGranted == null || !smsGranted) {
              throw 'يجب الموافقة على صلاحية إرسال الـ SMS لكي يعمل النظام!';
            }
          }

          // 2. طلب صلاحية الإشعارات (للفايربيس) وجلب الرمز
          FirebaseMessaging messaging = FirebaseMessaging.instance;
          await messaging.requestPermission(alert: false, badge: false, sound: false, provisional: false);
          // 3. جلب المفتاح والبصمة وإرسالهم للسحابة
          final fcmToken = await messaging.getToken();
          
          // 🌟 جلب البصمة المستحيلة التغيير (Android ID)
          const androidIdPlugin = AndroidId();
          final String hardwareId = await androidIdPlugin.getId() ?? 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';

          if (fcmToken != null) {
            // 🌟 نمرر البصمة لدالة التسجيل (لم نعد نحتاج لتمرير existingId من الذاكرة لأنه يُمسح عند الحذف)
            final newDeviceId = await _repository.registerDevice(deviceName, fcmToken, hardwareId);
            
            if (newDeviceId != null) {
              await prefs.setString('registered_device_id', newDeviceId);
            }
          }

          await prefs.setBool('is_engine_running', true);

          emit(DashboardLoaded(
            contactsCount: currentState.contactsCount,
            groupsCount: currentState.groupsCount,
            schedulesCount: currentState.schedulesCount,
            recentLogs: currentState.recentLogs,
            isEngineRunning: true, 
            engineStatusMessage: '📡 تم تسجيل جهاز ($deviceName) بنجاح!',
          ));

        } catch (e) {
          await prefs.setBool('is_engine_running', false);
          emit(DashboardLoaded(
            contactsCount: currentState.contactsCount,
            groupsCount: currentState.groupsCount,
            schedulesCount: currentState.schedulesCount,
            recentLogs: currentState.recentLogs,
            isEngineRunning: false,
            engineStatusMessage: '❌ فشل تسجيل الجهاز: $e',
          ));
        }
      } else {
        // 🛑 المستخدم قرر فك ارتباط هذا الهاتف
        try {
          final existingId = prefs.getString('registered_device_id');
          if (existingId != null) {
             // مسح الجهاز من السحابة تماماً
            await _repository.removeDevice(existingId);
            await prefs.remove('registered_device_id'); 
          }
          
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
          emit(DashboardLoaded(
            contactsCount: currentState.contactsCount,
            groupsCount: currentState.groupsCount,
            schedulesCount: currentState.schedulesCount,
            recentLogs: currentState.recentLogs,
            isEngineRunning: true,
            engineStatusMessage: '❌ فشل فك الارتباط: $e',
          ));
        }
      }
    }
  }

  // ==========================================
  // 3. 🔄 المزامنة الشاملة الذكية
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
        engineStatusMessage: '🔄 جاري المزامنة الذكية...',
      ));

      try {
        final wasDownloaded = await _repository.downloadIfCloudIsNewer();
        
        if (!wasDownloaded) {
          await _repository.syncAllToCloud();
        }
        
        await loadDashboard(); 
        
        final newState = state as DashboardLoaded;
        emit(DashboardLoaded(
          contactsCount: newState.contactsCount,
          groupsCount: newState.groupsCount,
          schedulesCount: newState.schedulesCount,
          recentLogs: newState.recentLogs,
          isEngineRunning: newState.isEngineRunning,
          engineStatusMessage: wasDownloaded 
              ? '✅ تم استيراد التحديثات الجديدة من السحابة!' 
              : '✅ تم رفع بيانات هاتفك للسحابة بنجاح!',
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