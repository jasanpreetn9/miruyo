import { fetchListCollection, fetchRecommendations, fetchRelations } from '#lib/anilist/client.ts';
import type { MediaType, ScoreFormat } from '#lib/anilist/types.ts';
import {
	buildPicks,
	DEFAULT_TUNE,
	MAX_CROSS_SEEDS,
	MIN_RATINGS,
	pickSeeds,
	scoredCount,
	type Pick,
	type Seed,
	type Tune
} from '#lib/page-data/for-you.ts';
import { addToPrefSet, readPref, readPrefSet, writePref } from '#lib/state/prefs.ts';
import { FOR_YOU_DISMISSED_STORAGE_KEY, FOR_YOU_TUNE_STORAGE_KEY } from '#lib/storage-keys.ts';

export interface ForYou {
	/** Fewer than MIN_RATINGS scored titles: picks wouldn't be worth much yet. */
	coldStart: boolean;
	/** How many titles on the list carry a score. */
	scored: number;
	seeds: Seed[];
	/** Titles you loved on your other list, whose manga or anime joined the picks. */
	crossSeeds: Seed[];
	picks: Pick[];
}

/**
 * Loads For You for one list (anime or manga): the list (the same cached
 * request as My List and Stats), then AniList's recommendations for the
 * day's seeds: highly rated titles on it, a different set each `day`. "Not this" picks are filtered by the caller,
 * so hiding one needs no new request.
 */
export async function loadForYou({
	userId,
	type,
	scoreFormat,
	showAdult,
	day
}: {
	userId: number;
	type: MediaType;
	scoreFormat?: ScoreFormat;
	showAdult: boolean;
	/** localDay(): which day's seeds. */
	day: string;
}): Promise<ForYou> {
	const other = type === 'ANIME' ? 'MANGA' : 'ANIME';
	// the other list loads alongside this one, not after it (loadCross never throws)
	const crossing = loadCross(userId, other, scoreFormat, day);
	const entries = await fetchListCollection(userId, type);
	const scored = scoredCount(entries);
	if (scored < MIN_RATINGS) {
		// too few ratings here for picks of its own, but titles loved on the
		// other list can still suggest their manga (or anime)
		const cross = await crossing;
		const picks = buildPicks([], new Map(), {
			entries,
			scoreFormat,
			type,
			showAdult,
			dismissed: new Set(),
			crossSeeds: cross.seeds,
			relations: cross.relations
		});
		return picks.length
			? { coldStart: false, scored, seeds: [], crossSeeds: cross.seeds, picks }
			: { coldStart: true, scored, seeds: [], crossSeeds: [], picks: [] };
	}
	const seeds = pickSeeds(entries, scoreFormat, day);
	const [recommendations, cross] = await Promise.all([
		fetchRecommendations(seeds.map((s) => s.id)),
		crossing
	]);
	const picks = buildPicks(seeds, recommendations, {
		entries,
		scoreFormat,
		type,
		showAdult,
		dismissed: new Set(),
		crossSeeds: cross.seeds,
		relations: cross.relations
	});
	return { coldStart: false, scored, seeds, crossSeeds: cross.seeds, picks };
}

/**
 * The cross seeds (the day's top titles on your other list) and their
 * relations. It's extra: if either request fails, For You goes on without it.
 */
async function loadCross(
	userId: number,
	other: MediaType,
	scoreFormat: ScoreFormat | undefined,
	day: string
) {
	try {
		const list = await fetchListCollection(userId, other);
		// the other list needs enough ratings to say what you loved
		if (scoredCount(list) < MIN_RATINGS) return { seeds: [], relations: new Map() };
		const seeds = pickSeeds(list, scoreFormat, day).slice(0, MAX_CROSS_SEEDS);
		return { seeds, relations: await fetchRelations(seeds.map((s) => s.id)) };
	} catch (err) {
		console.error('For You: no picks from the other list:', err);
		return { seeds: [], relations: new Map() };
	}
}

/** Picks hidden with "Not this"; they don't come back. */
class Dismissed {
	ids = $state(new Set<number>());

	constructor() {
		this.ids = new Set([...readPrefSet(FOR_YOU_DISMISSED_STORAGE_KEY)].map(Number));
	}

	add(id: number) {
		addToPrefSet(FOR_YOU_DISMISSED_STORAGE_KEY, String(id));
		this.ids = new Set([...this.ids, id]);
	}

	remove(id: number) {
		const next = new Set(this.ids);
		next.delete(id);
		writePref(FOR_YOU_DISMISSED_STORAGE_KEY, JSON.stringify([...next]));
		this.ids = next;
	}
}

export const dismissed = new Dismissed();

/** "Tune picks", kept on the device; a missing or broken value is the default. */
class TuneState {
	value = $state<Tune>({ ...DEFAULT_TUNE });

	constructor() {
		try {
			const raw = readPref(FOR_YOU_TUNE_STORAGE_KEY);
			if (raw) {
				const saved = JSON.parse(raw) as Partial<Tune>;
				this.value = {
					outOnly: saved.outOnly === true,
					crossMode: saved.crossMode !== false,
					hiddenGenres: Array.isArray(saved.hiddenGenres)
						? saved.hiddenGenres.filter((g) => typeof g === 'string')
						: []
				};
			}
		} catch {
			// the default
		}
	}

	set(next: Partial<Tune>) {
		this.value = { ...this.value, ...next };
		writePref(FOR_YOU_TUNE_STORAGE_KEY, JSON.stringify(this.value));
	}

	toggleGenre(genre: string) {
		const hidden = this.value.hiddenGenres;
		this.set({
			hiddenGenres: hidden.includes(genre) ? hidden.filter((g) => g !== genre) : [...hidden, genre]
		});
	}

	reset() {
		this.set({ ...DEFAULT_TUNE });
	}

	/** Whether anything is tuned away from the default. */
	get changed(): boolean {
		const v = this.value;
		return v.outOnly || !v.crossMode || v.hiddenGenres.length > 0;
	}
}

export const tune = new TuneState();
