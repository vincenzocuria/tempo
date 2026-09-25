import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../data/models/visit_session.dart';
import '../../../data/repositories/visit_repository.dart';
import '../../core/app_colors.dart';
import 'manual_visit_dialog.dart';

class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  List<VisitSession> _visits = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadVisits();
  }

  Future<void> _loadVisits() async {
    setState(() => _isLoading = true);
    final repo = Provider.of<VisitRepository>(context, listen: false);
    final v = await repo.getVisits();
    setState(() {
      _visits = v;
      _isLoading = false;
    });
  }

  void _deleteVisit(String id) async {
    final repo = Provider.of<VisitRepository>(context, listen: false);
    await repo.deleteVisit(id);
    _loadVisits();
  }

  Map<String, List<VisitSession>> _groupVisitsByDay(List<VisitSession> visits) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final fullFormat = DateFormat('EEEE d MMMM yyyy', 'it_IT');

    final groups = <String, List<VisitSession>>{};

    for (final v in visits) {
      if (_searchQuery.isNotEmpty &&
          !v.placeName.toLowerCase().contains(_searchQuery.toLowerCase()) &&
          !v.category.displayName.toLowerCase().contains(_searchQuery.toLowerCase())) {
        continue;
      }

      final dateOnly = DateTime(v.startTime.year, v.startTime.month, v.startTime.day);
      String key;
      if (dateOnly == today) {
        key = 'Oggi';
      } else if (dateOnly == yesterday) {
        key = 'Ieri';
      } else {
        key = fullFormat.format(dateOnly);
        key = key[0].toUpperCase() + key.substring(1);
      }

      groups.putIfAbsent(key, () => []).add(v);
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final textMuted = isDark ? AppColors.textDarkMuted : AppColors.textLightMuted;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final elevatedBg = isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated;
    final timeFormat = DateFormat('HH:mm');
    final grouped = _groupVisitsByDay(_visits);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cronologia'),
        actions: [
          IconButton(
            tooltip: 'Aggiungi visita manuale',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => ManualVisitDialog.show(context, onVisitAdded: _loadVisits),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Cerca per nome o categoria...',
                prefixIcon: const Icon(Icons.search_rounded),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : grouped.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 56,
                                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nessuna visita trovata',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Nessun risultato corrisponde alla ricerca.'
                                    : 'Le visite completate verranno archiviate qui in ordine cronologico.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: textMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadVisits,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: grouped.length,
                          itemBuilder: (context, index) {
                            final dayKey = grouped.keys.elementAt(index);
                            final dayVisits = grouped[dayKey]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    dayKey,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                                    ),
                                  ),
                                ),
                                ...dayVisits.map((v) {
                                  final startStr = timeFormat.format(v.startTime);
                                  final endStr = v.endTime != null
                                      ? timeFormat.format(v.endTime!)
                                      : 'In corso';

                                  return Dismissible(
                                    key: Key(v.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      decoration: BoxDecoration(
                                        color: AppColors.danger,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(Icons.delete_rounded, color: Colors.white),
                                    ),
                                    onDismissed: (_) => _deleteVisit(v.id),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: cardBg,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: borderColor),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: v.category.defaultColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Icon(
                                              v.category.icon,
                                              color: v.category.defaultColor,
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        v.placeName,
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w700,
                                                          color: textPrimary,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (v.isManual) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          'Manuale',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w700,
                                                            color: textMuted,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '$startStr - $endStr',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: textMuted,
                                                  ),
                                                ),
                                                if (v.notes != null && v.notes!.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    v.notes!,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontStyle: FontStyle.italic,
                                                      color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: v.isOngoing
                                                  ? AppColors.primary.withValues(alpha: 0.15)
                                                  : elevatedBg,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              v.formattedDuration,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: v.isOngoing
                                                    ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                                    : textPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
