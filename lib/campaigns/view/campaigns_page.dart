import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart'; // لجلب أنواع Group و Schedule
import '../cubit/campaigns_cubit.dart';

class CampaignsPage extends StatelessWidget {
  const CampaignsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CampaignsCubit(
        repository: context.read<CrmRepository>(),
      )..loadCampaignsData(),
      child: const CampaignsView(),
    );
  }
}

class CampaignsView extends StatelessWidget {
  const CampaignsView({super.key});

  // نافذة إضافة مجموعة جديدة
  void _showAddGroupDialog(BuildContext context) {
    final nameController = TextEditingController();
    final cubit = context.read<CampaignsCubit>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مجموعة جديدة'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'اسم المجموعة (مثال: عملاء VIP)'),
        ),
        actions:[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                cubit.createGroup(nameController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // نافذة إضافة حملة جديدة (رسالة مجدولة)
  void _showAddScheduleDialog(BuildContext context, List<Group> groups) {
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إنشاء مجموعة أولاً!'), backgroundColor: Colors.orange),
      );
      return;
    }

    final messageController = TextEditingController();
    final dayController = TextEditingController();
    Group? selectedGroup = groups.first; // اختيار أول مجموعة كافتراضي
    final cubit = context.read<CampaignsCubit>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('حملة أتمتة جديدة 🚀'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:[
                DropdownButtonFormField<Group>(
                  value: selectedGroup,
                  decoration: const InputDecoration(labelText: 'اختر المجموعة'),
                  items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g.name))).toList(),
                  onChanged: (val) => setState(() => selectedGroup = val),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'نص الرسالة (SMS)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dayController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'يوم الإرسال في الشهر (1 - 31)'),
                ),
              ],
            ),
          ),
          actions:[
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                final day = int.tryParse(dayController.text);
                if (messageController.text.isNotEmpty && day != null && day >= 1 && day <= 31 && selectedGroup != null) {
                  cubit.createSchedule(groupId: selectedGroup!.id, message: messageController.text.trim(), sendDay: day);
                  Navigator.pop(context);
                }
              },
              child: const Text('جدولة الحملة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // استخدمنا DefaultTabController لتقسيم الشاشة لتبويبين
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الحملات والمجموعات'),
          bottom: const TabBar(
            tabs:[
              Tab(icon: Icon(Icons.rocket_launch), text: 'الحملات'),
              Tab(icon: Icon(Icons.group), text: 'المجموعات'),
            ],
          ),
        ),
        body: BlocBuilder<CampaignsCubit, CampaignsState>(
          builder: (context, state) {
            if (state is CampaignsLoading) {
              return const Center(child: CircularProgressIndicator());
            } 
            else if (state is CampaignsError) {
              return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
            } 
            else if (state is CampaignsLoaded) {
              final groups = state.groups;
              final schedules = state.schedules;

              return TabBarView(
                children:[
                  // التبويب الأول: الحملات المجدولة
                  Scaffold(
                    body: schedules.isEmpty
                        ? const Center(child: Text('لا توجد حملات أتمتة بعد. قم بإنشاء حملة.'))
                        : ListView.builder(
                            itemCount: schedules.length,
                            itemBuilder: (context, i) {
                              final schedule = schedules[i];
                              // البحث عن اسم المجموعة المرتبطة بالحملة
                              final groupName = groups.firstWhere((g) => g.id == schedule.groupId, orElse: () => const Group(id: -1, name: 'محذوفة')).name;
                              
                              return Card(
                                margin: const EdgeInsets.all(8),
                                child: ListTile(
                                  leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.sms, color: Colors.white)),
                                  title: Text('لمجموعة: $groupName'),
                                  subtitle: Text('رسالة: ${schedule.message}'),
                                  trailing: Text('يوم: ${schedule.sendDay}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                ),
                              );
                            },
                          ),
                    floatingActionButton: FloatingActionButton.extended(
                      onPressed: () => _showAddScheduleDialog(context, groups),
                      icon: const Icon(Icons.add),
                      label: const Text('حملة جديدة'),
                    ),
                  ),

                  // التبويب الثاني: المجموعات
                  Scaffold(
                    body: groups.isEmpty
                        ? const Center(child: Text('لا توجد مجموعات بعد. قم بإنشاء مجموعة.'))
                        : ListView.builder(
                            itemCount: groups.length,
                            itemBuilder: (context, i) {
                              return ListTile(
                                leading: const Icon(Icons.folder, color: Colors.amber),
                                title: Text(groups[i].name),
                              );
                            },
                          ),
                    floatingActionButton: FloatingActionButton.extended(
                      onPressed: () => _showAddGroupDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('مجموعة جديدة'),
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}