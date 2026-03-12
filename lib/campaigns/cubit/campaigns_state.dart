part of 'campaigns_cubit.dart';

abstract class CampaignsState {}

class CampaignsInitial extends CampaignsState {}

class CampaignsLoading extends CampaignsState {}

// هذه الحالة تحمل قائمتين: المجموعات والحملات المجدولة
class CampaignsLoaded extends CampaignsState {
  final List<Group> groups;
  final List<Schedule> schedules;

  CampaignsLoaded({required this.groups, required this.schedules});
}

class CampaignsError extends CampaignsState {
  final String message;
  CampaignsError({required this.message});
}