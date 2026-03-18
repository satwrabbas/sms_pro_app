import 'dart:io' show Platform;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart';
import 'package:telephony/telephony.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;
import 'package:android_id/android_id.dart'; 

part 'campaigns_state.dart';

class CampaignsCubit extends Cubit<CampaignsState> {
  CampaignsCubit({required CrmRepository repository})
      : _repository = repository,
        super(CampaignsInitial());

  final CrmRepository _repository;

  /// 🌟 جلب البيانات (مع دعم وضع الطيران/بدون إنترنت ✈️)
  Future<void> loadCampaignsData() async {
    emit(CampaignsLoading());
    try {
      final groups = await _repository.getGroups();
      final schedules = await _repository.getSchedules();
      
      List<Map<String, dynamic>> devices =[];
      try {
        // 1. محاولة جلب الأجهزة من السحابة (تحتاج إنترنت)
        devices = await _repository.getRegisteredDevices(); 
      } catch (_) {
        // 2. ✈️ حالة الطوارئ (لا يوجد إنترنت): نجلب الهاتف الحالي من الذاكرة
        final prefs = await SharedPreferences.getInstance();
        final localId = prefs.getString('registered_device_id');
        if (localId != null) {
          devices =[{'device_id': localId, 'device_name': 'هذا الهاتف (بدون إنترنت)'}];
        }
      }
      
      emit(CampaignsLoaded(groups: groups, schedules: schedules, devices: devices));
    } catch (e) {
      emit(CampaignsError(message: 'حدث خطأ في جلب البيانات المحلية: $e'));
    }
  }

  Future<void> createGroup(String name) async {
    try {
      await _repository.addGroup(name);
      await loadCampaignsData(); 
      _repository.syncAllToCloud().catchError((_) {}); // 🌟 تجاهل خطأ المزامنة إذا لم يوجد نت
    } catch (e) {
      emit(CampaignsError(message: 'خطأ في إنشاء المجموعة: $e'));
    }
  }

  Future<void> createSchedule({
    required int groupId, 
    required String message, 
    required int sendDay, 
    required int sendHour, 
    required int sendMinute,
    String? targetDeviceId, 
  }) async {
    try {
      await _repository.addSchedule(
        groupId: groupId, 
        message: message, 
        sendDay: sendDay, 
        sendHour: sendHour, 
        sendMinute: sendMinute,
        targetDeviceId: targetDeviceId, 
      );
      await loadCampaignsData(); 

      _requestPermissionsAndLinkAsync();
      _repository.syncAllToCloud().catchError((_) {}); // 🌟 حماية الأوفلاين

    } catch (e) {
      emit(CampaignsError(message: 'خطأ في إنشاء الحملة: $e'));
    }
  }

  Future<void> _requestPermissionsAndLinkAsync() async {
    try {
      if (Platform.isAndroid) {
        final smsGranted = await Telephony.instance.requestPhoneAndSmsPermissions;
        if (smsGranted == null || !smsGranted) return; 
      }

      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: false, badge: false, sound: false, provisional: false);
      
      final fcmToken = await messaging.getToken();
      if (fcmToken != null) {
        const androidIdPlugin = AndroidId();
        final String hardwareId = await androidIdPlugin.getId() ?? 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';

        final newDeviceId = await _repository.registerDevice('هاتف الإرسال الأساسي', fcmToken, hardwareId);
        
        if (newDeviceId != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('registered_device_id', newDeviceId);
          await prefs.setBool('is_engine_running', true);
        }
      }
    } catch (e) {
      print("⚠️ خطأ في الربط التلقائي (ربما لا يوجد إنترنت): $e");
    }
  }

  Future<void> deleteGroup(Group group) async {
    try {
      await _repository.deleteGroup(group);
      await loadCampaignsData(); 
      _repository.syncAllToCloud().catchError((_) {}); 
    } catch (e) {
      emit(CampaignsError(message: 'خطأ أثناء الحذف: $e'));
    }
  }

  Future<void> editGroup(Group group, String newName) async {
    try {
      await _repository.updateGroup(group.copyWith(name: newName));
      await loadCampaignsData();
      _repository.syncAllToCloud().catchError((_) {}); 
    } catch (e) {
      emit(CampaignsError(message: 'خطأ أثناء التعديل: $e'));
    }
  }

  Future<void> deleteSchedule(Schedule schedule) async {
    try {
      await _repository.deleteSchedule(schedule);
      await loadCampaignsData();
      _repository.syncAllToCloud().catchError((_) {}); 
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
    String? newTargetDeviceId, 
  }) async {
    try {
      await _repository.updateSchedule(
        originalSchedule.copyWith(
          message: newMessage, 
          sendDay: newSendDay, 
          sendHour: newSendHour, 
          sendMinute: newSendMinute,
          targetDeviceId: drift.Value(newTargetDeviceId), 
        ),
      );
      await loadCampaignsData();
      _repository.syncAllToCloud().catchError((_) {}); 
    } catch (e) {
      emit(CampaignsError(message: 'خطأ أثناء تعديل الحملة: $e'));
    }
  }

  Future<void> toggleScheduleActive(Schedule schedule) async {
    try {
      await _repository.updateSchedule(schedule.copyWith(isActive: !schedule.isActive));
      await loadCampaignsData(); 
      _repository.syncAllToCloud().catchError((_) {}); 
    } catch (e) {
      emit(CampaignsError(message: 'خطأ أثناء تبديل حالة الحملة: $e'));
    }
  }
}