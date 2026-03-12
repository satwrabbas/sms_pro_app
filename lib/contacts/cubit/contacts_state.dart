part of 'contacts_cubit.dart';

abstract class ContactsState {}

class ContactsInitial extends ContactsState {}

class ContactsLoading extends ContactsState {} 

class ContactsSyncing extends ContactsState {} 

class ContactsLoaded extends ContactsState {
  final List<Contact> contacts;
  final List<Group> groups; // 🌟 أضفنا قائمة المجموعات هنا
  
  ContactsLoaded({required this.contacts, required this.groups});
}

class ContactsError extends ContactsState {
  final String message;
  ContactsError({required this.message});
}