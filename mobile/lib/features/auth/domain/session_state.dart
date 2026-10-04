enum SessionStatus { initial, authenticated, unauthenticated, expired }

class SessionState {
  final SessionStatus status;
  final String? userId;
  final String? userEmail;

  const SessionState({required this.status, this.userId, this.userEmail});

  const SessionState.initial()
    : status = SessionStatus.initial,
      userId = null,
      userEmail = null;

  const SessionState.unauthenticated()
    : status = SessionStatus.unauthenticated,
      userId = null,
      userEmail = null;

  const SessionState.authenticated({
    required this.userId,
    required this.userEmail,
  }) : status = SessionStatus.authenticated;

  const SessionState.expired({this.userId, this.userEmail})
    : status = SessionStatus.expired;

  bool get isAuthenticated => status == SessionStatus.authenticated;
  bool get isExpired => status == SessionStatus.expired;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          userId == other.userId &&
          userEmail == other.userEmail;

  @override
  int get hashCode => Object.hash(status, userId, userEmail);
}
