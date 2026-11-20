import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// App language. `null` = follow the phone's language.
class LocaleCubit extends Cubit<Locale?> {
  LocaleCubit() : super(null);

  void setLocale(Locale? locale) => emit(locale);
}
