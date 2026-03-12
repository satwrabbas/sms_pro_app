import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/home_cubit.dart';
import 'package:my_pro_app/campaigns/view/campaigns_page.dart';
// استدعاء شاشة جهات الاتصال التي صنعناها
import 'package:my_pro_app/contacts/view/contacts_page.dart'; 

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit(),
      child: const HomeView(),
    );
  }
}

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    // رقم الصفحة المحددة حالياً
    final selectedTab = context.watch<HomeCubit>().state;

    // قائمة الشاشات (سنضيف الشاشات الأخرى لاحقاً)
    final List<Widget> pages =[
      // 1. لوحة التحكم (مؤقتة لحين برمجتها)
      const Scaffold(
        body: Center(
          child: Text('📊 لوحة التحكم (قريباً)', style: TextStyle(fontSize: 24)),
        ),
      ),
      
      // 2. شاشة جهات الاتصال (التي تعمل بنجاح)
      const ContactsPage(),
      
      // 3. شاشة الحملات (مؤقتة لحين برمجتها)
      const CampaignsPage(),
    ];

    return Scaffold(
      // نعرض الشاشة بناءً على الرقم المختار
      body: IndexedStack(
        index: selectedTab,
        children: pages,
      ),
      
      // شريط التنقل السفلي
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          context.read<HomeCubit>().setTab(index); // تغيير الصفحة
        },
        destinations: const[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'العملاء',
          ),
          NavigationDestination(
            icon: Icon(Icons.rocket_launch_outlined),
            selectedIcon: Icon(Icons.rocket_launch),
            label: 'الحملات',
          ),
        ],
      ),
    );
  }
}