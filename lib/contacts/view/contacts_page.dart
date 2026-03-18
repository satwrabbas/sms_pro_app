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
      create: (context) => ContactsCubit(repository: context.read<CrmRepository>())..loadContacts(),
      child: const ContactsView(),
    );
  }
}

class ContactsView extends StatefulWidget {
  const ContactsView({super.key});

  @override
  State<ContactsView> createState() => _ContactsViewState();
}

class _ContactsViewState extends State<ContactsView> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  // 🌟 متغيرات الميزات الجديدة
  int? _selectedFilterGroupId; // null = الكل, -1 = بدون مجموعة
  final Set<Contact> _selectedContacts = {}; // قائمة العملاء المحددين

  bool get _isMultiSelectMode => _selectedContacts.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // النوافذ (Dialogs & BottomSheets)
  // ==========================================

  // 1. نافذة تعيين المجموعة (سواء لعميل واحد أو لعدة عملاء)
  void _showAssignGroupDialog(BuildContext context, List<Group> groups, {Contact? singleContact}) {
    final cubit = context.read<ContactsCubit>();
    final isBulk = singleContact == null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isBulk ? 'تعيين مجموعة لـ ${_selectedContacts.length} عملاء' : 'تعيين مجموعة لـ ${singleContact.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children:[
              ListTile(
                leading: const Icon(Icons.person_off),
                title: const Text('بدون مجموعة'),
                onTap: () {
                  isBulk ? cubit.assignGroupToMultiple(_selectedContacts.toList(), null) : cubit.assignGroup(singleContact!, null);
                  if (isBulk) setState(() => _selectedContacts.clear()); // إنهاء وضع التحديد
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ...groups.map((g) => ListTile(
                leading: const Icon(Icons.group, color: Colors.blue),
                title: Text(g.name),
                onTap: () {
                  isBulk ? cubit.assignGroupToMultiple(_selectedContacts.toList(), g.id) : cubit.assignGroup(singleContact!, g.id);
                  if (isBulk) setState(() => _selectedContacts.clear());
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  // 2. نافذة تعديل بيانات العميل
  void _showEditContactDialog(BuildContext context, Contact contact) {
    final nameController = TextEditingController(text: contact.name);
    final phoneController = TextEditingController(text: contact.phone);
    final cubit = context.read<ContactsCubit>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل بيانات العميل ✏️'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children:[
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم')),
            const SizedBox(height: 8),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
          ],
        ),
        actions:[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                cubit.editContact(contact, nameController.text.trim(), phoneController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );
  }

  // 3. القائمة السفلية (BottomSheet) للإجراءات السريعة
  void _showContactOptions(BuildContext context, Contact contact, List<Group> groups) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children:[
            const SizedBox(height: 8),
            Text(contact.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(contact.phone, style: const TextStyle(color: Colors.grey)),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.label, color: Colors.blue),
              title: const Text('تعيين مجموعة'),
              onTap: () { Navigator.pop(context); _showAssignGroupDialog(context, groups, singleContact: contact); },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.teal),
              title: const Text('تعديل البيانات'),
              onTap: () { Navigator.pop(context); _showEditContactDialog(context, contact); },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('حذف العميل', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                context.read<ContactsCubit>().deleteContact(contact);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // واجهة المستخدم (UI)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContactsCubit, ContactsState>(
      builder: (context, state) {
        
        // 🌟 بناء شريط التطبيق (يتغير إذا كنا في وضع التحديد المتعدد)
        final appBar = _isMultiSelectMode
            ? AppBar(
                backgroundColor: Colors.teal,
                leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => _selectedContacts.clear())),
                title: Text('${_selectedContacts.length} محدد', style: const TextStyle(color: Colors.white)),
                actions:[
                  IconButton(
                    icon: const Icon(Icons.group_add, color: Colors.white),
                    tooltip: 'تعيين مجموعة للمحددين',
                    onPressed: () {
                      if (state is ContactsLoaded) {
                        _showAssignGroupDialog(context, state.groups);
                      }
                    },
                  ),
                ],
              )
            : AppBar(
                title: const Text('العملاء (CRM)'),
                actions:[
                  IconButton(icon: const Icon(Icons.sync_outlined), tooltip: 'مزامنة من الهاتف', onPressed: () => context.read<ContactsCubit>().syncFromPhone()),
                  IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), tooltip: 'تسجيل الخروج', onPressed: () => context.read<CrmRepository>().signOut()),
                ],
              );

        return Scaffold(
          appBar: appBar,
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ContactsState state) {
    if (state is ContactsLoading) return const Center(child: CircularProgressIndicator());
    if (state is ContactsSyncing) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[CircularProgressIndicator(color: Colors.green), SizedBox(height: 16), Text('جاري سحب الأسماء...')]));
    }
    if (state is ContactsError) return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
    if (state is ContactsLoaded) {
      final contacts = state.contacts;
      final groups = state.groups;

      // 🌟 التصفية المزدوجة (بحث نصي + تصفية بالمجموعة)
      final filteredContacts = contacts.where((c) {
        // 1. فلتر البحث النصي
        final matchesSearch = c.name.toLowerCase().contains(_searchQuery.toLowerCase()) || c.phone.contains(_searchQuery);
        // 2. فلتر المجموعات
        bool matchesGroup = true;
        if (_selectedFilterGroupId == -1) {
          matchesGroup = c.groupId == null; // بدون مجموعة
        } else if (_selectedFilterGroupId != null) {
          matchesGroup = c.groupId == _selectedFilterGroupId;
        }
        return matchesSearch && matchesGroup;
      }).toList();

      return Column(
        children:[
          // شريط البحث
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو رقم الهاتف...', prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }) : null,
                filled: true, fillColor: Colors.grey[200], border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
          
          // 🌟 شريط شرائح التصفية (Filter Chips)
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children:[
                ChoiceChip(
                  label: const Text('الكل'), selected: _selectedFilterGroupId == null,
                  onSelected: (val) => setState(() => _selectedFilterGroupId = null),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('بدون مجموعة', style: TextStyle(color: Colors.deepOrange)), selected: _selectedFilterGroupId == -1,
                  onSelected: (val) => setState(() => _selectedFilterGroupId = val ? -1 : null),
                ),
                const SizedBox(width: 8),
                ...groups.map((g) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(g.name, style: TextStyle(color: _selectedFilterGroupId == g.id ? Colors.white : Colors.black)),
                    selectedColor: Colors.blue,
                    selected: _selectedFilterGroupId == g.id,
                    onSelected: (val) => setState(() => _selectedFilterGroupId = val ? g.id : null),
                  ),
                )),
              ],
            ),
          ),

          const Divider(),

          // 🌟 قائمة العملاء المصفاة
          Expanded(
            child: filteredContacts.isEmpty
                ? const Center(child: Text('لم يتم العثور على عميل يطابق بحثك 🕵️‍♂️', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = filteredContacts[index];
                      final isSelected = _selectedContacts.contains(contact);
                      
                      String groupName = 'بدون مجموعة';
                      Color groupColor = Colors.grey;
                      if (contact.groupId != null) {
                        try {
                          groupName = groups.firstWhere((g) => g.id == contact.groupId).name;
                          groupColor = Colors.blue;
                        } catch (_) {} 
                      }

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: Colors.teal.withOpacity(0.1),
                        // تغيير الأيقونة لمربع تحديد إذا كنا في وضع التحديد المتعدد
                        leading: _isMultiSelectMode
                            ? Checkbox(
                                value: isSelected,
                                activeColor: Colors.teal,
                                onChanged: (_) {
                                  setState(() {
                                    isSelected ? _selectedContacts.remove(contact) : _selectedContacts.add(contact);
                                  });
                                })
                            : const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(contact.phone),
                        trailing: Chip(label: Text(groupName, style: const TextStyle(fontSize: 10, color: Colors.white)), backgroundColor: groupColor),
                        
                        // 🌟 ضغطة مطولة لبدء التحديد المتعدد
                        onLongPress: () {
                          setState(() { _selectedContacts.add(contact); });
                        },
                        
                        // 🌟 ضغطة عادية
                        onTap: () {
                          if (_isMultiSelectMode) {
                            // إذا كنا في وضع التحديد، الضغطة تحدد/تلغي التحديد
                            setState(() { isSelected ? _selectedContacts.remove(contact) : _selectedContacts.add(contact); });
                          } else {
                            // إذا كان الوضع طبيعياً، نفتح خيارات العميل
                            _showContactOptions(context, contact, groups);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}