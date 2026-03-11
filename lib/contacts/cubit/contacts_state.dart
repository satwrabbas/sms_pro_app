part of 'contacts_cubit.dart';

abstract class ContactsState {}

class ContactsInitial extends ContactsState {}

class ContactsLoading extends ContactsState {} // جاري التحميل من قاعدة البيانات

class ContactsSyncing extends ContactsState {} // جاري سحب الأسماء من الهاتف

class ContactsLoaded extends ContactsState {
  final List<Contact> contacts; // Contact هنا قادمة من حزمتنا local_storage_api
  ContactsLoaded({required this.contacts});
}

class ContactsError extends ContactsState {
  final String message;
  ContactsError({required this.message});
}