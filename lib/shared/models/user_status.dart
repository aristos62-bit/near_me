/// Real-time κατάσταση παρουσίας (presence) ενός χρήστη.
///
/// Μεταφέρθηκε από `features/discovery/providers/status_provider.dart`
/// ώστε να είναι προσβάσιμο από το `ProfileRepository` (repository pattern refactor).
class UserStatus {
  final bool isOnline;
  final DateTime? lastSeen;
  const UserStatus({required this.isOnline, this.lastSeen});
}