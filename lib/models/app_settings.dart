/// General settings that apply across every source at once: which time
/// zone due dates are shown in, and how many days ahead the app looks
/// when deciding what counts as coming up.
class AppSettings {
  /// An IANA time zone identifier, for example "America/Chicago". Due
  /// dates are converted into this zone for display and for deciding
  /// which calendar day an assignment belongs to.
  final String timeZone;

  /// How many days ahead of today to include when trimming the merged
  /// assignment list. Matches the desktop tool's own lookahead setting.
  final int lookaheadDays;

  const AppSettings({
    this.timeZone = 'America/Chicago',
    this.lookaheadDays = 21,
  });

  AppSettings copyWith({String? timeZone, int? lookaheadDays}) {
    return AppSettings(
      timeZone: timeZone ?? this.timeZone,
      lookaheadDays: lookaheadDays ?? this.lookaheadDays,
    );
  }
}
