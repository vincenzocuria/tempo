import '../models/trip.dart';
import '../models/place_category.dart';

import 'dart:convert';

import 'package:intl/intl.dart';

import '../models/place.dart';
import '../models/visit_session.dart';

class ExportService {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  static String exportVisitsToCsv({
    required List<VisitSession> visits,
    required List<Place> places,
  }) {
    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln(
      'ID,Luogo,Categoria,Inizio,Fine,Durata_Secondi,Durata_Formattata,Manuale,Note',
    );

    for (final v in visits) {
      final startStr = _dateFormat.format(v.startTime);
      final endStr = v.endTime != null
          ? _dateFormat.format(v.endTime!)
          : 'In corso';
      final durSec = v.currentDuration.inSeconds;
      final durForm = v.formattedDuration;
      final manual = v.isManual ? 'SI' : 'NO';
      final notes = v.notes ?? '';

      buffer.writeln(
        [
          v.id,
          v.placeName,
          v.category.displayName,
          startStr,
          endStr,
          '$durSec',
          durForm,
          manual,
          notes,
        ].map(_csvField).join(','),
      );
    }
    return buffer.toString();
  }

  static String _csvField(String value) => '"${value.replaceAll('"', '""')}"';

  static String exportDataToJson({
    required List<Place> places,
    required List<VisitSession> visits,
    List<Trip> trips = const [],
    List<PlaceCategory> customCategories = const [],
  }) {
    final data = {
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'Tempo',
      'version': '1.0.25',
      'places': places.map((p) => p.toMap()).toList(),
      'visits': visits.map((v) => v.toMap()).toList(),
      'trips': trips.map((t) => t.toMap()).toList(),
      'customCategories': customCategories.map((c) => c.toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }
}
