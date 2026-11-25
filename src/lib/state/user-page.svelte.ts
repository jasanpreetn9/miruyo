import { createContext } from 'svelte';
import {
	fetchActivityHistory,
	fetchListCollection,
	fetchUserList,
	fetchUserProfile,
	isPrivateUser
} from '#lib/anilist/client.ts';
import type {
	ActivityDay,
	CollectionEntry,
	MediaType,
	Profile,
	ScoreFormat,
	UserAccount
} from '#lib/anilist/types.ts';
import { forViewer, isOwnProfile } from '#lib/page-data/user.ts';
import { list } from './list.svelte.ts';
import { Resource } from './resource.svelte.ts';
import { session } from './session.svelte.ts';

/**
 * Someone's page (/user/[name]), yours included (it's your profile): the
 * layout loads who they are once, and its tabs (Overview, Anime list, Manga
 * list, Favourites, Stats) load what they need from here, so switching tabs
 * never fetches the same thing twice.
 */
export class UserPage {
	readonly profile = new Resource<Profile<UserAccount>>();
	readonly lists: Record<MediaType, Resource<CollectionEntry[]>> = {
		ANIME: new Resource(),
		MANGA: new Resource()
	};
	readonly history = new Resource<ActivityDay[]>();

	readonly #name: () => string;
	readonly #server: () => Profile<UserAccount> | null | undefined;

	/** `server`: the signed-out copy rendered on the server, shown until the browser's own arrives. */
	constructor(name: () => string, server: () => Profile<UserAccount> | null | undefined) {
		this.#name = name;
		this.#server = server;
	}

	/** Their profile, as long as it's the one in the URL. */
	get loaded(): Profile<UserAccount> | null {
		const name = this.#name().toLowerCase();
		const mine = (p: Profile<UserAccount> | null | undefined) =>
			p?.account.name.toLowerCase() === name ? p : null;
		return mine(this.profile.data) ?? mine(this.#server());
	}

	get account(): UserAccount | null {
		return this.loaded?.account ?? null;
	}

	/** The signed-in viewer's own page: their profile. */
	get own(): boolean {
		return (
			session.authState === 'in' && !!this.account && isOwnProfile(this.account, session.user?.name)
		);
	}

	/**
	 * The scale their scores come in: yours in your own format (your whole
	 * list, as My List has it); anyone else's out of 10 (fetchUserList).
	 */
	get scoreFormat(): ScoreFormat {
		return this.own ? session.scoreFormat : 'POINT_10_DECIMAL';
	}

	loadProfile(signedIn: boolean): void {
		const name = this.#name();
		if (!name) return;
		void this.profile.load(`${name.toLowerCase()}:${signedIn}`, () =>
			fetchUserProfile(name, { signedIn })
		);
	}

	/**
	 * A list for a list tab or Stats: yours whole (private entries too, the
	 * same request and cache as My List); anyone else's as anyone sees it.
	 */
	loadList(type: MediaType): void {
		// again when a newer copy loaded behind the page (same key: rows stay)
		void list.collectionsVersion;
		const id = this.account?.id;
		if (!id) return;
		const own = this.own;
		void this.lists[type].load(`${id}:${own}`, () =>
			own ? fetchListCollection(id, type) : fetchUserList(id, type)
		);
	}

	loadHistory(): void {
		const id = this.account?.id;
		if (!id) return;
		void this.history.load(String(id), () => fetchActivityHistory(id));
	}

	/**
	 * A list as the viewer is shown it (forViewer): someone else's without 18+
	 * titles unless the viewer's account shows them, as the list tabs do;
	 * yours whole, as My List has it. Stats and the facts card count this.
	 */
	shownList(type: MediaType): CollectionEntry[] | null {
		const entries = this.lists[type].data;
		if (!entries) return null;
		return forViewer(entries, this.own || (session.authState === 'in' && session.showAdultContent));
	}

	/** They keep their list private (AniList says so when it's asked for). */
	isPrivate(type: MediaType): boolean {
		return isPrivateUser(this.lists[type].error);
	}

	reset(): void {
		this.profile.reset();
		this.lists.ANIME.reset();
		this.lists.MANGA.reset();
		this.history.reset();
	}
}

export const [getUserPage, setUserPage] = createContext<UserPage>();
