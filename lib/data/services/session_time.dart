/// Counts only the part of a session inside a half-open calendar interval.
class SessionTime {
  static int seconds(
    DateTime start,
    DateTime? end, {
    DateTime? from,
    DateTime? to,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    var finish = end ?? clock;
    if (finish.isAfter(clock)) finish = clock;
    if (to != null && finish.isAfter(to)) finish = to;
    final begin = from != null && start.isBefore(from) ? from : start;
    return finish.isAfter(begin) ? finish.difference(begin).inSeconds : 0;
  }

  static String dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  static Map<String, int> daily(
    DateTime start,
    DateTime? end, {
    DateTime? from,
    DateTime? to,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final begin = from != null && start.isBefore(from) ? from : start;
    var finish = end ?? clock;
    if (finish.isAfter(clock)) finish = clock;
    if (to != null && finish.isAfter(to)) finish = to;
    final result = <String, int>{};
    var day = DateTime(begin.year, begin.month, begin.day);
    while (day.isBefore(finish)) {
      // Calendar construction also handles days with daylight-saving changes.
      final next = DateTime(day.year, day.month, day.day + 1);
      final value = seconds(
        start,
        end,
        from: day.isBefore(begin) ? begin : day,
        to: next.isAfter(finish) ? finish : next,
        now: clock,
      );
      if (value > 0) result[dayKey(day)] = value;
      day = next;
    }
    return result;
  }

  static double distance(
    double meters,
    DateTime start,
    DateTime? end, {
    DateTime? from,
    DateTime? to,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final whole = seconds(start, end, now: clock);
    if (whole <= 0) return 0;
    return meters * seconds(start, end, from: from, to: to, now: clock) / whole;
  }
}
