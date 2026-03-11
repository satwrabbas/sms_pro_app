import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:cloud_storage_api/cloud_storage_api.dart'; // لجلب AuthException

part 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit({required CrmRepository repository})
      : _repository = repository,
        super(LoginInitial());

  final CrmRepository _repository;

  /// دالة تسجيل الدخول
  Future<void> signIn({required String email, required String password}) async {
    emit(LoginLoading());
    try {
      await _repository.signIn(email: email, password: password);
      emit(LoginSuccess());
    } on AuthException catch (e) {
      emit(LoginError(message: e.message)); // رسالة الخطأ من السحابة (مثلاً الباسورد خطأ)
    } catch (e) {
      emit(LoginError(message: 'حدث خطأ غير متوقع: $e'));
    }
  }

  /// دالة إنشاء حساب جديد
  Future<void> signUp({required String email, required String password}) async {
    emit(LoginLoading());
    try {
      await _repository.signUp(email: email, password: password);
      emit(LoginSuccess());
    } on AuthException catch (e) {
      emit(LoginError(message: e.message));
    } catch (e) {
      emit(LoginError(message: 'حدث خطأ غير متوقع: $e'));
    }
  }
}