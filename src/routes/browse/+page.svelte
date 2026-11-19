<script lang="ts">
	import CoverImage from '#lib/components/shared/CoverImage.svelte';
	import { untrack } from 'svelte';
	import { fade, fly } from 'svelte/transition';
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { adaptMedia } from '#lib/anilist/adapt.ts';
	import { fetchBrowse, fetchBrowseCollections } from '#lib/anilist/client.ts';
	import type { AniListMedia, BrowseCollectionsResponse } from '#lib/anilist/types.ts';
	import {
		activeFilters,
		activePreset,
		browsePresets,
		browseTitle,
		DEFAULT_STATE,
		isRanked,
		parseBrowseParams,
		SORTS,
		toQueryVariables,
		toSearchParams,
		withoutFilters,
		type BrowseState
	} from '#lib/browse/params.ts';
	import { STATUS_COLOR, statusLabel } from '#lib/catalog/status.ts';
	import type { Title } from '#lib/catalog/types.ts';
	import BrowseFilters from '#lib/components/browse/BrowseFilters.svelte';
	import SearchPeople from '#lib/components/browse/SearchPeople.svelte';
	import SectionError from '#lib/components/home/SectionError.svelte';
	import PosterCard from '#lib/components/shared/PosterCard.svelte';
	import Skeleton from '#lib/components/shared/Skeleton.svelte';
	import PageShell from '#lib/components/shared/PageShell.svelte';
	import { entryFromTitle, list } from '#lib/state/list.svelte.ts';
	import { loadListState } from '#lib/state/list-state.ts';
	import { changeStatus } from '#lib/state/list-actions.ts';
	import { PagedResults } from '#lib/state/paged.svelte.ts';
	import { searchFocus } from '#lib/state/search.svelte.ts';
	import { session } from '#lib/state/session.svelte.ts';

	// The URL is the source of truth for every filter (browse/params.ts), so
	// results can be shared and the back button walks through changes.

	const isAnime = $derived(session.mode === 'anime');
	const filters = $derived(parseBrowseParams(page.url.searchParams, isAnime));
	const signedIn = $derived(session.authState === 'in');
	const chips = $derived(activeFilters(filters, isAnime));
	/** Set when a "See all" opened a named list (Trending, Popular releasing…). */
	const listTitle = $derived(browseTitle(filters, isAnime));
	const presets = $derived(browsePresets(isAnime));
	const preset = $derived(activePreset(filters, isAnime));
	/** Ranked lists number their results (#1, #2…). */
	const ranked = $derived(isRanked(filters));

	function presetHref(state: Partial<BrowseState>): string {
		const qs = toSearchParams({ ...DEFAULT_STATE, ...state, view: filters.view }).toString();
		return qs ? `?${qs}` : page.url.pathname;
	}

	const accent = $derived(isAnime ? 'var(--color-anime)' : 'var(--color-manga)');
	const accentInk = $derived(isAnime ? 'var(--color-anime-ink)' : 'var(--color-manga-ink)');
	const chipStyle = $derived(
		isAnime
			? 'background:rgba(255,106,85,.14);border:1px solid rgba(255,106,85,.4);color:#FFB3A6'
			: 'background:rgba(160,140,255,.16);border:1px solid rgba(160,140,255,.45);color:#CFC4FF'
	);

	/** Writes `next` to the URL without moving scroll or focus. */
	function navigate(next: BrowseState, { replace = false } = {}) {
		const qs = toSearchParams(next).toString();
		void goto(qs ? `?${qs}` : page.url.pathname, { replace, reset: false });
	}

	function apply(patch: Partial<BrowseState>, options?: { replace?: boolean }) {
		navigate({ ...filters, ...patch }, options);
	}

	// Drop params that don't fit (another mode's season/country/formats, typos)
	// so the URL always says what's actually being searched.
	$effect(() => {
		const normal = toSearchParams(filters).toString();
		if (normal !== page.url.searchParams.toString()) {
			untrack(() => navigate(filters, { replace: true }));
		}
	});

	// ── Search box: typed text is debounced into the URL ──
	const SEARCH_DEBOUNCE = 300;
	let query = $state(untrack(() => filters.q));
	let searchTimer: ReturnType<typeof setTimeout> | undefined;

	// the URL's q changed from elsewhere (back button, a chip, a suggestion)
	$effect(() => {
		const q = filters.q;
		untrack(() => {
			if (q !== query.trim()) query = q;
		});
	});

	function onSearchInput() {
		clearTimeout(searchTimer);
		searchTimer = setTimeout(() => apply({ q: query }, { replace: true }), SEARCH_DEBOUNCE);
	}

	function onSearchKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			query = '';
			clearTimeout(searchTimer);
			apply({ q: '' }, { replace: true });
		} else if (e.key === 'Enter') {
			clearTimeout(searchTimer);
			apply({ q: query }, { replace: true });
		}
	}

	let desktopSearch = $state<HTMLInputElement>();
	let mobileSearch = $state<HTMLInputElement>();

	// ⌘K / the Search tab / the top bar's search pill: focus whichever search
	// box is showing at this width
	$effect(() => {
		if (!searchFocus.pending || !desktopSearch || !mobileSearch) return;
		searchFocus.consume();
		const input = desktopSearch.offsetParent ? desktopSearch : mobileSearch;
		input.focus();
		input.select();
	});

	// ── Genres and tags for the filter rail ──
	let collections = $state<BrowseCollectionsResponse | null>(null);
	$effect(() => {
		fetchBrowseCollections()
			.then((c) => (collections = c))
			.catch((err) => console.error('Failed to load genres and tags:', err));
	});
	/** AniList's only adult genre; like 18+ tags, hidden unless the account allows adult content. */
	const ADULT_GENRES = new Set(['Hentai']);
	const genres = $derived(
		(collections?.GenreCollection ?? []).filter(
			(g) => session.showAdultContent || !ADULT_GENRES.has(g)
		)
	);
	const tags = $derived(
		(collections?.MediaTagCollection ?? []).filter((t) => session.showAdultContent || !t.isAdult)
	);

	// ── Results ──
	const results = new PagedResults<AniListMedia>();
	const queryContext = $derived({
		type: isAnime ? ('ANIME' as const) : ('MANGA' as const),
		signedIn,
		showAdult: session.showAdultContent
	});

	$effect(() => {
		// wait for the account: it decides the token, onList and 18+ filtering
		if (session.authState === 'loading') return;
		const ctx = queryContext;
		const state = filters;
		const key = JSON.stringify(toQueryVariables(state, ctx));
		untrack(() =>
			results.load(
				key,
				async (pageNumber) => {
					const vars = toQueryVariables(state, { ...ctx, page: pageNumber });
					const data = await fetchBrowse(vars, { signedIn: ctx.signedIn });
					return {
						items: data.media,
						total: exactTotal(data, pageNumber, Number(vars.perPage)),
						hasMore: data.pageInfo.hasNextPage
					};
				},
				{ onItems: seedList }
			)
		);
	});

	$effect(() => () => results.reset());

	/**
	 * AniList's pageInfo.total is a placeholder (5000) until the last page, so
	 * a count is only exact once there are no more pages.
	 */
	function exactTotal(
		data: { pageInfo: { hasNextPage: boolean }; media: unknown[] },
		pageNumber: number,
		perPage: number
	): number | null {
		return data.pageInfo.hasNextPage ? null : (pageNumber - 1) * perPage + data.media.length;
	}

	/** Signed in: list state for each page of results (the search can't carry it — see BROWSE_QUERY). */
	function seedList(media: AniListMedia[]) {
		void loadListState(media.map((m) => m.id));
	}

	// while searching, the characters, staff and studios it matches come after
	// the first two rows of titles (on a phone, two rows of two)
	const peopleAfter = { desktop: 10, mobile: 4 };

	const titles = $derived<Title[]>(
		results.items.map((m) =>
			adaptMedia(m, undefined, { titles: signedIn ? 'userPreferred' : 'english' })
		)
	);

	/** Starts loading the next page when the end of the results scrolls near. */
	function loadMoreWhenVisible(node: HTMLElement) {
		const observer = new IntersectionObserver(
			([entry]) => {
				if (entry.isIntersecting) void results.loadMore();
			},
			{ rootMargin: '600px 0px' }
		);
		observer.observe(node);
		return () => observer.disconnect();
	}

	// ── No results: suggest the closest match without the filters ──
	let suggestion = $state<string | null>(null);
	$effect(() => {
		const state = filters;
		const ctx = queryContext;
		const empty = !results.loading && !results.failed && results.total === 0;
		suggestion = null;
		if (!empty || !state.q.trim() || !chips.length) return;
		let cancelled = false;
		fetchBrowse(toQueryVariables(withoutFilters(state), { ...ctx, perPage: 1 }), {
			signedIn: ctx.signedIn
		})
			.then((data) => {
				const top = data.media[0];
				if (!cancelled && top) {
					suggestion = adaptMedia(top, undefined, {
						titles: ctx.signedIn ? 'userPreferred' : 'english'
					}).title;
				}
			})
			.catch(() => {});
		return () => (cancelled = true);
	});

	function searchSuggestion() {
		if (!suggestion) return;
		query = suggestion;
		navigate({ ...withoutFilters(filters), q: suggestion });
	}

	// ── List view: add / show status per row ──
	function addFromRow(title: Title) {
		if (!list.sync) {
			if (session.authState === 'out') void goto('/login');
			return;
		}
		void changeStatus(title, 'PLANNING');
	}

	// ── Mobile filter sheet: edits a draft, applied with "Show N results" ──
	let sheetOpen = $state(false);
	let draft = $state<BrowseState>(untrack(() => filters));
	/** "Show 7 results" / "Show 50+ results" — see exactTotal() on why it can't be exact past a page. */
	let draftCount = $state<string | null>(null);
	const SHEET_COUNT_LIMIT = 50;

	function openSheet() {
		draft = { ...filters };
		sheetOpen = true;
	}

	function applySheet() {
		navigate({ ...draft, q: filters.q });
		sheetOpen = false;
	}

	// the sheet's button counts what the draft would show
	$effect(() => {
		if (!sheetOpen || session.authState === 'loading') return;
		const vars = toQueryVariables(
			{ ...draft, q: filters.q },
			{ ...queryContext, perPage: SHEET_COUNT_LIMIT }
		);
		const signed = queryContext.signedIn;
		draftCount = null;
		let cancelled = false;
		const timer = setTimeout(() => {
			fetchBrowse(vars, { signedIn: signed })
				.then((data) => {
					if (cancelled) return;
					draftCount = data.pageInfo.hasNextPage
						? `${SHEET_COUNT_LIMIT}+`
						: data.media.length.toLocaleString('en-US');
				})
				.catch(() => {});
		}, SEARCH_DEBOUNCE);
		return () => {
			cancelled = true;
			clearTimeout(timer);
		};
	});

	// exact once every page is in; until then, how many are loaded so far
	const resultCount = $derived(
		results.total !== null
			? results.total.toLocaleString('en-US')
			: results.items.length
				? `${results.items.length.toLocaleString('en-US')}+`
				: ''
	);
</script>

<svelte:head>
	<title>{listTitle ?? (isAnime ? 'Browse anime' : 'Browse manga')} · miruyo</title>
</svelte:head>

{#snippet chipRow(extra: string)}
	{#if chips.length}
		<div class="flex items-center gap-2 {extra}">
			{#each chips as chip (chip.key)}
				<button
					type="button"
					onclick={() => apply(chip.without)}
					aria-label="Remove filter: {chip.label}"
					class="flex h-8 flex-none press items-center gap-1 rounded-[2px] py-0 pr-2 pl-3 text-[13px] font-semibold"
					style={chipStyle}
				>
					{chip.label}
					<span class="material-symbols-rounded !text-[16px]" aria-hidden="true">close</span>
				</button>
			{/each}
			<button
				type="button"
				onclick={() => navigate(withoutFilters(filters))}
				class="h-8 flex-none px-2.5 text-[13px] font-semibold text-muted hover:text-ink"
			>
				Clear all
			</button>
		</div>
	{/if}
{/snippet}

<!-- the ready-made lists, while not searching -->
{#snippet presetRow(extra: string)}
	{#if !filters.q}
		<nav class="flex gap-5 border-b border-line {extra}" aria-label="Lists">
			{#each presets as p (p.key)}
				{@const on = preset === p.key}
				<a
					href={presetHref(p.state)}
					aria-current={on ? 'page' : undefined}
					class="flex h-9 flex-none items-center px-1 text-[14px] {on
						? 'font-semibold text-ink shadow-[inset_0_-2px_0_var(--color-anime)] hover:text-ink'
						: 'font-medium text-muted hover:text-ink'}"
				>
					{p.label}
				</a>
			{/each}
		</nav>
	{/if}
{/snippet}

{#snippet rank(i: number)}
	<span
		class="pointer-events-none absolute top-1.5 left-1.5 z-[1] rounded-[2px] bg-black/70 px-1.5 py-0.5 font-mono text-xs font-bold text-white backdrop-blur-sm"
		>#{i + 1}</span
	>
{/snippet}

{#snippet emptyState()}
	<div class="flex flex-col items-center gap-3 py-16 text-center lg:py-20" data-testid="no-results">
		<div
			class="grid h-16 w-16 place-items-center rounded-[2px] border border-line bg-raised text-dim"
		>
			<span class="material-symbols-rounded !text-[32px]" aria-hidden="true">search_off</span>
		</div>
		<div class="font-display text-xl font-bold">
			{filters.q ? `Nothing for “${filters.q}”` : 'No titles match your filters'}
		</div>
		<div class="max-w-xs text-sm leading-relaxed text-muted">
			{#if suggestion}
				Did you mean
				<button type="button" onclick={searchSuggestion} class="font-semibold text-anime-soft"
					>{suggestion}</button
				>?
			{:else}
				Try a different search{chips.length ? ' or fewer filters' : ''}.
			{/if}
			{#if chips.length}
				You {suggestion ? 'also ' : ''}have {chips.length}
				{chips.length === 1 ? 'filter' : 'filters'} on.
			{/if}
		</div>
		<div class="mt-1.5 flex flex-wrap justify-center gap-2">
			{#if chips.length}
				<button
					type="button"
					onclick={() => navigate(withoutFilters(filters))}
					class="h-11 press btn-quiet px-4 text-sm font-semibold"
				>
					Clear filters
				</button>
			{/if}
			{#if suggestion}
				<button
					type="button"
					onclick={searchSuggestion}
					class="h-11 press rounded-[2px] px-4 text-sm font-semibold"
					style="background:{accent};color:{accentInk}"
				>
					Search “{suggestion}”
				</button>
			{:else if filters.q}
				<button
					type="button"
					onclick={() => {
						query = '';
						apply({ q: '' });
					}}
					class="h-11 press rounded-[2px] px-4 text-sm font-semibold"
					style="background:{accent};color:{accentInk}"
				>
					Clear search
				</button>
			{/if}
		</div>
	</div>
{/snippet}

{#snippet loadingGrid(cols: string, count: number)}
	<div class="grid {cols}" aria-busy="true" aria-label="Loading results">
		{#each { length: count } as _, i (i)}
			<div class="flex flex-col gap-2.5">
				<Skeleton class="aspect-2/3 w-full rounded-[2px]" />
				<Skeleton class="h-3.5 w-4/5" />
				<Skeleton class="h-3 w-1/2" />
			</div>
		{/each}
	</div>
{/snippet}

{#snippet desktopTitles(part: Title[], from: number)}
	{#if filters.view === 'grid'}
		<div class="grid grid-cols-5 gap-x-5 gap-y-8">
			{#each part as t, j (t.id)}
				<div class="relative">
					{#if ranked}{@render rank(from + j)}{/if}
					<PosterCard title={t} loggedOut={session.authState === 'out'} />
				</div>
			{/each}
		</div>
	{:else}
		<div class="flex flex-col border-t border-ink">
			{#if from === 0}
				<div
					class="grid {ranked
						? 'grid-cols-[36px_56px_minmax(0,1fr)_90px_90px_80px_130px_120px]'
						: 'grid-cols-[56px_minmax(0,1fr)_90px_90px_80px_130px_120px]'} gap-4 border-b border-line px-1 py-2.5 text-[11px] font-semibold tracking-[0.1em] text-dim uppercase"
				>
					{#if ranked}<div>#</div>{/if}
					<div></div>
					<div>Title</div>
					<div>Format</div>
					<div>Length</div>
					<div>Score</div>
					<div>Status</div>
					<div></div>
				</div>
			{/if}
			{#each part as t, j (t.id)}
				{@const entry = session.authState === 'out' ? null : list.entryFor(t)}
				<div
					class="grid {ranked
						? 'grid-cols-[36px_56px_minmax(0,1fr)_90px_90px_80px_130px_120px]'
						: 'grid-cols-[56px_minmax(0,1fr)_90px_90px_80px_130px_120px]'} items-center gap-4 border-b border-line px-1 py-2 hover:bg-raised"
				>
					{#if ranked}
						<div class="font-mono text-sm font-bold text-muted">{from + j + 1}</div>
					{/if}
					<div
						class="relative aspect-2/3 w-10 self-start overflow-hidden rounded-[2px]"
						style="background:{t.placeholder}"
					>
						<CoverImage title={t} />
					</div>
					<div class="flex min-w-0 flex-col gap-0.5">
						<a
							href="/title/{t.id}"
							class="truncate text-sm font-semibold text-ink hover:text-ink hover:underline"
							>{t.title}</a
						>
						<div class="truncate text-xs text-dim">{t.genres.join(' · ')}</div>
					</div>
					<div class="text-[13px] text-muted">{t.format}</div>
					<div class="font-mono text-[13px] text-muted">{t.countLabel}</div>
					<div class="flex items-center gap-1 font-mono text-[13px] font-semibold">
						<span
							class="material-symbols-rounded !text-[15px]"
							style="color:var(--color-gold);font-variation-settings:'FILL' 1"
							aria-hidden="true">star</span
						>
						{t.score || '—'}
					</div>
					<div class="text-[13px] text-muted">{t.status}</div>
					<div class="flex justify-end">
						{#if entry}
							<span
								class="flex h-8 items-center gap-1 rounded-[2px] border border-white/10 px-2.5 text-xs font-semibold"
								style="color:{STATUS_COLOR[entry.status]}"
							>
								<span class="material-symbols-rounded !text-[16px]" aria-hidden="true">check</span>
								{statusLabel(entry.status, isAnime)}
							</span>
						{:else}
							<button
								type="button"
								onclick={() => addFromRow(t)}
								aria-label="Add {t.title} to Planning"
								class="flex h-8 press items-center gap-1 rounded-[2px] px-2.5 text-xs font-semibold"
								style="background:{accent};color:{accentInk}"
							>
								<span class="material-symbols-rounded !text-[16px]" aria-hidden="true">add</span>
								Add
							</button>
						{/if}
					</div>
				</div>
			{/each}
		</div>
	{/if}
{/snippet}

{#snippet people()}
	{#if filters.q}
		<SearchPeople q={filters.q} {isAnime} titles={signedIn ? 'userPreferred' : 'english'} />
	{/if}
{/snippet}

{#snippet mobileTitles(part: Title[], from: number)}
	<div class="grid grid-cols-2 gap-x-3 gap-y-5 md:grid-cols-4">
		{#each part as t, j (t.id)}
			<div class="relative">
				{#if ranked}{@render rank(from + j)}{/if}
				<PosterCard title={t} size="sm" loggedOut={session.authState === 'out'} />
			</div>
		{/each}
	</div>
{/snippet}

{#snippet moreResults()}
	{#if results.hasMore || results.loadingMore}
		<div class="flex justify-center py-6" {@attach loadMoreWhenVisible}>
			<button
				type="button"
				onclick={() => results.loadMore()}
				disabled={results.loadingMore}
				class="h-11 press btn-quiet px-5 text-sm font-semibold disabled:opacity-60"
			>
				{results.loadingMore ? 'Loading…' : 'Load more'}
			</button>
		</div>
	{:else if results.error && results.items.length}
		<!-- loading the next page failed; what's loaded stays -->
		<div class="flex flex-col items-center gap-2 py-6 text-center text-sm text-muted">
			{results.rateLimited && results.retry.active
				? `AniList is busy — trying again in ${results.retry.label}.`
				: "Couldn't load more results."}
			<button
				type="button"
				onclick={() => results.retryNow()}
				class="h-10 btn-quiet px-4 font-semibold"
			>
				Retry now
			</button>
		</div>
	{/if}
{/snippet}

<PageShell nav="browse" tab="browse">
	<!-- desktop -->
	<div class="hidden lg:block">
		<div
			class="flex flex-col gap-5 px-20 pt-10 pb-6"
			style="background:radial-gradient(700px 240px at 20% 0%, {isAnime
				? 'rgba(255,106,85,.10)'
				: 'rgba(160,140,255,.12)'}, transparent 70%)"
		>
			<h1 class="m-0 font-display text-[56px] leading-[0.92] font-light tracking-[-0.045em]">
				{listTitle ?? (isAnime ? 'Browse anime' : 'Browse manga')}
			</h1>
			<div class="flex h-14 items-center gap-3 field-line px-1">
				<span class="material-symbols-rounded !text-[24px] text-muted" aria-hidden="true"
					>search</span
				>
				<input
					bind:this={desktopSearch}
					bind:value={query}
					oninput={onSearchInput}
					onkeydown={onSearchKeydown}
					aria-label="Search"
					type="search"
					placeholder={isAnime
						? 'Search anime, studios, characters…'
						: 'Search manga, authors, characters…'}
					class="flex-1 border-0 bg-transparent text-[17px] text-ink outline-none placeholder:text-dim"
				/>
				<span class="font-mono text-xs text-dim">Esc to clear</span>
			</div>
			{@render presetRow('flex-wrap')}
		</div>

		<div class="grid grid-cols-[272px_1fr] gap-10 px-20 pt-2 pb-20">
			<aside aria-label="Filters">
				<BrowseFilters
					state={filters}
					{isAnime}
					{signedIn}
					{genres}
					{tags}
					onChange={(patch) => apply(patch)}
					idPrefix="rail"
				/>
			</aside>

			<div data-testid="browse-results" class="flex min-w-0 flex-col gap-[18px]">
				<div class="flex items-center gap-3">
					<div class="text-[15px]" aria-live="polite">
						{#if resultCount}
							<b class="font-mono">{resultCount}</b> <span class="text-muted">results</span>
						{/if}
					</div>
					<div class="flex-1"></div>
					<label class="flex h-10 items-center gap-2 field-line pr-1 pl-0.5 text-sm">
						<span class="material-symbols-rounded !text-[18px] text-dim" aria-hidden="true"
							>sort</span
						>
						<span class="sr-only">Sort by</span>
						<select
							value={filters.sort}
							onchange={(e) => apply({ sort: e.currentTarget.value as BrowseState['sort'] })}
							class="h-8 border-0 bg-transparent py-0 pr-8 pl-0 text-sm text-ink focus:ring-0"
						>
							{#each SORTS as s (s.key)}
								<option value={s.key}>{s.label}</option>
							{/each}
						</select>
					</label>
					<div class="inline-flex gap-1" role="radiogroup" aria-label="View">
						{#each [{ key: 'grid', icon: 'grid_view', label: 'Grid' }, { key: 'list', icon: 'view_list', label: 'Compact list' }] as v (v.key)}
							{@const on = filters.view === v.key}
							<button
								type="button"
								role="radio"
								aria-checked={on}
								onclick={() => apply({ view: v.key as BrowseState['view'] })}
								aria-label={v.label}
								class="grid h-[34px] w-9 place-items-center rounded-[2px]"
								style="color:{on ? 'var(--color-ink)' : 'var(--color-dim)'};box-shadow:{on
									? 'inset 0 -1.5px 0 var(--color-anime)'
									: 'none'}"
							>
								<span class="material-symbols-rounded !text-[20px]" aria-hidden="true"
									>{v.icon}</span
								>
							</button>
						{/each}
					</div>
				</div>

				{@render chipRow('flex-wrap')}

				{#if results.pending}
					{@render loadingGrid('grid-cols-5 gap-x-5 gap-y-8', 10)}
				{:else if results.failed}
					<SectionError
						title="Couldn't load results"
						onRetry={() => results.retryNow()}
						detail={results.error}
						retryIn={results.retry.active ? results.retry.label : undefined}
						rateLimited={results.rateLimited}
					/>
					{@render people()}
				{:else if !results.stale && results.total === 0}
					{@render emptyState()}
					{@render people()}
				{:else}
					<div
						class="flex flex-col gap-8 transition-opacity duration-(--duration-overlay) {results.stale
							? 'opacity-50'
							: ''}"
						aria-busy={results.stale}
					>
						{@render desktopTitles(titles.slice(0, peopleAfter.desktop), 0)}
						{@render people()}
						{#if titles.length > peopleAfter.desktop}
							{@render desktopTitles(titles.slice(peopleAfter.desktop), peopleAfter.desktop)}
						{/if}
					</div>
					{@render moreResults()}
				{/if}
			</div>
		</div>
	</div>

	<!-- mobile -->
	<div class="flex flex-col gap-3 px-4 pt-3 lg:hidden">
		{#if listTitle}
			<h1
				class="m-0 pt-1 font-display text-[34px] leading-[0.95] font-light tracking-[-0.04em] lg:text-[44px]"
			>
				{listTitle}
			</h1>
		{/if}
		<div class="flex gap-2">
			<div class="flex h-12 flex-1 items-center gap-2 field-line px-1 text-[15px]">
				<span class="material-symbols-rounded !text-[22px] text-muted" aria-hidden="true"
					>search</span
				>
				<input
					bind:this={mobileSearch}
					bind:value={query}
					oninput={onSearchInput}
					onkeydown={onSearchKeydown}
					aria-label="Search"
					type="search"
					placeholder="Search…"
					class="min-w-0 flex-1 border-0 bg-transparent text-ink outline-none placeholder:text-dim"
				/>
			</div>
			<button
				type="button"
				onclick={openSheet}
				class="relative grid h-12 w-12 press place-items-center btn-quiet text-ink"
				aria-label="Filters{chips.length ? ` (${chips.length} on)` : ''}"
			>
				<span class="material-symbols-rounded !text-[22px]" aria-hidden="true">tune</span>
				{#if chips.length}
					<span
						class="absolute -top-1 -right-1 grid h-5 min-w-5 place-items-center rounded-[2px] px-1 font-mono text-[11px] font-bold"
						style="background:{accent};color:{accentInk};box-shadow:0 0 0 2px var(--color-surface)"
						aria-hidden="true"
					>
						{chips.length}
					</span>
				{/if}
			</button>
		</div>

		{@render presetRow('-mx-4 scrollbar-none overflow-x-auto px-4')}
		{@render chipRow('-mx-4 scrollbar-none overflow-x-auto px-4')}

		{#if resultCount}
			<div class="flex items-center justify-between text-[13px] text-muted">
				<span><b class="font-mono text-ink">{resultCount}</b> results</span>
				<span>{SORTS.find((s) => s.key === filters.sort)?.label}</span>
			</div>
		{/if}

		{#if results.pending}
			{@render loadingGrid('grid-cols-2 gap-x-3 gap-y-5 md:grid-cols-4', 8)}
		{:else if results.failed}
			<SectionError
				title="Couldn't load results"
				onRetry={() => results.retryNow()}
				detail={results.error}
				retryIn={results.retry.active ? results.retry.label : undefined}
				rateLimited={results.rateLimited}
			/>
			{@render people()}
		{:else if !results.stale && results.total === 0}
			{@render emptyState()}
			{@render people()}
		{:else}
			<div class="flex flex-col gap-5 transition-opacity {results.stale ? 'opacity-50' : ''}">
				{@render mobileTitles(titles.slice(0, peopleAfter.mobile), 0)}
				{@render people()}
				{#if titles.length > peopleAfter.mobile}
					{@render mobileTitles(titles.slice(peopleAfter.mobile), peopleAfter.mobile)}
				{/if}
			</div>
			{@render moreResults()}
		{/if}
	</div>

	{#if sheetOpen}
		<div class="fixed inset-0 z-[60] lg:hidden">
			<button
				type="button"
				class="absolute inset-0 bg-[rgba(19,17,15,.6)]"
				transition:fade={{ duration: 150 }}
				onclick={() => (sheetOpen = false)}
				aria-label="Close filters"
			></button>
			<div
				class="absolute inset-x-0 bottom-0 flex max-h-[85vh] flex-col rounded-t-[6px] border-t border-line bg-raised-hover"
				style="box-shadow:0 -24px 64px rgba(0,0,0,.6)"
				transition:fly={{ y: 400, duration: 220 }}
				role="dialog"
				aria-modal="true"
				aria-labelledby="sheet-title"
			>
				<div class="flex justify-center pt-2.5 pb-1">
					<div class="h-[5px] w-10 rounded-full bg-white/20"></div>
				</div>
				<div class="flex items-center px-4 pt-2 pb-3">
					<h2
						id="sheet-title"
						class="m-0 flex-1 font-display text-[24px] leading-tight font-medium tracking-[-0.02em] lg:text-[26px]"
					>
						Filters
					</h2>
					<button
						type="button"
						onclick={() => (draft = { ...withoutFilters(draft), sort: 'popularity' })}
						class="h-11 px-2 text-sm font-semibold text-muted"
					>
						Reset
					</button>
				</div>
				<div class="flex-1 overflow-y-auto px-4">
					<BrowseFilters
						state={draft}
						{isAnime}
						{signedIn}
						{genres}
						{tags}
						onChange={(patch) => (draft = { ...draft, ...patch })}
						showSort
						idPrefix="sheet"
					/>
				</div>
				<div class="border-t border-line px-4 pt-3 pb-8">
					<button
						type="button"
						onclick={applySheet}
						class="h-[52px] w-full press rounded-[2px] text-base font-semibold"
						style="background:{accent};color:{accentInk}"
					>
						{draftCount === null ? 'Show results' : `Show ${draftCount} results`}
					</button>
				</div>
			</div>
		</div>
	{/if}
</PageShell>
