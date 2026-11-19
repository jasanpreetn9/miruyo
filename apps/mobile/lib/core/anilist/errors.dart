/// rateLimit = 429, retry after [AniListError.retryAfter] seconds.
/// unauthorized = the token we sent was rejected (expired or revoked).
/// network = no response (offline, DNS, timeout). api = anything else AniList reported.
enum AniListErrorKind { rateLimit, unauthorized, network, api }

class AniListError implements Exception {
  const AniListError(this.message, this.kind, {this.status, this.retryAfter});

  final String message;
  final AniListErrorKind kind;
  final int? status;

  /// Seconds; only set for [AniListErrorKind.rateLimit].
  final int? retryAfter;

  bool get isRateLimit => kind == AniListErrorKind.rateLimit;
  bool get isUnauthorized => kind == AniListErrorKind.unauthorized;
  bool get isNetwork => kind == AniListErrorKind.network;

  /// Worth keeping an edit queued for: AniList couldn't take it right now,
  /// but nothing says it's wrong.
  bool get isTransient => isNetwork || isRateLimit;

  @override
  String toString() => 'AniListError(${kind.name}${status == null ? '' : ' $status'}): $message';
}

bool isAniListError(Object? err, [AniListErrorKind? kind]) => err is AniListError && (kind == null || err.kind == kind);
