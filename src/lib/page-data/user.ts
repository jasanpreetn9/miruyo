import type { TitlePreference } from '#lib/anilist/adapt.ts';
import type {
	CollectionEntry,
	MediaListStatus,
	ScoreFormat,
	UserAccount
} from '#lib/anilist/types.ts';
import { LIST_STATUSES } from '#lib/catalog/status.ts';
import { buildListView, sortsFor, type ListSort, type ListView } from './list.ts';
import { anilistUrl } from '#lib/anilist/adapt.ts';
import { parseDescription, type Fact } from './markdown.ts';
import type { PersonHeader } from './person.ts';

// Someone else's page (/user/[name]): their profile, and their lists read-only.
// The list is My List's view (buildListView) without the editing: their
// scores arrive out of 10 with decimals (fetchUserList), whatever their own
// score format, so they read the same for everyone.

/** A list tab's `?status=completed`; Watching / Reading when there's none. */
export function statusParam(value: string | null): MediaListStatus {
	const status = value?.toUpperCase() as MediaListStatus;
	return LIST_STATUSES.includes(status) ? status : 'CURRENT';
}

/** The sorts on someone else's list: My List's, less "Most to watch", which is about your next episode. */
export function userSortsFor(status: MediaListStatus, isAnime: boolean) {
	return sortsFor(status, isAnime).filter((s) => s.key !== 'toWatch');
}

/** Completed opens best first (what people look at someone's list for); the rest, latest first. */
export function defaultUserSort(status: MediaListStatus): ListSort {
	return status === 'COMPLETED' ? 'score' : 'updated';
}

export interface UserListOptions {
	status: MediaListStatus;
	sort?: ListSort;
	filter?: string;
	/** A humanized format ("TV", "Movie"), or '' for all. */
	format?: string;
	genre?: string;
	country?: string;
	year?: number | null;
	isAnime: boolean;
	titles?: TitlePreference;
	/** The viewer's own adult-content setting: 18+ titles are left out unless it's on. */
	adult: boolean;
	/** The scale the scores came in (UserPage.scoreFormat). */
	scoreFormat?: ScoreFormat;
	now: number;
	timeZone?: string;
}

/**
 * Someone's list as this viewer is shown it: without 18+ titles unless
 * `adult` (the viewer's own setting, or the list is the viewer's). The list
 * tabs, Stats and the facts card all count this, so their totals match.
 */
export function forViewer(entries: CollectionEntry[], adult: boolean): CollectionEntry[] {
	return adult ? entries : entries.filter((e) => !e.media.isAdult);
}

/** Their list on one status, with every status's count (empty ones left out). */
export function buildUserList(entries: CollectionEntry[], options: UserListOptions): ListView {
	const view = buildListView(forViewer(entries, options.adult), {
		tab: options.status,
		sort: options.sort ?? defaultUserSort(options.status),
		filter: options.filter,
		format: options.format,
		genre: options.genre,
		country: options.country,
		year: options.year,
		isAnime: options.isAnime,
		titles: options.titles,
		scoreFormat: options.scoreFormat ?? 'POINT_10_DECIMAL',
		now: options.now,
		timeZone: options.timeZone
	});
	return { ...view, tabs: view.tabs.filter((t) => t.count > 0 || t.status === options.status) };
}

/** "matchai's" / "Ines'". */
export function possessive(name: string): string {
	return name.endsWith('s') ? `${name}’` : `${name}’s`;
}

/** Whether a profile is the viewer's own (names match whatever the case). */
export function isOwnProfile(
	account: Pick<UserAccount, 'name'>,
	viewerName: string | null | undefined
) {
	return !!viewerName && viewerName.toLowerCase() === account.name.toLowerCase();
}

/**
 * A user page's header, in a staff page's shape (PersonLayout): the avatar,
 * "Follows you" under the name, the bio, and a facts card. `memberSince` is
 * buildProfile's ("Member since March 2019"), said as "Member since · March
 * 2019"; `numbers` are the Overview's Stats cards for the mode (Total anime,
 * Episodes watched…), so the card and Stats never disagree. AniList's own
 * totals (User.statistics) leave out Planning and lag, so they aren't used.
 */
export function userHeader(
	account: UserAccount,
	{
		own,
		memberSince,
		numbers
	}: { own: boolean; memberSince: string | null; numbers: Pick<Fact, 'label' | 'value'>[] }
): PersonHeader {
	const since = memberSince?.replace(/^Member since /, '');
	const facts: Fact[] = [
		...(since ? [{ label: 'Member since', value: since }] : []),
		...numbers.filter((f) => f.value && f.value !== '—')
	];
	return {
		name: account.name,
		native: !own && account.isFollower ? 'Follows you' : null,
		altNames: [],
		spoilerNames: [],
		image: account.avatar?.large ?? null,
		facts,
		bio: parseDescription(account.about).paragraphs,
		favourites: '',
		isFavourite: false,
		anilistHref: anilistUrl(
			account.siteUrl,
			`https://anilist.co/user/${encodeURIComponent(account.name)}`
		)
	};
}
