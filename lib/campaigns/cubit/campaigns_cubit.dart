import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart'; // لجلب أنواع Group و Schedule

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
      // نطلب من المدير جلب الاثنين في نفس الوقت لتسريع العملية
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
      await loadCampaignsData(); // تحديث الشاشة بعد الإضافة
    } catch (e) {
      emit(CampaignsError(message: 'خطأ في إنشاء المجموعة: $e'));
    }
  }

  /// إنشاء حملة (ربط رسالة ويوم معين بمجموعة)
  Future<void> createSchedule({required int groupId, required String message, required int sendDay}) async {
    try {
      await _repository.addSchedule(groupId: groupId, message: message, sendDay: sendDay);
      await loadCampaignsData(); // تحديث الشاشة
    } catch (e) {
      emit(CampaignsError(message: 'خطأ في إنشاء الحملة: $e'));
    }
  }
}