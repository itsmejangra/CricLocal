import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../../core/enums.dart';
import '../../../match/data/models/models.dart';

class WicketModal extends StatefulWidget {
  final Function(DismissalType type, String? fielderId, String? fielder2Id, String? dismissedId) onConfirm;
  final List<PlayerModel> players;
  final PlayerModel? striker;
  final PlayerModel? nonStriker;
  final InningsModel? innings;

  const WicketModal({super.key, required this.onConfirm, required this.players, this.striker, this.nonStriker, this.innings});
  @override
  State<WicketModal> createState() => _WicketModalState();
}

class _WicketModalState extends State<WicketModal> {
  DismissalType _type = DismissalType.bowled;
  String? _fielderId;
  String? _fielder2Id;
  String? _dismissedId;

  @override
  void initState() {
    super.initState();
    _dismissedId = widget.striker?.id;
  }

  List<PlayerModel> get _fieldingPlayers =>
    widget.players.where((p) => widget.innings != null && p.teamName == widget.innings!.bowlingTeam).toList();

  bool get _needsFielder => [DismissalType.caught, DismissalType.runOut, DismissalType.stumped].contains(_type);
  bool get _needsTwoFielders => _type == DismissalType.runOut;
  bool get _canSelectDismissed => _type == DismissalType.runOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: AppTheme.cardBorder, borderRadius: BorderRadius.circular(2)))),
        Text('Wicket!', style: AppTheme.headlineMedium.copyWith(color: AppTheme.wicketRed)),
        const SizedBox(height: 16),
        Text('Dismissal Type', style: AppTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: DismissalType.values.map((t) =>
          ChoiceChip(label: Text(t.displayName), selected: _type == t,
            selectedColor: AppTheme.wicketRed.withValues(alpha: 0.2),
            onSelected: (_) => setState(() { _type = t; _fielderId = null; _fielder2Id = null; }))).toList()),
        if (_canSelectDismissed) ...[
          const SizedBox(height: 16),
          Text('Who is out?', style: AppTheme.titleMedium),
          const SizedBox(height: 8),
          Row(children: [
            if (widget.striker != null) Expanded(child: _selectChip(widget.striker!.name, _dismissedId == widget.striker!.id, () => setState(() => _dismissedId = widget.striker!.id))),
            const SizedBox(width: 8),
            if (widget.nonStriker != null) Expanded(child: _selectChip(widget.nonStriker!.name, _dismissedId == widget.nonStriker!.id, () => setState(() => _dismissedId = widget.nonStriker!.id))),
          ]),
        ],
        if (_needsFielder) ...[
          const SizedBox(height: 16),
          Text(_needsTwoFielders ? 'Fielder 1 (thrower)' : 'Fielder', style: AppTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(initialValue: _fielderId,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Select fielder'),
            items: _fieldingPlayers.map((p) => DropdownMenuItem(value: p.id, child: Text(p.displayName))).toList(),
            onChanged: (v) => setState(() => _fielderId = v)),
        ],
        if (_needsTwoFielders) ...[
          const SizedBox(height: 12),
          Text('Fielder 2 (stumps end)', style: AppTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: _fielder2Id,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Select fielder'),
            items: _fieldingPlayers.where((p) => p.id != _fielderId).map((p) => DropdownMenuItem(value: p.id, child: Text(p.displayName))).toList(),
            onChanged: (v) => setState(() => _fielder2Id = v)),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () { Navigator.pop(context);
            widget.onConfirm(_type, _fielderId, _fielder2Id, _dismissedId ?? widget.striker?.id); },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.wicketRed, padding: const EdgeInsets.symmetric(vertical: 14)),
          child: const Text('Confirm Wicket', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _selectChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: selected ? AppTheme.wicketRed.withValues(alpha: 0.1) : AppTheme.backgroundGray,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? AppTheme.wicketRed : AppTheme.cardBorder, width: selected ? 2 : 1)),
      child: Center(child: Text(label, style: AppTheme.bodyMedium.copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? AppTheme.wicketRed : AppTheme.textPrimary))),
    ));
  }
}
