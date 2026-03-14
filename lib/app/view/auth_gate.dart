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
          // 🌟 السحر هنا: نطلب من التطبيق تنزيل البيانات قبل الدخول للرئيسية
          return FutureBuilder(
            // نستخدم دالة التنزيل التي بنيناها سابقاً
            future: repository.downloadAllFromCloud(),
            builder: (context, downloadSnapshot) {
              
              // طالما أنه لا يزال يحمل، نعرض شاشة تهيئة جميلة
              if (downloadSnapshot.connectionState == ConnectionState.waiting) {
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
              
              // بمجرد الانتهاء (سواء نجح أو فشل بسبب غياب الإنترنت)، ندخله للرئيسية!
              return const HomePage();
            },
          );
        } else {
          return const LoginPage();
        }
      },
    );
  }
}