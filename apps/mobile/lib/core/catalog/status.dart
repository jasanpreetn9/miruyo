// Ported from apps/web/src/lib/catalog/status.ts.

import 'dart:ui';

import '../anilist/types.dart';

/// Menu order, in the status dropdown.
const listStatuses = [
  MediaListStatus.current,
  MediaListStatus.completed,
  MediaListStatus.planning,
  MediaListStatus.paused,
  MediaListStatus.dropped,
  MediaListStatus.repeating,
];

/// The secondary colour system. Status always ships with a label or icon:
/// colour is never the only signal.
const statusColor = {
  MediaListStatus.current: Color(0xFF5AB0FF),
  MediaListStatus.completed: Color(0xFF4ED98A),
  MediaListStatus.planning: Color(0xFFB3A996),
  MediaListStatus.paused: Color(0xFFF5B83D),
  MediaListStatus.dropped: Color(0xFFFF6B8B),
  MediaListStatus.repeating: Color(0xFF3DD6D0),
};

const _animeLabels = {
  MediaListStatus.current: 'Watching',
  MediaListStatus.completed: 'Completed',
  MediaListStatus.planning: 'Planning',
  MediaListStatus.paused: 'Paused',
  MediaListStatus.dropped: 'Dropped',
  MediaListStatus.repeating: 'Rewatching',
};

const _mangaLabels = {
  MediaListStatus.current: 'Reading',
  MediaListStatus.completed: 'Completed',
  MediaListStatus.planning: 'Planning',
  MediaListStatus.paused: 'Paused',
  MediaListStatus.dropped: 'Dropped',
  MediaListStatus.repeating: 'Rereading',
};

/// The status verb for the current mode (Watching → Reading, Rewatching → Rereading).
String statusLabel(MediaListStatus status, {required bool isAnime}) => (isAnime ? _animeLabels : _mangaLabels)[status]!;

/// Statuses where progress is still moving, so cards and rows expose +1.
bool isInProgress(MediaListStatus status) =>
    status == MediaListStatus.current || status == MediaListStatus.repeating || status == MediaListStatus.paused;
