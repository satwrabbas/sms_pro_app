import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import '../cubit/dashboard_cubit.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DashboardCubit(repository: context.read<CrmRepository>())..loadDashboard(),
      child: const DashboardView(),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم (CRM)'),
        actions:[
          // 🌟 زر المزامنة السحابية الجديد
          BlocBuilder<DashboardCubit, DashboardState>(
            builder: (context, state) {
              final isRunning = state is DashboardLoaded && state.isEngineRunning;
              return IconButton(
                icon: const Icon(Icons.cloud_upload, color: Colors.white),
                tooltip: 'رفع النسخة الاحتياطية للسحابة',
                onPressed: isRunning
                    ? null // تعطيل الزر إذا كانت هناك عملية تعمل
                    : () {
                        context.read<DashboardCubit>().syncDataToCloud();
                      },
              );
            },
          ),
        ],
      ),
      // BlocListener لعرض نوافذ الـ SnackBar عند تشغيل المحرك
      body: BlocConsumer<DashboardCubit, DashboardState>(
        listener: (context, state) {
          if (state is DashboardLoaded && state.engineStatusMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.engineStatusMessage!), duration: const Duration(seconds: 4)),
            );
          }
        },
        builder: (context, state) {
          if (state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator());
          } 
          else if (state is DashboardLoaded) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children:[
                  // 1. الإحصائيات العلوية
                  Row(
                    children:[
                      _buildStatCard('العملاء', state.contactsCount.toString(), Icons.people, Colors.blue),
                      const SizedBox(width: 8),
                      _buildStatCard('المجموعات', state.groupsCount.toString(), Icons.group, Colors.orange),
                      const SizedBox(width: 8),
                      _buildStatCard('الحملات', state.schedulesCount.toString(), Icons.rocket, Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // 2. زر تشغيل المحرك السحري
                  ElevatedButton.icon(
                    onPressed: state.isEngineRunning 
                        ? null 
                        : () => context.read<DashboardCubit>().runAutomationEngine(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    icon: state.isEngineRunning 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)) 
                        : const Icon(Icons.play_circle_fill, size: 32),
                    label: Text(
                      state.isEngineRunning ? 'جاري الأتمتة وإرسال الرسائل...' : 'تشغيل محرك الأتمتة الآن 🚀', 
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 3. سجل العمليات
                  const Text('سجل الإرسال الأخير:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Expanded(
                    child: state.recentLogs.isEmpty
                        ? const Center(child: Text('لم يتم إرسال أي رسائل أوتوماتيكية بعد.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: state.recentLogs.length,
                            itemBuilder: (context, index) {
                              final log = state.recentLogs[index];
                              return ListTile(
                                leading: const Icon(Icons.mark_email_read, color: Colors.green),
                                title: Text(log.phone, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(log.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: Text('${log.messageDate.month}/${log.messageDate.day} - ${log.messageDate.hour}:${log.messageDate.minute}', style: const TextStyle(fontSize: 12)),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // أداة صغيرة لبناء كروت الإحصائيات (Clean Code)
  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children:[
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              Text(title, style: TextStyle(color: color.withOpacity(0.8))),
            ],
          ),
        ),
      ),
    );
  }
}