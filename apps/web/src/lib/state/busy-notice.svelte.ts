/**
 * Section errors on screen that already say AniList is rate limiting
 * (SectionError, counting itself in while it does). The session's banner
 * stays quiet while any does, so the page says it once.
 */
export const busyCards = $state({ count: 0 });
