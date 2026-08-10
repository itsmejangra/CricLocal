import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../data/models/models.dart';
import '../bloc/scoring_event_state.dart';
import '../utils/phase_analytics_utils.dart';

class InsightsTab extends StatefulWidget {
  final ScoringState state;
  const InsightsTab({super.key, required this.state});

  @override
  State<InsightsTab> createState() => _InsightsTabState();
}

class _InsightsTabState extends State<InsightsTab> {
  int _selectedPhaseIndex = 0;

  @override
  Widget build(BuildContext context) {
    final data = _extractData(widget.state);
    if (data == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Insights will appear once the match has started.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final phases = PhaseAnalyticsUtils.chipRanges(data.match.totalOvers);
    if (_selectedPhaseIndex >= phases.length) _selectedPhaseIndex = 0;
    final selectedPhase = phases[_selectedPhaseIndex];

    final isFullInnings = selectedPhase.endOver == null;
    final team1Stats = PhaseAnalyticsUtils.computeStats(
      data.team1Deliveries,
      selectedPhase,
      innings: isFullInnings ? data.team1Scorecard?.innings : null,
      batsmanStats: isFullInnings ? data.team1Scorecard?.batsmanStats : null,
      bowlerStats: isFullInnings ? data.team1Scorecard?.bowlerStats : null,
    );
    final team2Stats = PhaseAnalyticsUtils.computeStats(
      data.team2Deliveries,
      selectedPhase,
      innings: isFullInnings ? data.team2Scorecard?.innings : null,
      batsmanStats: isFullInnings ? data.team2Scorecard?.batsmanStats : null,
      bowlerStats: isFullInnings ? data.team2Scorecard?.bowlerStats : null,
    );
    final phasesWon = PhaseAnalyticsUtils.computePhasesWon(
      data.team1Deliveries,
      data.team2Deliveries,
      data.match.totalOvers,
    );

    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPhasesHeader(),
            _buildPhaseChips(phases),
            const Divider(height: 1, color: AppTheme.cardBorder),
            _buildTeamHeader(data),
            const Divider(height: 1, color: AppTheme.cardBorder),
            _buildComparisonTable(team1Stats, team2Stats),
            const Divider(height: 24, color: AppTheme.cardBorder),
            _buildPhasesWonSection(data, phasesWon),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPhasesHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Row(
        children: [
          Text('Phases of play', style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppTheme.textHint, size: 20),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseChips(List<PhaseRange> phases) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(phases.length, (index) {
            final selected = index == _selectedPhaseIndex;
            return Padding(
              padding: EdgeInsets.only(right: index < phases.length - 1 ? 8 : 0),
              child: GestureDetector(
                onTap: () => setState(() => _selectedPhaseIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF00695C) : const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    phases[index].label,
                    style: AppTheme.bodyMedium.copyWith(
                      color: selected ? Colors.white : AppTheme.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTeamHeader(_InsightsData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          Expanded(child: _teamColumn(data.team1Name, data.team1Won, data.team1Color, 0)),
          _buildVsDivider(),
          Expanded(child: _teamColumn(data.team2Name, data.team2Won, data.team2Color, 1)),
        ],
      ),
    );
  }

  Widget _teamColumn(String name, bool won, Color color, int teamIndex) {
    final initials = _initials(name);
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: color,
          child: Text(
            initials,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        if (won)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Won',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textHint,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVsDivider() {
    return SizedBox(
      width: 48,
      child: Column(
        children: [
          Container(width: 1, height: 16, color: AppTheme.cardBorder),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.cardBorder),
              color: Colors.white,
            ),
            alignment: Alignment.center,
            child: Text('VS', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          ),
          Container(width: 1, height: 16, color: AppTheme.cardBorder),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(PhaseStats team1, PhaseStats team2) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _comparisonRow('${team1.runs}', 'Runs scored', '${team2.runs}'),
          _comparisonRow('${team1.wickets}', 'Wickets lost', '${team2.wickets}'),
          _comparisonRow('${team1.dots}', 'Dots played', '${team2.dots}'),
          _comparisonRow('${team1.boundaryRuns}', 'Runs in 4s/6s', '${team2.boundaryRuns}'),
          _comparisonRow(
            team1.runRate.toStringAsFixed(2),
            'Run rate',
            team2.runRate.toStringAsFixed(2),
          ),
        ],
      ),
    );
  }

  Widget _comparisonRow(String left, String label, String right) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              left,
              textAlign: TextAlign.center,
              style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              right,
              textAlign: TextAlign.center,
              style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhasesWonSection(_InsightsData data, PhasesWonSummary summary) {
    final total = summary.total;
    final team1Flex = total == 0 ? 1 : summary.team1Phases;
    final sharedFlex = total == 0 ? 0 : summary.sharedPhases;
    final team2Flex = total == 0 ? 1 : summary.team2Phases;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Phases of play won', style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  data.team1Name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                child: Text(
                  'Shared',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                child: Text(
                  data.team2Name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (team1Flex > 0)
                    Expanded(
                      flex: team1Flex,
                      child: Container(color: const Color(0xFF00695C)),
                    ),
                  if (sharedFlex > 0)
                    Expanded(
                      flex: sharedFlex,
                      child: Container(color: AppTheme.textHint),
                    ),
                  if (team2Flex > 0)
                    Expanded(
                      flex: team2Flex,
                      child: Container(color: AppTheme.wicketRed),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${summary.team1Phases} ${summary.team1Phases == 1 ? 'phase' : 'phases'}',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
              ),
              Expanded(
                child: Text(
                  '${summary.sharedPhases} ${summary.sharedPhases == 1 ? 'phase' : 'phases'}',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
              ),
              Expanded(
                child: Text(
                  '${summary.team2Phases} ${summary.team2Phases == 1 ? 'phase' : 'phases'}',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _InsightsData? _extractData(ScoringState state) {
    MatchModel? match;
    List<ScorecardData> scorecards = [];

    if (state is ScoringActive) {
      match = state.match;
      scorecards = state.allScorecards;
    } else if (state is InningsBreak) {
      match = state.match;
      scorecards = state.allScorecards;
    } else if (state is MatchCompleted) {
      match = state.match;
      scorecards = state.allScorecards;
    } else {
      return null;
    }

    if (match == null || scorecards.isEmpty) return null;

    final resolvedMatch = match;
    final team1Scorecards = scorecards.where((s) => s.innings.battingTeam == resolvedMatch.team1Name).toList();
    final team2Scorecards = scorecards.where((s) => s.innings.battingTeam == resolvedMatch.team2Name).toList();

    final team1Scorecard = team1Scorecards.isNotEmpty ? team1Scorecards.first : null;
    final team2Scorecard = team2Scorecards.isNotEmpty ? team2Scorecards.first : null;
    final team1Deliveries = team1Scorecard?.deliveries ?? <DeliveryModel>[];
    final team2Deliveries = team2Scorecard?.deliveries ?? <DeliveryModel>[];

    if (team1Deliveries.isEmpty && team2Deliveries.isEmpty) return null;

    final winner = resolvedMatch.winnerTeam;
    return _InsightsData(
      match: resolvedMatch,
      team1Name: resolvedMatch.team1Name,
      team2Name: resolvedMatch.team2Name,
      team1Scorecard: team1Scorecard,
      team2Scorecard: team2Scorecard,
      team1Deliveries: team1Deliveries,
      team2Deliveries: team2Deliveries,
      team1Won: winner == resolvedMatch.team1Name,
      team2Won: winner == resolvedMatch.team2Name,
      team1Color: const Color(0xFF5E35B1),
      team2Color: AppTheme.winGreen,
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
}

class _InsightsData {
  final MatchModel match;
  final String team1Name;
  final String team2Name;
  final ScorecardData? team1Scorecard;
  final ScorecardData? team2Scorecard;
  final List<DeliveryModel> team1Deliveries;
  final List<DeliveryModel> team2Deliveries;
  final bool team1Won;
  final bool team2Won;
  final Color team1Color;
  final Color team2Color;

  const _InsightsData({
    required this.match,
    required this.team1Name,
    required this.team2Name,
    this.team1Scorecard,
    this.team2Scorecard,
    required this.team1Deliveries,
    required this.team2Deliveries,
    required this.team1Won,
    required this.team2Won,
    required this.team1Color,
    required this.team2Color,
  });
}
