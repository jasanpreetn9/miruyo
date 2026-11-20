<script lang="ts">
	import CoverImage from '#lib/components/shared/CoverImage.svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { coverBackground } from '#lib/anilist/adapt.ts';
	import {
		fetchCustomLists,
		fetchListCollection,
		requestStamp,
		type CustomList
	} from '#lib/anilist/client.ts';
	import { formatScore, nudgeScore } from '#lib/anilist/score.ts';
	import type { CollectionEntry, MediaListStatus } from '#lib/anilist/types.ts';
	import { LIST_STATUSES, STATUS_COLOR } from '#lib/catalog/status.ts';
	import SectionError from '#lib/components/home/SectionError.svelte';
	import PosterCard from '#lib/components/shared/PosterCard.svelte';
	import ProgressBar from '#lib/components/shared/ProgressBar.svelte';
	import Skeleton from '#lib/components/shared/Skeleton.svelte';
	import PageShell from '#lib/components/shared/PageShell.svelte';
	import {
		buildListView,
		defaultSortFor,
		sortsFor,
		type ListRow,
		type ListSort
	} from '#lib/page-data/list.ts';
	import { clock } from '#lib/state/clock.svelte.ts';
	import { editor } from '#lib/state/editor.svelte.ts';
	import { entryFromTitle, list } from '#lib/state/list.svelte.ts';
	import { readPref, writePref } from '#lib/state/prefs.ts';
	import { plusOne } from '#lib/state/list-actions.ts';
	import { Resource } from '#lib/state/resource.svelte.ts';
	import { mediaTypeFor, session } from '#lib/state/session.svelte.ts';
	import { LIST_VIEW_STORAGE_KEY } from '#lib/storage-keys.ts';

	// My List: a table for a list you manage, a grid for one you
	// admire. Edit in place: +1 on every row, click a score to nudge it. Your
	// custom lists from AniList follow the statuses as tabs of their own
	// (?list=Rewatch%20someday), each holding its titles whatever their status.

	const isAnime = $derived(session.mode === 'anime');
	const collection = new Resource<{
		entries: CollectionEntry[];
		custom: { lists: CustomList[]; hidden: number[] };
	}>();

	function loadCollection() {
		const userId = session.user?.id;
		const mode = session.mode;
		// a custom list changed in the editor, or a newer copy of the list
		// loaded behind the page: load again (under the same key, so the rows
		// stay on screen while it does)
		void list.customListsVersion;
		void list.collectionsVersion;
		if (session.authState !== 'in' || !userId) return;
		void collection.load(
			`${userId}:${mode}`,
			() => {
				const type = mediaTypeFor(mode);
				// one request: both read the same cached collection
				return Promise.all([
					fetchListCollection(userId, type),
					fetchCustomLists(userId, type)
				]).then(([entries, custom]) => ({ entries, custom }));
			},
			// every entry, in full, for every card and the editor
			// titles edited since the copy was requested keep their local values
			({ entries }) =>
				list.seed(
					entries.map(({ media: _media, ...entry }) => entry),
					requestStamp(entries)
				)
		);
	}

	$effect(loadCollection);

	$effect(() => () => collection.reset());

	// ── Tab (in the URL, so it survives reloads and the back button) ──
	const tab = $derived.by((): MediaListStatus => {
		const key = page.url.searchParams.get('tab')?.toUpperCase();
		return LIST_STATUSES.find((s) => s === key) ?? 'CURRENT';
	});

	/** The custom list open (?list=), or null on a status tab. */
	const custom = $derived.by((): CustomList | null => {
		const name = page.url.searchParams.get('list');
		return (name && collection.data?.custom.lists.find((l) => l.name === name)) || null;
	});
	const customLists = $derived(
		(collection.data?.custom.lists ?? []).map((l) => ({
			...l,
			count: l.mediaIds.filter((id) => !list.isRemoved(id)).length
		}))
	);

	function showTab(status: MediaListStatus) {
		const qs = status === 'CURRENT' ? '' : `?tab=${status.toLowerCase()}`;
		void goto(qs || page.url.pathname, { reset: false });
		shown = PAGE_SIZE;
		editingScore = null;
	}

	// on phones the tabs scroll sideways: keep the open one in view (a custom
	// list, or Dropped, can start off-screen)
	let tabRow = $state<HTMLElement>();
	$effect(() => {
		void tab;
		void custom;
		void customLists.length;
		tabRow
			?.querySelector<HTMLElement>('[aria-selected="true"]')
			?.scrollIntoView({ block: 'nearest', inline: 'nearest' });
	});

	function showList(name: string) {
		void goto(`?list=${encodeURIComponent(name)}`, { reset: false });
		shown = PAGE_SIZE;
		editingScore = null;
	}

	// ── Toolbar ──
	let filter = $state('');
	// in the URL too (?sort=), so a link can open a tab in an order; a tab's
	// own default is left out of it
	// a custom list mixes statuses: the sorts that suit any of them
	const sortTab = $derived<MediaListStatus>(custom ? 'COMPLETED' : tab);
	const sorts = $derived(sortsFor(sortTab, isAnime));
	const sort = $derived.by((): ListSort => {
		const key = page.url.searchParams.get('sort');
		return sorts.find((s) => s.key === key)?.key ?? defaultSortFor(sortTab);
	});

	function setSort(next: ListSort) {
		const params = new URLSearchParams(page.url.search);
		if (next === defaultSortFor(sortTab)) params.delete('sort');
		else params.set('sort', next);
		const qs = params.toString();
		void goto(qs ? `?${qs}` : page.url.pathname, { replace: true, reset: false });
	}
	let format = $state('');

	/** Table or grid, one choice for every tab. */
	type View = 'table' | 'grid';
	// an older per-status value (JSON) reads as the default
	let view = $state<View>(readPref(LIST_VIEW_STORAGE_KEY) === 'grid' ? 'grid' : 'table');

	function setView(v: View) {
		view = v;
		writePref(LIST_VIEW_STORAGE_KEY, v);
	}

	const listView = $derived(
		collection.data
			? buildListView(collection.data.entries, {
					tab,
					only: custom ? new Set(custom.mediaIds) : undefined,
					hidden: new Set(collection.data.custom.hidden),
					filter,
					sort,
					format,
					isAnime,
					titles: 'userPreferred',
					scoreFormat: session.scoreFormat,
					live: (id) => list.get(id),
					removed: (id) => list.isRemoved(id),
					now: clock.seconds
				})
			: null
	);

	// a format that isn't on this tab would hide everything
	$effect(() => {
		if (format && listView && !listView.formats.includes(format)) format = '';
	});

	// ── Long lists render in steps of 100 ──
	const PAGE_SIZE = 100;
	let shown = $state(PAGE_SIZE);
	const visibleRows = $derived(listView ? listView.rows.slice(0, shown) : []);

	function showMoreWhenVisible(node: HTMLElement) {
		const observer = new IntersectionObserver(
			([e]) => {
				if (e.isIntersecting) shown += PAGE_SIZE;
			},
			{ rootMargin: '800px 0px' }
		);
		observer.observe(node);
		return () => observer.disconnect();
	}

	// ── Score: click to nudge with a stepper, ✓ to save ──
	let editingScore = $state<number | null>(null);
	let scoreDraft = $state(0);

	function startScore(row: ListRow) {
		editingScore = row.title.id;
		scoreDraft = row.score;
	}

	function saveScore(row: ListRow) {
		editingScore = null;
		if (scoreDraft !== row.score) {
			void list.update(
				row.title.id,
				{ score: scoreDraft },
				list.get(row.title.id) ?? entryFromTitle(row.title)
			);
		}
	}

	function onScoreKeydown(e: KeyboardEvent, row: ListRow) {
		if (e.key === 'Escape') editingScore = null;
		if (e.key === 'Enter') saveScore(row);
	}

	const heading = $derived(`${session.user?.name ?? 'Your'}’s ${isAnime ? 'anime' : 'manga'}`);
	// your list as others see it, on your miruyo page (its Share button has the link)
	const shareUrl = $derived(
		session.user
			? `/user/${encodeURIComponent(session.user.name)}/${isAnime ? 'animelist' : 'mangalist'}`
			: null
	);
	const currentTab = $derived(listView?.tabs.find((t) => t.status === tab));
	const tabName = $derived(custom?.name ?? currentTab?.label);
	const emptyTitle = $derived(
		custom
			? `Nothing on ${custom.name} yet`
			: `Nothing ${currentTab?.label.toLowerCase() ?? ''} yet`
	);
	const emptyBody = $derived(
		tab === 'DROPPED'
			? 'Either great taste or great patience. Titles you drop will show up here.'
			: 'When you move a title here it will appear in this tab.'
	);
</script>

<svelte:head>
	<title>My List · miruyo</title>
</svelte:head>

{#snippet plusButton(row: ListRow, size: 'sm' | 'md')}
	{@const done =
		row.status === 'COMPLETED' || (!!row.title.total && row.progress >= row.title.total)}
	<button
		type="button"
		onclick={() => plusOne(row.title)}
		disabled={done}
		aria-label="Add one {isAnime ? 'episode' : 'chapter'} to {row.title.title}"
		class="grid flex-none press place-items-center rounded-[2px] {size === 'md'
			? 'h-11 w-11'
			: 'h-9 w-9'} {done ? 'bg-raised-hover text-[var(--color-dim)]' : 'btn-quiet'}"
	>
		<span class="material-symbols-rounded !text-[20px]" aria-hidden="true">add</span>
	</button>
{/snippet}

{#snippet progressLabel(row: ListRow)}
	{isAnime ? '' : 'CH '}{row.progress} / {row.title.total ?? '?'}
{/snippet}

<PageShell nav="list" tab="list">
	{#if session.authState === 'out'}
		<div class="flex flex-col items-center gap-3 px-6 py-24 text-center">
			<span class="material-symbols-rounded !text-[40px] text-dim" aria-hidden="true"
				>bookmarks</span
			>
			<h1
				class="m-0 font-display text-[34px] leading-[0.95] font-light tracking-[-0.04em] lg:text-[44px]"
			>
				Your list lives on AniList
			</h1>
			<p class="m-0 max-w-sm text-sm text-muted">
				Log in to see and update everything you're watching and reading.
			</p>
			<a
				href="/login"
				class="mt-2 flex h-12 items-center rounded-[2px] bg-anime px-5 font-semibold text-anime-ink hover:text-anime-ink"
				>Log in with AniList</a
			>
		</div>
	{:else}
		<!-- header -->
		<div class="hidden items-end gap-5 px-20 pt-10 lg:flex">
			<div
				class="h-[72px] w-[72px] flex-none rounded-full bg-[linear-gradient(135deg,#5AB0FF,#A08CFF)]"
				style={session.user?.avatar.large
					? `background:${coverBackground(session.user.avatar.large)}`
					: ''}
				aria-hidden="true"
			></div>
			<div class="flex flex-1 flex-col gap-1.5">
				<h1 class="m-0 font-display text-[56px] leading-[0.92] font-light tracking-[-0.045em]">
					{heading}
				</h1>
				<div class="text-sm text-muted">
					{#if listView}{listView.summary}{:else}&nbsp;{/if}
				</div>
			</div>
			{#if shareUrl}
				<a
					href={shareUrl}
					class="flex h-10 items-center gap-1.5 btn-quiet px-3.5 text-sm font-semibold hover:text-ink"
				>
					<span class="material-symbols-rounded !text-[18px]" aria-hidden="true">ios_share</span>
					Share list
				</a>
			{/if}
		</div>

		<!-- tabs: underlined on desktop, pills on mobile -->
		<div
			class="flex scrollbar-none gap-1.5 overflow-x-auto px-4 pt-3 lg:gap-1 lg:border-b lg:border-line lg:px-10 lg:pt-7 xl:px-20"
			role="tablist"
			aria-label="List status"
			bind:this={tabRow}
		>
			{#each listView?.tabs ?? LIST_STATUSES.map( (status) => ({ status, label: '', count: 0 }) ) as t (t.status)}
				{@const on = !custom && t.status === tab}
				<button
					type="button"
					role="tab"
					aria-selected={on}
					onclick={() => showTab(t.status)}
					class="flex h-10 flex-none items-center gap-2 rounded-[2px] border px-3.5 text-sm whitespace-nowrap lg:h-11 lg:rounded-none lg:border-0 lg:bg-transparent lg:px-3.5 {on
						? 'border-ink bg-ink font-semibold text-surface lg:text-ink lg:shadow-[inset_0_-2px_0_var(--tab-accent)]'
						: 'border-line bg-raised text-[#DDD3C3] lg:text-muted'}"
					style="--tab-accent:{isAnime ? 'var(--color-anime)' : 'var(--color-manga)'}"
				>
					<span
						class="hidden h-[7px] w-[7px] rounded-full lg:block"
						style="background:{STATUS_COLOR[t.status]}"
						aria-hidden="true"
					></span>
					{t.label || '…'}
					<span class="font-mono text-xs opacity-70">{listView ? t.count : ''}</span>
				</button>
			{/each}
			<!-- your own lists, after the statuses -->
			{#if customLists.length}
				<span class="mx-1 my-2 w-px flex-none bg-line lg:my-3" aria-hidden="true"></span>
				{#each customLists as l (l.name)}
					{@const on = custom?.name === l.name}
					<button
						type="button"
						role="tab"
						aria-selected={on}
						onclick={() => showList(l.name)}
						class="flex h-10 flex-none items-center gap-2 rounded-[2px] border px-3.5 text-sm whitespace-nowrap lg:h-11 lg:rounded-none lg:border-0 lg:bg-transparent lg:px-3.5 {on
							? 'border-ink bg-ink font-semibold text-surface lg:text-ink lg:shadow-[inset_0_-2px_0_var(--tab-accent)]'
							: 'border-line bg-raised text-[#DDD3C3] lg:text-muted'}"
						style="--tab-accent:{isAnime ? 'var(--color-anime)' : 'var(--color-manga)'}"
						data-testid="custom-list-tab"
					>
						<span class="material-symbols-rounded hidden !text-[16px] lg:block" aria-hidden="true"
							>bookmarks</span
						>
						{l.name}
						<span class="font-mono text-xs opacity-70">{l.count}</span>
					</button>
				{/each}
			{/if}
		</div>

		<!-- toolbar (tablets and desktop) -->
		<div class="hidden items-center gap-2.5 px-4 pt-3 md:flex lg:px-10 lg:py-5 xl:px-20">
			<label class="flex h-10 w-56 items-center gap-2 field-line px-0.5 text-sm lg:w-72">
				<span class="material-symbols-rounded !text-[20px] text-dim" aria-hidden="true"
					>filter_list</span
				>
				<span class="sr-only">Filter this list</span>
				<input
					bind:value={filter}
					oninput={() => (shown = PAGE_SIZE)}
					type="search"
					placeholder="Filter this list…"
					class="min-w-0 flex-1 border-0 bg-transparent p-0 text-sm text-ink outline-none placeholder:text-dim focus:ring-0"
				/>
			</label>
			<label class="flex h-10 items-center gap-1.5 text-sm">
				<span class="text-dim">Sort</span>
				<select
					value={sort}
					onchange={(e) => setSort(e.currentTarget.value as ListSort)}
					class="h-8 border-0 bg-transparent py-0 pr-8 pl-0 text-sm text-ink focus:ring-0"
				>
					{#each sorts as s (s.key)}
						<option value={s.key}>{s.label}</option>
					{/each}
				</select>
			</label>
			<label class="flex h-10 items-center gap-1.5 text-sm">
				<span class="text-dim">Format</span>
				<select
					bind:value={format}
					class="h-8 border-0 bg-transparent py-0 pr-8 pl-0 text-sm text-ink focus:ring-0"
				>
					<option value="">All</option>
					{#each listView?.formats ?? [] as f (f)}
						<option value={f}>{f}</option>
					{/each}
				</select>
			</label>
			<div class="flex-1"></div>
			<div class="inline-flex gap-3" role="radiogroup" aria-label="View">
				{#each [{ key: 'table', icon: 'view_list', label: 'Table' }, { key: 'grid', icon: 'grid_view', label: 'Grid' }] as v (v.key)}
					{@const on = view === v.key}
					<button
						type="button"
						role="radio"
						aria-checked={on}
						onclick={() => setView(v.key as View)}
						class="flex h-[34px] items-center gap-1.5 text-[13px] {on
							? 'font-semibold text-ink shadow-[inset_0_-1.5px_0_var(--color-anime)]'
							: 'font-medium text-dim hover:text-ink'}"
					>
						<span class="material-symbols-rounded !text-[18px]" aria-hidden="true">{v.icon}</span>
						{v.label}
					</button>
				{/each}
			</div>
		</div>

		<div class="px-4 pt-3 pb-20 lg:px-10 lg:pt-0 xl:px-20" role="tabpanel">
			{#if session.authState === 'loading' || collection.pending}
				<div class="flex flex-col gap-2" aria-busy="true" aria-label="Loading your list">
					{#each { length: 6 } as _, i (i)}
						<div class="flex items-center gap-3 border-b border-line py-2.5">
							<Skeleton class="aspect-2/3 w-12 rounded-[2px]" />
							<div class="flex flex-1 flex-col gap-2">
								<Skeleton class="h-3 w-3/4" />
								<Skeleton class="h-2.5 w-2/5" />
								<Skeleton class="h-1 w-full" />
							</div>
							<Skeleton class="h-11 w-11 rounded-[2px]" />
						</div>
					{/each}
				</div>
			{:else if collection.failed || session.authState === 'error'}
				<SectionError
					title="Couldn't load your list"
					onRetry={() =>
						session.authState === 'error' ? session.loadCurrentUser() : loadCollection()}
					detail={collection.error || session.loadError}
					retryIn={collection.retry.active ? collection.retry.label : undefined}
					rateLimited={collection.rateLimited}
				/>
			{:else if listView && listView.rows.length === 0}
				<div
					class="flex flex-col items-center gap-3 rounded-[2px] border border-dashed border-line px-6 py-14 text-center"
					data-testid="list-empty"
				>
					<div class="grid h-16 w-16 place-items-center rounded-[2px] bg-raised text-dim">
						<span class="material-symbols-rounded !text-[32px]" aria-hidden="true">inventory_2</span
						>
					</div>
					{#if filter || format}
						<div class="font-display text-[22px] font-[650]">No matches on this tab</div>
						<button
							type="button"
							onclick={() => ((filter = ''), (format = ''))}
							class="text-sm font-semibold text-muted hover:text-ink">Clear filter</button
						>
					{:else}
						<div class="font-display text-[22px] font-[650]">{emptyTitle}</div>
						<div class="max-w-[380px] text-sm text-muted">{emptyBody}</div>
						<a
							href="/seasonal"
							class="mt-1 flex h-11 items-center btn-quiet px-4 text-sm font-semibold hover:text-ink"
							>Browse seasonal</a
						>
					{/if}
				</div>
			{:else if listView}
				{#if view === 'grid'}
					<div
						class="grid grid-cols-2 gap-x-3 gap-y-6 md:grid-cols-4 lg:grid-cols-7 lg:gap-x-5 lg:gap-y-7"
					>
						{#each visibleRows as row (row.title.id)}
							<PosterCard title={row.title} size="sm" />
						{/each}
					</div>
				{:else}
					<!-- desktop table -->
					<div
						class="hidden flex-col overflow-hidden rounded-[2px] border border-white/6 lg:flex"
						role="table"
						aria-label={tabName}
					>
						<div
							class="grid grid-cols-[minmax(0,2.2fr)_minmax(0,1.4fr)_150px_90px_110px] gap-5 border-t border-b border-t-ink border-b-line px-1 py-2.5 text-[11px] font-semibold tracking-[0.1em] text-dim uppercase"
							role="row"
						>
							<div role="columnheader">Title</div>
							<div role="columnheader">Progress</div>
							<div role="columnheader">Score</div>
							<div role="columnheader">Type</div>
							<div role="columnheader">Updated</div>
						</div>
						{#each visibleRows as row (row.title.id)}
							<div
								class="group grid grid-cols-[minmax(0,2.2fr)_minmax(0,1.4fr)_150px_90px_110px] items-center gap-5 border-b border-line px-1 py-2.5 [contain-intrinsic-size:auto_76px] [content-visibility:auto] hover:bg-[#0E1119]"
								role="row"
								data-testid="list-row"
							>
								<div class="flex min-w-0 items-center gap-3.5" role="cell">
									<a
										href="/title/{row.title.id}"
										class="relative aspect-2/3 w-11 flex-none overflow-hidden rounded-[2px]"
										style="background:{row.title.placeholder}"
										aria-hidden="true"
										tabindex="-1"><CoverImage title={row.title} thumb /></a
									>
									<div class="flex min-w-0 flex-col gap-1">
										<a
											href="/title/{row.title.id}"
											class="truncate text-[15px] font-semibold text-ink hover:text-ink hover:underline"
											>{row.title.title}</a
										>
										<div class="truncate font-mono text-xs" style="color:{row.noteColor}">
											{row.note}
										</div>
									</div>
								</div>
								<div class="flex items-center gap-3" role="cell">
									<ProgressBar
										value={row.progress}
										total={row.title.total}
										color={STATUS_COLOR[row.status]}
										full={row.status === 'COMPLETED'}
										class="h-1.5 flex-1"
									/>
									<div class="w-20 text-right font-mono text-[13px] text-[#DDD3C3]">
										{@render progressLabel(row)}
									</div>
									{@render plusButton(row, 'sm')}
								</div>
								<div class="flex items-center gap-1" role="cell">
									{#if editingScore === row.title.id}
										<div
											class="flex items-center gap-0.5 rounded-[2px] border border-white/16 bg-raised-hover p-0.5"
										>
											<button
												type="button"
												onclick={() =>
													(scoreDraft = nudgeScore(scoreDraft, -1, session.scoreFormat))}
												onkeydown={(e) => onScoreKeydown(e, row)}
												aria-label="Lower score"
												class="grid h-8 w-8 place-items-center rounded-[2px] text-ink hover:bg-white/5"
											>
												<span class="material-symbols-rounded !text-[18px]" aria-hidden="true"
													>remove</span
												>
											</button>
											<div
												class="w-9 text-center font-mono text-sm font-semibold"
												aria-live="polite"
											>
												{formatScore(scoreDraft, session.scoreFormat)}
											</div>
											<button
												type="button"
												onclick={() =>
													(scoreDraft = nudgeScore(scoreDraft, 1, session.scoreFormat))}
												onkeydown={(e) => onScoreKeydown(e, row)}
												aria-label="Raise score"
												class="grid h-8 w-8 place-items-center rounded-[2px] text-ink hover:bg-white/5"
											>
												<span class="material-symbols-rounded !text-[18px]" aria-hidden="true"
													>add</span
												>
											</button>
										</div>
										<button
											type="button"
											onclick={() => saveScore(row)}
											aria-label="Save score"
											class="grid h-8 w-8 place-items-center rounded-[2px] text-green hover:bg-white/5"
										>
											<span class="material-symbols-rounded !text-[20px]" aria-hidden="true"
												>check</span
											>
										</button>
									{:else}
										<button
											type="button"
											onclick={() => startScore(row)}
											aria-label="Score {formatScore(row.score, session.scoreFormat)} — change"
											class="flex h-8 items-center gap-1 rounded-[2px] border border-transparent px-2 font-mono text-sm font-semibold hover:border-white/14 hover:bg-raised-hover"
										>
											<span
												class="material-symbols-rounded !text-[16px] text-gold"
												style="font-variation-settings:'FILL' {row.score ? 1 : 0}"
												aria-hidden="true">star</span
											>
											{formatScore(row.score, session.scoreFormat)}
										</button>
									{/if}
								</div>
								<div class="text-[13px] text-muted" role="cell">{row.title.format}</div>
								<div
									class="flex items-center justify-between gap-1 text-[13px] text-dim"
									role="cell"
								>
									{row.updated}
									<button
										type="button"
										onclick={() => editor.open(row.title)}
										aria-label="Edit {row.title.title}"
										class="grid h-8 w-8 place-items-center rounded-[2px] text-muted opacity-0 group-focus-within:opacity-100 group-hover:opacity-100 hover:bg-white/5 hover:text-ink focus-visible:opacity-100"
									>
										<span class="material-symbols-rounded !text-[18px]" aria-hidden="true"
											>edit</span
										>
									</button>
								</div>
							</div>
						{/each}
					</div>

					<!-- mobile rows (two columns on tablets) -->
					<div class="flex flex-col gap-2 md:grid md:grid-cols-2 lg:hidden">
						{#each visibleRows as row (row.title.id)}
							<div
								class="flex items-center gap-3 border-b border-line py-2.5 [contain-intrinsic-size:auto_92px] [content-visibility:auto]"
								data-testid="list-row-mobile"
							>
								<button
									type="button"
									onclick={() => editor.open(row.title)}
									aria-label="Edit {row.title.title}"
									class="relative aspect-2/3 w-12 flex-none overflow-hidden rounded-[2px]"
									style="background:{row.title.placeholder}"
									><CoverImage title={row.title} thumb /></button
								>
								<div class="flex min-w-0 flex-1 flex-col gap-1.5">
									<a
										href="/title/{row.title.id}"
										class="truncate text-sm font-semibold text-ink hover:text-ink"
										>{row.title.title}</a
									>
									<div class="flex justify-between gap-2 font-mono text-[11px]">
										<span class="truncate" style="color:{row.noteColor}">{row.note}</span>
										<span class="flex-none text-muted">{@render progressLabel(row)}</span>
									</div>
									<ProgressBar
										value={row.progress}
										total={row.title.total}
										color={STATUS_COLOR[row.status]}
										full={row.status === 'COMPLETED'}
										class="h-1"
									/>
								</div>
								{@render plusButton(row, 'md')}
							</div>
						{/each}
					</div>
				{/if}

				{#if listView.rows.length > shown}
					<div class="flex justify-center py-6" {@attach showMoreWhenVisible}>
						<button
							type="button"
							onclick={() => (shown += PAGE_SIZE)}
							class="h-11 btn-quiet px-5 text-sm font-semibold"
						>
							Show more ({listView.rows.length - shown} left)
						</button>
					</div>
				{/if}
			{/if}
		</div>
	{/if}
</PageShell>
