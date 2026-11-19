<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { formatScore } from '#lib/anilist/score.ts';
	import type { MediaListStatus, MediaType } from '#lib/anilist/types.ts';
	import { STATUS_COLOR } from '#lib/catalog/status.ts';
	import SectionError from '#lib/components/home/SectionError.svelte';
	import CoverImage from '#lib/components/shared/CoverImage.svelte';
	import ProgressBar from '#lib/components/shared/ProgressBar.svelte';
	import Skeleton from '#lib/components/shared/Skeleton.svelte';
	import { countryName, type ListRow, type ListSort } from '#lib/page-data/list.ts';
	import {
		buildUserList,
		defaultUserSort,
		possessive,
		statusParam,
		userSortsFor
	} from '#lib/page-data/user.ts';
	import { session } from '#lib/state/session.svelte.ts';
	import { getUserPage } from '#lib/state/user-page.svelte.ts';

	// Someone else's anime or manga list, read-only (a user page's list tab;
	// yours is My List), in the page's right column: a toolbar as on My List (the
	// statuses, then filter, format, sort and view), then the list. It opens on
	// every status at once, each in its own panel; pick one (?status=completed)
	// to see just that. Sort (?sort=), Format (?format=TV), AniList's Genre,
	// Country and Year (?genre=Action&country=KR&year=2024) and rows or covers
	// (?view=covers) live in the URL too. Scores come in
	// UserPage.scoreFormat.

	interface Props {
		type: MediaType;
	}

	let { type }: Props = $props();

	const user = getUserPage();
	const isAnime = $derived(type === 'ANIME');
	const account = $derived(user.account);
	const resource = $derived(user.lists[type]);
	const signedIn = $derived(session.authState === 'in');

	$effect(() => {
		void account?.id;
		user.loadList(type);
	});

	const whose = $derived(user.own ? 'your' : account ? possessive(account.name) : 'their');
	const accent = $derived(isAnime ? 'var(--color-anime)' : 'var(--color-manga)');
	const accentInk = $derived(isAnime ? 'var(--color-anime-ink)' : 'var(--color-manga-ink)');

	/** The status picked, or null for all of them. */
	const status = $derived.by((): MediaListStatus | null => {
		const value = page.url.searchParams.get('status');
		return value ? statusParam(value) : null;
	});
	// every status's sorts work across all of them, less those for what's in progress
	const sorts = $derived(userSortsFor(status ?? 'COMPLETED', isAnime));
	const defaultSort = $derived(status ? defaultUserSort(status) : 'updated');
	const sort = $derived.by((): ListSort => {
		const key = page.url.searchParams.get('sort');
		return sorts.find((s) => s.key === key)?.key ?? defaultSort;
	});
	const format = $derived(page.url.searchParams.get('format') ?? '');
	const genre = $derived(page.url.searchParams.get('genre') ?? '');
	const country = $derived(page.url.searchParams.get('country') ?? '');
	const year = $derived.by(() => {
		const value = Number(page.url.searchParams.get('year'));
		return Number.isInteger(value) && value > 0 ? value : null;
	});
	const covers = $derived(page.url.searchParams.get('view') === 'covers');

	let filter = $state('');
	/** Any of the toolbar's filters is narrowing the list. */
	const narrowed = $derived(!!(filter || format || genre || country || year));
	// one status renders 100 rows at a time; a new status or filter starts over
	const PAGE = 100;
	let more = $state({ key: '', count: PAGE });
	const listKey = $derived(`${type}:${status}:${filter}:${format}:${genre}:${country}:${year}`);
	const shown = $derived(more.key === listKey ? more.count : PAGE);

	const now = Math.floor(Date.now() / 1000);
	function build(s: MediaListStatus, sortKey: ListSort) {
		return buildUserList(resource.data ?? [], {
			status: s,
			sort: sortKey,
			filter,
			format,
			genre,
			country,
			year,
			isAnime,
			titles: signedIn ? 'userPreferred' : 'english',
			adult: signedIn && session.showAdultContent,
			scoreFormat: user.scoreFormat,
			now
		});
	}

	/** The first status's view: every status's count, and the summary. */
	const list = $derived(resource.data ? build(status ?? 'CURRENT', sort) : null);
	const total = $derived(list?.tabs.reduce((n, t) => n + t.count, 0) ?? 0);
	/** A panel per status (with anything on it), or the one picked. */
	const panels = $derived.by(() => {
		if (!list) return [];
		const tabs = status ? list.tabs.filter((t) => t.status === status) : list.tabs;
		return tabs
			.filter((t) => status || t.count > 0)
			.map((t) => ({
				...t,
				view: t.status === (status ?? 'CURRENT') ? list : build(t.status, sort)
			}));
	});
	/** What a filter can pick: what's on the panels, plus what's picked (so it still shows). */
	function options<T extends string | number>(
		values: (p: (typeof panels)[number]) => T[],
		picked: T | null | '',
		order: (a: T, b: T) => number
	): T[] {
		const all = new Set(panels.flatMap(values));
		if (picked) all.add(picked);
		return [...all].sort(order);
	}
	const byText = (a: string, b: string) => a.localeCompare(b);
	const formats = $derived(options((p) => p.view.formats, format, byText));
	const genres = $derived(options((p) => p.view.genres, genre, byText));
	const countries = $derived(options((p) => p.view.countries, country, byText));
	const years = $derived(
		options(
			(p) => p.view.years,
			year,
			(a, b) => b - a
		)
	);
	const shownPanels = $derived(
		status || !narrowed ? panels : panels.filter((p) => p.view.rows.length)
	);

	// Your own list lives in My List: your profile has no list tabs, and a link
	// to yours (one you shared) opens My List on the same type and status.
	$effect(() => {
		if (!user.own) return;
		const tab = status && status !== 'CURRENT' ? `?tab=${status.toLowerCase()}` : '';
		session.setMode(isAnime ? 'anime' : 'manga');
		void goto(`/list${tab}`, { replace: true });
	});

	function href(s: MediaListStatus | null): string {
		const url = new URL(page.url.href);
		url.searchParams.delete('sort');
		if (s) url.searchParams.set('status', s.toLowerCase());
		else url.searchParams.delete('status');
		return url.pathname + url.search;
	}

	function setParam(key: string, value: string, fallback = '') {
		const url = new URL(page.url.href);
		if (!value || value === fallback) url.searchParams.delete(key);
		else url.searchParams.set(key, value);
		void goto(url, { replace: true, reset: false });
	}

	const lists = $derived(
		list
			? [
					{ status: null, label: 'All', count: total },
					...list.tabs.filter((t) => t.count > 0 || t.status === status)
				]
			: []
	);
	const kind = $derived(isAnime ? 'anime' : 'manga');
</script>

{#snippet dropdown(
	label: string,
	value: string,
	options: { key: string; label: string }[],
	onchange: (v: string) => void
)}
	<label
		class="relative flex h-11 items-center rounded-[2px] border border-line bg-canvas pr-2.5 pl-3.5 text-sm focus-within:outline-2 focus-within:outline-offset-2 focus-within:outline-ink"
	>
		<span class="sr-only">{label}</span>
		<select
			{value}
			onchange={(e) => onchange(e.currentTarget.value)}
			class="h-9 w-full appearance-none border-0 bg-transparent bg-none py-0 pr-7 pl-0 text-sm text-ink outline-none focus:ring-0"
		>
			{#each options as o (o.key)}
				<option value={o.key}>{o.label}</option>
			{/each}
		</select>
		<span
			class="material-symbols-rounded pointer-events-none absolute right-2.5 !text-[20px] text-dim"
			aria-hidden="true">expand_more</span
		>
	</label>
{/snippet}

{#snippet sortSelect()}
	{@render dropdown(
		'Sort',
		sort,
		sorts.map((s) => ({ key: s.key, label: s.label })),
		(v) => setParam('sort', v, defaultSort)
	)}
{/snippet}

{#snippet filterBox(classes: string, placeholder = `Filter ${whose} list`)}
	<label class="relative flex items-center {classes}">
		<span
			class="material-symbols-rounded pointer-events-none absolute left-3 !text-[18px] text-dim"
			aria-hidden="true">search</span
		>
		<input
			type="search"
			bind:value={filter}
			{placeholder}
			aria-label="Filter the list"
			class="h-11 w-full min-w-0 field-line pr-1 pl-7 text-sm text-ink placeholder:text-dim focus:border-b-ink focus:ring-0"
		/>
	</label>
{/snippet}

<!-- rows or covers, in the Stats' Anime / Manga switch style -->
{#snippet viewSwitch(classes: string)}
	<div class="flex flex-none gap-1 {classes}" role="radiogroup" aria-label="View">
		{#each [{ key: '', icon: 'view_agenda', label: 'Rows' }, { key: 'covers', icon: 'grid_view', label: 'Covers' }] as v (v.key)}
			{@const on = covers === !!v.key}
			<button
				type="button"
				role="radio"
				aria-checked={on}
				aria-label={v.label}
				onclick={() => setParam('view', v.key)}
				class="grid h-9.5 w-10 place-items-center"
				style="color:{on ? 'var(--color-ink)' : 'var(--color-muted)'};box-shadow:{on
					? `inset 0 -2px 0 ${accent}`
					: 'none'}"
			>
				<span class="material-symbols-rounded !text-[20px]" aria-hidden="true">{v.icon}</span>
			</button>
		{/each}
	</div>
{/snippet}

{#snippet score(row: ListRow)}
	<span class="sr-only">{row.score ? 'Scored' : 'Not scored'}</span>
	{row.score ? formatScore(row.score, user.scoreFormat) : '—'}
{/snippet}

{#snippet rowList(rows: ListRow[])}
	<div
		class="flex items-center gap-3 border-b border-line pb-2.5 text-[11px] font-semibold tracking-wider text-dim uppercase"
		aria-hidden="true"
	>
		<span class="flex-1">Title</span>
		<span class="hidden w-20 text-right sm:block">{isAnime ? 'Episodes' : 'Chapters'}</span>
		<span class="w-12 text-right">Score</span>
		<span class="hidden w-20 text-right md:block">Updated</span>
	</div>
	<ul class="m-0 flex list-none flex-col p-0">
		{#each rows as row (row.title.id)}
			<li
				class="flex items-center gap-3 border-b border-line py-2.5 last:border-0 last:pb-0"
				data-testid="user-list-row"
			>
				<a
					href="/title/{row.title.id}"
					class="relative h-14 w-10 flex-none overflow-hidden rounded-[2px]"
					style="background:{row.title.placeholder}"
					tabindex="-1"
					aria-hidden="true"
				>
					<CoverImage title={row.title} thumb />
				</a>
				<div class="min-w-0 flex-1">
					<a
						href="/title/{row.title.id}"
						class="line-clamp-1 text-sm font-semibold text-ink hover:text-ink">{row.title.title}</a
					>
					<div class="truncate text-xs" style="color:{row.noteColor}">{row.note}</div>
				</div>
				<div class="hidden w-20 text-right font-mono text-xs text-muted sm:block">
					{row.progress}<span class="text-dim"> / {row.title.total ?? '?'}</span>
				</div>
				<div
					class="w-12 text-right font-mono text-sm font-semibold {row.score
						? 'text-ink'
						: 'text-dim'}"
				>
					{@render score(row)}
				</div>
				<div class="hidden w-20 text-right text-xs text-dim md:block">{row.updated}</div>
			</li>
		{/each}
	</ul>
{/snippet}

{#snippet coverGrid(rows: ListRow[])}
	<ul
		class="m-0 grid list-none grid-cols-3 gap-x-3 gap-y-5 p-0 sm:grid-cols-4 md:grid-cols-5 xl:grid-cols-6 2xl:grid-cols-7"
	>
		{#each rows as row (row.title.id)}
			<li class="flex min-w-0 flex-col gap-2" data-testid="user-list-row">
				<a
					href="/title/{row.title.id}"
					class="group relative block aspect-[2/3] overflow-hidden rounded-[2px]"
					style="background:{row.title.placeholder}"
				>
					<CoverImage title={row.title} class="transition-transform group-hover:scale-[1.03]" />
					{#if row.score}
						<span
							class="absolute top-1.5 right-1.5 rounded-[2px] bg-black/70 px-1.5 py-0.5 font-mono text-xs font-semibold text-white backdrop-blur-sm"
						>
							{@render score(row)}
						</span>
					{/if}
					<div class="absolute inset-x-0 bottom-0">
						<ProgressBar
							value={row.progress}
							total={row.title.total}
							color={STATUS_COLOR[row.status]}
							full={row.status === 'COMPLETED'}
							class="h-1"
							track="rgba(0,0,0,.5)"
						/>
					</div>
				</a>
				<div class="min-w-0">
					<a
						href="/title/{row.title.id}"
						class="line-clamp-2 text-[13px] leading-snug font-semibold text-ink hover:text-ink"
						>{row.title.title}</a
					>
					<div class="mt-0.5 truncate font-mono text-[11px] text-dim">
						{row.progress} / {row.title.total ?? '?'}
					</div>
				</div>
			</li>
		{/each}
	</ul>
{/snippet}

<div class="flex flex-col gap-4" data-testid="user-list">
	<!-- the toolbar, as on My List: the statuses, then filter, format, sort and view -->
	<div class="flex flex-col gap-3">
		{#if list}
			<nav
				class="-mx-4 flex scrollbar-none gap-1.5 overflow-x-auto px-4 lg:mx-0 lg:flex-wrap lg:px-0"
				aria-label="{whose} list by status"
			>
				{#each lists as t (t.status ?? 'all')}
					{@const on = t.status === status}
					<a
						href={href(t.status)}
						data-sveltekit-noscroll
						aria-current={on ? 'page' : undefined}
						class="flex h-9 flex-none items-center gap-1.5 rounded-[2px] border px-3.5 text-[13px] font-semibold {on
							? 'border-transparent bg-ink text-surface hover:text-surface'
							: 'border-line bg-raised text-muted hover:text-ink'}"
					>
						{#if t.status}<span
								class="h-2 w-2 rounded-full"
								style="background:{STATUS_COLOR[t.status]}"
								aria-hidden="true"
							></span>{/if}
						{t.label}
						<span class="font-mono text-xs font-medium opacity-70">{t.count}</span>
					</a>
				{/each}
			</nav>
		{:else}
			<div class="flex gap-1.5" aria-hidden="true">
				{#each { length: 5 } as _, i (i)}
					<Skeleton class="h-9 w-24 rounded-full" />
				{/each}
			</div>
		{/if}
		<div class="flex flex-wrap items-center gap-2">
			{@render filterBox('min-w-0 basis-full sm:basis-auto sm:flex-1')}
			<div class="min-w-0 flex-1 sm:w-36 sm:flex-none">
				{@render dropdown(
					'Format',
					format,
					[{ key: '', label: 'Any format' }, ...formats.map((f) => ({ key: f, label: f }))],
					(v) => setParam('format', v)
				)}
			</div>
			<div class="min-w-0 flex-1 sm:w-40 sm:flex-none">{@render sortSelect()}</div>
			{@render viewSwitch('hidden sm:flex')}
		</div>
		<!-- AniList's list filters -->
		<div class="grid grid-cols-3 gap-2 sm:flex sm:flex-wrap">
			<div class="min-w-0 sm:w-40">
				{@render dropdown(
					'Genre',
					genre,
					[{ key: '', label: 'Genre' }, ...genres.map((g) => ({ key: g, label: g }))],
					(v) => setParam('genre', v)
				)}
			</div>
			<div class="min-w-0 sm:w-40">
				{@render dropdown(
					'Country',
					country,
					[
						{ key: '', label: 'Country' },
						...countries.map((c) => ({ key: c, label: countryName(c) }))
					],
					(v) => setParam('country', v)
				)}
			</div>
			<div class="min-w-0 sm:w-32">
				{@render dropdown(
					'Year',
					year ? String(year) : '',
					[{ key: '', label: 'Year' }, ...years.map((y) => ({ key: String(y), label: String(y) }))],
					(v) => setParam('year', v)
				)}
			</div>
		</div>
		<!-- phones: the view switch here, so Format and Sort have the row; desktop has the summary in the facts card -->
		<div class="flex items-center gap-3 lg:hidden">
			<div class="min-w-0 flex-1 text-[13px] text-muted">{list?.summary ?? ''}</div>
			{@render viewSwitch('flex sm:hidden')}
		</div>
	</div>

	<div class="flex flex-col gap-3 lg:gap-5">
		{#if user.isPrivate(type) && account}
			<div
				class="flex flex-col items-center gap-3 rounded-[2px] border border-dashed border-line px-6 py-14 text-center"
				data-testid="private-list"
			>
				<span class="material-symbols-rounded !text-[36px] text-dim" aria-hidden="true"
					>visibility_off</span
				>
				<h3 class="m-0 font-display text-[22px] font-medium tracking-[-0.02em]">
					{account.name} keeps their list private
				</h3>
			</div>
		{:else if resource.failed}
			<SectionError
				title="Couldn't load {whose} {kind} list"
				onRetry={() => user.loadList(type)}
				detail={resource.error}
				retryIn={resource.retry.active ? resource.retry.label : undefined}
				rateLimited={resource.rateLimited}
			/>
		{:else if !list}
			<div aria-busy="true" aria-label="Loading {whose} list" class="flex flex-col gap-3 lg:gap-5">
				<Skeleton class="h-40 rounded-[2px]" />
				<Skeleton class="h-80 rounded-[2px]" />
			</div>
		{:else if !shownPanels.length}
			<p
				class="m-0 rounded-[2px] border border-dashed border-line px-6 py-14 text-center text-sm text-muted"
			>
				{narrowed ? 'Nothing matches.' : `Nothing on ${whose} ${kind} list yet.`}
			</p>
		{:else}
			{#each shownPanels as p (p.status)}
				{@const rows = status ? p.view.rows.slice(0, shown) : p.view.rows}
				<section
					class="flex min-w-0 flex-col gap-3 border-t border-ink pt-4 lg:gap-4 lg:pt-5"
					aria-labelledby="list-{p.status.toLowerCase()}"
				>
					<h3
						id="list-{p.status.toLowerCase()}"
						class="m-0 flex items-center gap-2.5 font-display text-[19px] font-medium lg:text-[22px]"
					>
						<span
							class="h-2.5 w-2.5 rounded-full"
							style="background:{STATUS_COLOR[p.status]}"
							aria-hidden="true"
						></span>
						{p.label}
						<span class="font-mono text-sm font-medium text-dim">{p.view.rows.length}</span>
					</h3>
					{#if !rows.length}
						<p class="m-0 py-4 text-sm text-muted">
							{narrowed ? 'Nothing matches.' : 'Nothing here.'}
						</p>
					{:else if covers}
						{@render coverGrid(rows)}
					{:else}
						<div>{@render rowList(rows)}</div>
					{/if}
					{#if status && p.view.rows.length > shown}
						<button
							type="button"
							onclick={() => (more = { key: listKey, count: shown + PAGE })}
							class="flex h-11 press items-center justify-center self-center rounded-[2px] border border-line bg-canvas px-5 text-sm font-semibold text-ink"
						>
							Show more
						</button>
					{/if}
				</section>
			{/each}
		{/if}
	</div>
</div>
