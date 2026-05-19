import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../../../core/enums.dart';
import '../../../match/data/models/models.dart';
import '../widgets/scorecard_tab.dart';
import '../bloc/scoring_bloc.dart';
import '../../../match/presentation/bloc/scoring_event_state.dart';

class InningsBreakPage extends StatefulWidget {
  final InningsBreak state;
  const InningsBreakPage({super.key, required this.state});

  @override
  State<InningsBreakPage> createState() => _InningsBreakPageState();
}

class _InningsBreakPageState extends State<InningsBreakPage> {
  String? strikerId;
  String? nonStrikerId;
  String? bowlerId;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final bowlingTeam = state.completedInnings.battingTeam == state.match.team1Name 
        ? state.match.team2Name 
        : state.match.team1Name;
    
    final batters = state.allPlayers.where((p) => p.teamName == bowlingTeam).toList();
    final bowlers = state.allPlayers.where((p) => p.teamName == state.completedInnings.battingTeam).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Innings Break'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: AppTheme.primaryRed,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'End of 1st Innings',
                      style: AppTheme.titleMedium.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${state.completedInnings.battingTeam} scored',
                      style: AppTheme.bodyLarge.copyWith(color: Colors.white),
                    ),
                    Text(
                      '${state.completedInnings.totalRuns}/${state.completedInnings.totalWickets}',
                      style: AppTheme.headlineLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '(${state.completedInnings.oversDisplay} Overs)',
                      style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '${bowlingTeam} needs ${state.target} runs to win',
              style: AppTheme.titleLarge.copyWith(color: AppTheme.accentTeal, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            Text('1st Innings Scorecard', style: AppTheme.titleLarge),
            const SizedBox(height: 8),
            ScorecardTab(state: state, isScrollable: false),
            const Divider(),
            const SizedBox(height: 32),
            Text('Start 2nd Innings', style: AppTheme.titleLarge.copyWith(color: AppTheme.primaryRed)),
            const SizedBox(height: 16),
            _buildDropdown('Select Striker', batters, strikerId, (v) => setState(() => strikerId = v)),
            const SizedBox(height: 16),
            _buildDropdown('Select Non-Striker', batters.where((p) => p.id != strikerId).toList(), nonStrikerId, (v) => setState(() => nonStrikerId = v)),
            const SizedBox(height: 16),
            _buildDropdown('Select Bowler', bowlers, bowlerId, (v) => setState(() => bowlerId = v)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: strikerId != null && nonStrikerId != null && bowlerId != null
                  ? () {
                      context.read<ScoringBloc>().add(StartSecondInnings(
                            strikerId: strikerId!,
                            nonStrikerId: nonStrikerId!,
                            bowlerId: bowlerId!,
                          ));
                      Navigator.pop(context);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primaryRed,
              ),
              child: const Text('Start 2nd Innings', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<PlayerModel> players, String? value, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: players.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
