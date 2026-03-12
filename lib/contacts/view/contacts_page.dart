import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart'; // نحتاجه لمعرفة نوع Contact و Group
import '../cubit/contacts_cubit.dart';

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ContactsCubit(
        repository: context.read<CrmRepository>(),
      )..loadContacts(),
      child: const ContactsView(),
    );
  }
}

class ContactsView extends StatelessWidget {
  const ContactsView({super.key});

  // 🌟 نافذة تعيين المجموعة
  void _showAssignGroupDialog(BuildContext context, Contact contact, List<Group> groups) {
    final cubit = context.read<ContactsCubit>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('تعيين مجموعة لـ ${contact.name}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children:[
                // خيار إزالة العميل من أي مجموعة
                ListTile(
                  leading: const Icon(Icons.person_off),
                  title: const Text('بدون مجموعة'),
                  trailing: contact.groupId == null ? const Icon(Icons.check, color: Colors.green) : null,
                  onTap: () {
                    cubit.assignGroup(contact, null);
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                // عرض المجموعات المتاحة
                ...groups.map((g) => ListTile(
                  leading: const Icon(Icons.group, color: Colors.blue),
                  title: Text(g.name),
                  // إظهار علامة صح إذا كان العميل في هذه المجموعة أصلاً
                  trailing: contact.groupId == g.id ? const Icon(Icons.check, color: Colors.green) : null,
                  onTap: () {
                    cubit.assignGroup(contact, g.id);
                    Navigator.pop(context);
                  },
                )).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العملاء (CRM)'),
        actions:[
          IconButton(
            icon: const Icon(Icons.sync_outlined),
            tooltip: 'مزامنة من الهاتف',
            onPressed: () {
              context.read<ContactsCubit>().syncFromPhone();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'تسجيل الخروج',
            onPressed: () {
              context.read<CrmRepository>().signOut();
            },
          ),
        ],
      ),
      body: BlocBuilder<ContactsCubit, ContactsState>(
        builder: (context, state) {
          if (state is ContactsLoading) {
            return const Center(child: CircularProgressIndicator());
          } 
          else if (state is ContactsSyncing) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children:[
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 16),
                  Text('جاري سحب الأسماء من الهاتف...'),
                ],
              ),
            );
          } 
          else if (state is ContactsError) {
            return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
          } 
          else if (state is ContactsLoaded) {
            final contacts = state.contacts;
            final groups = state.groups; // 🌟 استلمنا المجموعات
            
            if (contacts.isEmpty) {
              return const Center(child: Text('لا يوجد عملاء. اضغط على المزامنة بالأعلى.'));
            }

            return ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                
                // البحث عن اسم مجموعة هذا العميل (إن وجدت)
                String groupName = 'بدون مجموعة';
                Color groupColor = Colors.grey;
                if (contact.groupId != null) {
                  try {
                    groupName = groups.firstWhere((g) => g.id == contact.groupId).name;
                    groupColor = Colors.blue;
                  } catch (_) {} // في حال تم حذف المجموعة
                }

                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(contact.phone),
                  // 🌟 إظهار اسم المجموعة كـ "شريحة" (Chip) أنيقة
                  trailing: Chip(
                    label: Text(groupName, style: const TextStyle(fontSize: 12, color: Colors.white)),
                    backgroundColor: groupColor,
                  ),
                  onTap: () => _showAssignGroupDialog(context, contact, groups),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}