import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as phone_contacts;

part 'contacts_state.dart';

class ContactsCubit extends Cubit<ContactsState> {
  ContactsCubit({required CrmRepository repository})
      : _repository = repository,
        super(ContactsInitial());

  final CrmRepository _repository;

  Future<void> loadContacts() async {
    emit(ContactsLoading());
    try {
      final contacts = await _repository.getContacts();
      emit(ContactsLoaded(contacts: contacts));
    } catch (e) {
      emit(ContactsError(message: e.toString()));
    }
  }

  Future<void> syncFromPhone() async {
    emit(ContactsSyncing());
    try {
      // 🚀 التصحيح الأول: أضفنا نوع الصلاحية المطلوبة
      final status = await phone_contacts.FlutterContacts.permissions.request(
        phone_contacts.PermissionType.read, // نريد فقط قراءة الأسماء
      );

      if (status == phone_contacts.PermissionStatus.granted || status == phone_contacts.PermissionStatus.limited) {
        final contactsFromPhone = await phone_contacts.FlutterContacts.getAll(
          properties: {
            phone_contacts.ContactProperty.name,
            phone_contacts.ContactProperty.phone,
          },
        );

        final List<Map<String, String>> formattedContacts =[];
        for (var c in contactsFromPhone) {
          if (c.phones.isNotEmpty) {
            formattedContacts.add({
              // 🚀 التصحيح الثاني: أضفنا قيمة افتراضية في حال كان الاسم فارغاً
              'name': c.displayName ?? 'بدون اسم',
              'phone': c.phones.first.number,
            });
          }
        }

        await _repository.saveSyncedContacts(formattedContacts);
        
        await loadContacts();
      } else {
        emit(ContactsError(message: 'تم رفض صلاحية الوصول لجهات الاتصال'));
      }
    } catch (e) {
      emit(ContactsError(message: 'حدث خطأ أثناء المزامنة: $e'));
    }
  }
}