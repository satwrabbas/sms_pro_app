part of 'dashboard_cubit.dart';

abstract class DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState { // رسالة المحرك (تم الإرسال، فشل، إلخ)

  DashboardLoaded({
    required this.contactsCount,
    required this.groupsCount,
    required this.schedulesCount,
    required this.recentLogs,
    this.isEngineRunning = false,
    this.engineStatusMessage,
  });
  final int contactsCount;
  final int groupsCount;
  final int schedulesCount;
  final List<Message> recentLogs;
  final bool isEngineRunning; // هل المحرك يعمل الآن؟
  final String? engineStatusMessage;
}