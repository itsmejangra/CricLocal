import 'package:get_it/get_it.dart';
import '../core/database/database_helper.dart';
import '../core/services/sync_service.dart';
import '../features/match/data/repositories/match_repository.dart';
import '../features/match/presentation/bloc/scoring_bloc.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // Database
  getIt.registerLazySingleton<DatabaseHelper>(() => DatabaseHelper());

  // Services
  getIt.registerLazySingleton<SyncService>(() => SyncService());

  // Repositories
  getIt.registerLazySingleton<MatchRepository>(() => MatchRepository(getIt<DatabaseHelper>(), getIt<SyncService>()));

  // BLoCs
  getIt.registerFactory<ScoringBloc>(() => ScoringBloc(getIt<MatchRepository>()));
}
