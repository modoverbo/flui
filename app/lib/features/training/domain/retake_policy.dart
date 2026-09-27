import 'package:flui/core/date/local_date.dart';

/// Client-side mirror of the server's 30-day retake trigger (design D8):
/// used only to show the user when a retake becomes available. The server
/// trigger is authoritative — an early retake is rejected there regardless
/// of what this policy says.
final class RetakePolicy {
  const new();

  static const cooldownDays = 30;

  LocalDate nextAvailableOn(LocalDate lastDiagnosedOn) =>
      lastDiagnosedOn.addDays(cooldownDays);

  bool isAvailable({
    required LocalDate lastDiagnosedOn,
    required LocalDate today,
  }) => !today.isBefore(nextAvailableOn(lastDiagnosedOn));
}
