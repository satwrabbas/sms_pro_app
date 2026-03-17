import 'dart:io' show Platform; 
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart';
import 'package:telephony/telephony.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 

part 'campaigns_state.dart';

class CampaignsCubit extends Cubit<CampaignsState> {
  CampaignsCubit({required CrmRepository repository})
      : _repository = repository,
        super(CampaignsInitial());

  final CrmRepository _repository;

  /// جلب المجموعات والحملات معاً لعرضها في الشاشة
  Future<void> loadCampaignsData() async {
    emit(CampaignsLoading());
    try {
      final groups = await _repository.getGroups();
      final schedules = await _repository.getSchedules();
      emit(CampaignsLoaded(groups: groups, schedules: schedules));
    } catch (e) {
      emit(CampaignsError(message: 'حدث خطأ في جلب البيانات: $e'));
    }
  }

  /// إنشاء مجموعة جديدة
  Future<void> createGroup(String name) async {
    try {
      await _repository.addGroup(name);
      await loadCampaignsData(); 
      _repository.syncAllToCloud(); 
    } catch (e) {
      emit(CampaignsError(message: 'خطأ في إنشاء المجموعة: $e'));
    }
  }

  // ==========================================
  // 🌟 إنشاء حملة (مفصولة وآمنة جداً 100%)
  // ==========================================
  Future<void> createSchedule({
    required int groupId, 
    required String message, 
    required int sendDay, 
    required int sendHour, 
    required int sendMinute
  }) async {
    try {
      // 1. حفظ الحملة محلياً وعرضها للمستخدم فوراً (حتى لو لم يكن هناك إنترنت)
      await _repository.addSchedule(
        groupId: groupId, 
        message: message, 
        sendDay: sendDay, 
        sendHour: sendHour, 
        sendMinute: sendMinute
      );
      await loadCampaignsData(); // تحديث الشاشة لتظهر الحملة

      // 2. تشغيل أوامر الصلاحيات والربط في الخلفية (لكي لا تخرب الواجهة إذا فشلت)
      _requestPermissionsAndLinkAsync();

      // 3. رفع الحملة للسحابة بصمت
      _repository.syncAllToCloud(); 

    } catch (e) {
      emit(CampaignsError(message: 'خطأ في إنشاء الحملة: $e'));
    }
  }

  // ==========================================
  // 👻 دالة خلفية لطلب الصلاحيات والربط بالفايربيس بدون إزعاج الـ UI
  // ==========================================
  Future<void> _requestPermissionsAndLinkAsync() async {
    try {
      // 1. طلب صلاحية الـ SMS
      if (Platform.isAndroid) {
        await Telephony.instance.requestPhoneAndSmsPermissions;
      }

      // 2. طلب صلاحية الفايربيس وتوليد المفتاح
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: false, badge: false, sound: false, provisional: false);
      
      final fcmToken = await messaging.getToken();
      if (fcmToken != null) {
        await _repository.saveFcmToken(fcmToken);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_engine_running', true);
      }
    } catch (e) {
      // نتجاهل الأخطاء بصمت لكي لا نؤثر على تجربة المستخدم
      print("⚠️ خطأ في الربط التلقائي بالفايربيس: $e");
    }
  }

  // --- دوال الحذف والتعديل ---
  Future<void> deleteGroup(Group group) async {
    try {
      await _repository.deleteGroup(group);
      await loadCampaignsData(); 
      _repository.syncAllToCloud(); 
    } catch (e) {
      emit(CampaignsError(message: 'خطأ أثناء الحذف: $e'));
    }
  }

  Future<void> editGroup(Group group, String newName) async {
    try {
      await _repository.updateGroup(group.copyWith(name: newName));
      await loadCampaignsData();
      _repository.syncAllToCloud(); 
    } catch (e) {
      emit(CampaignsError(message: 'خطأ أثناء التعديل: $e'));
    }
  }

  Future<void> deleteSchedule(Schedule schedule) async {
    try {
      await _repository.deleteSchedule(schedule);
      await loadCampaignsData();
      _repository.syncAllToCloud(); 
    } catch (e) {
      emit(CampaignsError(message: 'خطأ أثناء حذف الحملة: $e'));
    }
  }

  Future<void> editSchedule({
    required Schedule originalSchedule,
    required String newMessage,
    required int newSendDay,
    required int newSendHour,
    required int newSendMinute,
  }) async {
    try {
      await _repository.updateSchedule(
        originalSchedule.copyWith(
          message: newMessage, 
          sendDay: newSendDay, 
          sendHour: newSendHour, 
          sendMinute: newSendMinute
        ),
      );
      await loadCampaignsData();
      _repository.syncAllToCloud(); 
    } catch (e) {
      emit(CampaignsError(message: 'خطأ أثناء تعديل الحملة: $e'));
    }
  }

  Future<void> toggleScheduleActive(Schedule schedule) async {
    try {
      await _repository.updateSchedule(schedule.copyWith(isActive: !schedule.isActive));
      await loadCampaignsData(); 
      _repository.syncAllToCloud(); 
    } catch (e) {
      emit(CampaignsError(message: 'خطأ أثناء تبديل حالة الحملة: $e'));
    }
  }
}