import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:cloud_storage_api/cloud_storage_api.dart'; 
import 'package:my_pro_app/login/view/login_page.dart';
import 'package:my_pro_app/home/view/home_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<CrmRepository>();

    return StreamBuilder<AuthState>(
      stream: repository.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final session = snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          // 🌟 نستخدم الشاشة الذكية الجديدة هنا لمنع التكرار
          return const WorkspaceInitializer();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

// ==========================================
// 🌟 الشاشة الذكية للتهيئة (تعمل مرة واحدة فقط!)
// ==========================================
class WorkspaceInitializer extends StatefulWidget {
  const WorkspaceInitializer({super.key});

  @override
  State<WorkspaceInitializer> createState() => _WorkspaceInitializerState();
}

class _WorkspaceInitializerState extends State<WorkspaceInitializer> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    // 🌟 السحر هنا: نطلب التنزيل من السحابة مرة واحدة فقط عند فتح الشاشة!
    _initFuture = context.read<CrmRepository>().downloadAllFromCloud();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        
        // شاشة التحميل الأنيقة
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children:[
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 24),
                  Text('جاري تهيئة مساحة العمل...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('يتم الآن جلب عملائك وحملاتك من السحابة ☁️', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }
        
        // بمجرد الانتهاء، ندخله للرئيسية ولن يعود للتحميل مجدداً
        return const HomePage();
      },
    );
  }
}