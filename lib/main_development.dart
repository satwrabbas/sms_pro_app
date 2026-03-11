import 'package:flutter/widgets.dart';
import 'package:local_storage_api/local_storage_api.dart';
import 'package:cloud_storage_api/cloud_storage_api.dart'; // استدعاء حزمة السحابة
import 'package:supabase_flutter/supabase_flutter.dart'; // ضروري للتهيئة
import 'package:my_pro_app/app/app.dart';
import 'package:my_pro_app/bootstrap.dart';

// تحويل الدالة إلى async لأن تهيئة Supabase تأخذ وقتاً
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ☁️ تهيئة الاتصال بـ Supabase
  await Supabase.initialize(
    url: 'https://trqowiapaafxxsvnmnwy.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRycW93aWFwYWFmeHhzdm5tbnd5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5OTY1MjEsImV4cCI6MjA4ODU3MjUyMX0.tni1GYt5QEyouSKGUhTpsLAS2Mmy1M2_c9ty72WslSY',
  );

  // 💾 إنشاء نسخة من قاعدة البيانات المحلية
  final database = AppDatabase();

  // ☁️ إنشاء نسخة من عميل السحابة
  final cloudClient = CloudStorageClient();

  // 🚀 تمرير الاثنين للتطبيق (سندخلهم لاحقاً في المدير Repository)
  bootstrap(() => App(
    database: database,
    cloudClient: cloudClient, 
  ));
}