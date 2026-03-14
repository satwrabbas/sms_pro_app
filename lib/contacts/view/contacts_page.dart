import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart';
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

// 🌟 حولناها إلى StatefulWidget لنتمكن من إدارة مربع البحث
class ContactsView extends StatefulWidget {
  const ContactsView({super.key});

  @override
  State<ContactsView> createState() => _ContactsViewState();
}

class _ContactsViewState extends State<ContactsView> {
  // متغيرات البحث
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // نافذة تعيين المجموعة
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
                ...groups.map((g) => ListTile(
                  leading: const Icon(Icons.group, color: Colors.blue),
                  title: Text(g.name),
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
            final groups = state.groups; 
            
            if (contacts.isEmpty) {
              return const Center(child: Text('لا يوجد عملاء. اضغط على المزامنة بالأعلى.'));
            }

            // 🌟 السحر هنا: تصفية العملاء بناءً على نص البحث (بالاسم أو الرقم)
            final filteredContacts = contacts.where((c) {
              final nameMatch = c.name.toLowerCase().contains(_searchQuery.toLowerCase());
              final phoneMatch = c.phone.contains(_searchQuery);
              return nameMatch || phoneMatch; // يطابق الاسم أو رقم الهاتف
            }).toList();

            return Column(
              children:[
                // 🌟 مربع البحث الجميل
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value; // تحديث الشاشة عند كتابة أي حرف
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'ابحث بالاسم أو رقم الهاتف...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      // زر مسح البحث يظهر فقط إذا كان هناك نص مكتوب
                      suffixIcon: _searchQuery.isNotEmpty 
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            ) 
                          : null,
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                
                // 🌟 قائمة العملاء المصفاة
                Expanded(
                  child: filteredContacts.isEmpty
                      ? const Center(child: Text('لم يتم العثور على عميل يطابق بحثك 🕵️‍♂️', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: filteredContacts.length,
                          itemBuilder: (context, index) {
                            final contact = filteredContacts[index];
                            
                            String groupName = 'بدون مجموعة';
                            Color groupColor = Colors.grey;
                            if (contact.groupId != null) {
                              try {
                                groupName = groups.firstWhere((g) => g.id == contact.groupId).name;
                                groupColor = Colors.blue;
                              } catch (_) {} 
                            }

                            return ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(contact.phone),
                              trailing: Chip(
                                label: Text(groupName, style: const TextStyle(fontSize: 12, color: Colors.white)),
                                backgroundColor: groupColor,
                              ),
                              onTap: () => _showAssignGroupDialog(context, contact, groups),
                            );
                          },
                        ),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}