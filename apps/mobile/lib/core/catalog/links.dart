// Links from the API, ported from apps/web/src/lib/anilist/adapt.ts.

/// A link to another site from the API (a title's external links), or null
/// when it isn't http(s), so an unexpected value never becomes a link.
Uri? externalUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty ? uri : null;
}
