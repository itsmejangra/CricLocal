
import 'package:go_router/go_router.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/match/presentation/pages/match_detail_page.dart';
import '../features/match/presentation/pages/new_match_page.dart';
import '../features/scoring/presentation/pages/score_input_page.dart';
import '../features/home/presentation/pages/player_stats_page.dart';
import '../features/match/presentation/pages/live_viewer_page.dart';
import '../features/streaming/presentation/pages/go_live_page.dart';
import '../features/streaming/presentation/pages/watch_live_page.dart';
import '../features/match/presentation/pages/saved_teams_page.dart';
import '../features/home/presentation/pages/leaderboards_page.dart';
import '../features/home/presentation/pages/awards_page.dart';
import '../features/home/presentation/pages/contact_page.dart';
import '../features/home/presentation/pages/explorer_page.dart';
import '../features/home/presentation/pages/profile_page.dart';
import '../features/home/presentation/pages/notification_page.dart';
import '../features/home/presentation/pages/head_to_head_page.dart';
import '../features/match/presentation/pages/match_fees_page.dart';
import '../features/home/presentation/pages/player_rankings_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(path: '/match/new', builder: (context, state) => const NewMatchPage()),
    GoRoute(path: '/match/:id', builder: (context, state) {
      final matchId = state.pathParameters['id']!;
      final tab = state.uri.queryParameters['tab'];
      final initialTabIndex = switch (tab) {
        'summary' => 0,
        'scorecard' => 1,
        'insights' => 2,
        'comms' => 3,
        'squads' => 4,
        'mvp' => 5,
        _ => 2,
      };
      return MatchDetailPage(matchId: matchId, initialTabIndex: initialTabIndex);
    }),
    GoRoute(path: '/match/:id/score', builder: (context, state) {
      final matchId = state.pathParameters['id']!;
      return ScoreInputPage(matchId: matchId);
    }),
    GoRoute(path: '/player/stats/:name', builder: (context, state) {
      final name = state.pathParameters['name']!;
      final creatorId = state.uri.queryParameters['creatorId'];
      return PlayerStatsPage(playerName: name, creatorId: creatorId);
    }),
    GoRoute(path: '/live/:id', builder: (context, state) {
      final matchId = state.pathParameters['id']!;
      final tab = state.uri.queryParameters['tab'];
      final initialTabIndex = switch (tab) {
        'scorecard' => 1,
        'insights' => 2,
        'comms' => 3,
        'squads' => 4,
        'mvp' => 5,
        _ => 0,
      };
      return LiveViewerPage(initialMatchId: matchId, initialTabIndex: initialTabIndex);
    }),
    GoRoute(path: '/match/:id/go-live', builder: (context, state) {
      final matchId = state.pathParameters['id']!;
      final title = state.uri.queryParameters['title'] ?? 'Live Match';
      return GoLivePage(matchId: matchId, matchTitle: title);
    }),
    GoRoute(path: '/match/:id/watch-live', builder: (context, state) {
      final matchId = state.pathParameters['id']!;
      final title = state.uri.queryParameters['title'] ?? 'Live Match';
      return WatchLivePage(matchId: matchId, matchTitle: title);
    }),
    GoRoute(path: '/teams', builder: (context, state) => const SavedTeamsPage()),
    GoRoute(path: '/leaderboards', builder: (context, state) => const LeaderboardsPage()),
    GoRoute(path: '/rankings', builder: (context, state) {
      final creatorId = state.uri.queryParameters['creatorId'];
      return PlayerRankingsPage(creatorId: creatorId);
    }),
    GoRoute(path: '/awards', builder: (context, state) => const AwardsPage()),
    GoRoute(path: '/contact', builder: (context, state) => const ContactPage()),
    GoRoute(path: '/associations', builder: (context, state) => const ExplorerPage(title: 'Associations', type: 'Association')),
    GoRoute(path: '/clubs', builder: (context, state) => const ExplorerPage(title: 'Clubs', type: 'Club')),
    GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
    GoRoute(path: '/notifications', builder: (context, state) => const NotificationPage()),
    GoRoute(path: '/head-to-head', builder: (context, state) {
      final creatorId = state.uri.queryParameters['creatorId'];
      return HeadToHeadPage(creatorId: creatorId);
    }),
    GoRoute(path: '/match/:id/fees', builder: (context, state) {
      final matchId = state.pathParameters['id']!;
      return MatchFeesPage(matchId: matchId);
    }),
  ],
);
