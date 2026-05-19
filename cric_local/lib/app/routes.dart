
import 'package:go_router/go_router.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/match/presentation/pages/match_detail_page.dart';
import '../features/match/presentation/pages/new_match_page.dart';
import '../features/scoring/presentation/pages/score_input_page.dart';
import '../features/home/presentation/pages/player_stats_page.dart';
import '../features/match/presentation/pages/live_viewer_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(path: '/match/new', builder: (context, state) => const NewMatchPage()),
    GoRoute(path: '/match/:id', builder: (context, state) {
      final matchId = state.pathParameters['id']!;
      return MatchDetailPage(matchId: matchId);
    }),
    GoRoute(path: '/match/:id/score', builder: (context, state) {
      final matchId = state.pathParameters['id']!;
      return ScoreInputPage(matchId: matchId);
    }),
    GoRoute(path: '/player/stats/:name', builder: (context, state) {
      final name = state.pathParameters['name']!;
      return PlayerStatsPage(playerName: name);
    }),
    GoRoute(path: '/live/:id', builder: (context, state) {
      final matchId = state.pathParameters['id']!;
      return LiveViewerPage(initialMatchId: matchId);
    }),
  ],
);
