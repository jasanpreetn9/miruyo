<script lang="ts">
	import { untrack } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { coverBackground } from '#lib/anilist/adapt.ts';
	import { fetchDetail, toggleFavourite } from '#lib/anilist/client.ts';
	import { formatScore } from '#lib/anilist/score.ts';
	import type { DetailMedia } from '#lib/anilist/types.ts';
	import { airingChip } from '#lib/catalog/airing.ts';
	import { newEpisodesFor } from '#lib/catalog/progress.ts';
	import { isInProgress, STATUS_COLOR, statusLabel } from '#lib/catalog/status.ts';
	import SectionError from '#lib/components/home/SectionError.svelte';
	import Tick from '#lib/components/shared/Tick.svelte';
	import TitleStats from '#lib/components/title/TitleStats.svelte';
	import PosterCard from '#lib/components/shared/PosterCard.svelte';
	import ProgressBar from '#lib/components/shared/ProgressBar.svelte';
	import Skeleton from '#lib/components/shared/Skeleton.svelte';
	import PageShell from '#lib/components/shared/PageShell.svelte';
	import { createDetailContent, formatAiringLong, type LinkChip } from '#lib/page-data/detail.ts';
	import { reveal } from '#lib/motion.ts';
	import { clock } from '#lib/state/clock.svelte.ts';
	import { editor } from '#lib/state/editor.svelte.ts';
	import { list } from '#lib/state/list.svelte.ts';
	import { loadListState } from '#lib/state/list-state.ts';
	import { minusOne, plusOne } from '#lib/state/list-actions.ts';
	import { Resource } from '#lib/state/resource.svelte.ts';
	import { session } from '#lib/state/session.svelte.ts';
	import type { PageProps } from './$types';

	// The title page (design 03, made editorial in design/mockups/title-editorial).
	// The cover colour owns the page — the banner's duotone, the cover's offset
	// shadow, the score, the progress fill — while the chrome stays constant.

	let { data }: PageProps = $props();

	const id = $derived(Number(page.params.id));
	const signedIn = $derived(session.authState === 'in');
	const detail = new Resource<DetailMedia>();

	function load(mediaId: number, signed: boolean) {
		let since = 0;
		return detail.load(
			`${mediaId}:${signed}`,
			() => {
				since = list.stamp();
				return fetchDetail(mediaId, { signedIn: signed });
			},
			(media) => {
				// share the viewer's full entry (score, dates…) with every card
				const e = media.mediaListEntry;
				if (e) list.seed([{ ...e, mediaId: media.id }], since);
				favourite = media.isFavourite;
				// the recommendations arrive without list state; fetch it
				void loadListState(
					media.recommendations.nodes.flatMap((n) =>
						n.mediaRecommendation ? [n.mediaRecommendation.id] : []
					)
				);
			}
		);
	}

	$effect(() => {
		if (session.authState === 'loading' || !Number.isInteger(id) || id <= 0) return;
		void load(id, signedIn);
	});

	// a related title opens in the same page component: start it fresh
	$effect(() => {
		void id;
		tab = 'overview';
		synopsisOpen = false;
		spoilersShown = false;
		tagsOpen = false;
		watchOpen = false;
	});

	$effect(() => () => detail.reset());

	// the server's signed-out copy (first load only) shows until the browser's own arrives
	const media = $derived(detail.data ?? (data.media?.id === id ? data.media : null));
	const content = $derived(
		media
			? createDetailContent(media, {
					titles: signedIn ? 'userPreferred' : 'english',
					adult: signedIn && session.showAdultContent
				})
			: null
	);
	const title = $derived(content?.title);
	const isAnime = $derived(title?.isAnime ?? true);

	// The top bar's Anime / Manga switch follows the title you open, so a
	// manga's page says Manga (and Browse, My List… carry on in manga). Once
	// per title: switching back by hand while you're here stays switched.
	let modeSetFor: number | null = null;
	$effect(() => {
		const t = title;
		if (!t || t.id === modeSetFor) return;
		modeSetFor = t.id;
		untrack(() => session.setMode(t.isAnime ? 'anime' : 'manga'));
	});
	const entry = $derived(title && session.authState !== 'out' ? list.entryFor(title) : null);
	const progress = $derived(entry?.progress ?? 0);
	const myScore = $derived(entry?.score ?? 0);
	// what's out that you haven't seen, while it's in progress
	const fresh = $derived(
		title && entry && isInProgress(entry.status) ? newEpisodesFor(title, progress) : null
	);
	const waiting = $derived(fresh === 0 && !!title?.next);
	const accent = $derived(isAnime ? 'var(--color-anime)' : 'var(--color-manga)');
	/** The cover's colour toward the page: the offset shadows behind covers. */
	const shade = $derived(
		title ? `color-mix(in oklch, ${title.accent} 50%, var(--color-canvas))` : 'transparent'
	);
	const notFound = $derived(
		(!Number.isInteger(id) || id <= 0 || /not found/i.test(detail.error)) && !media
	);

	// ── Actions ──
	function openEditor() {
		if (!title) return;
		if (session.authState === 'out') return void goto('/login');
		editor.open(title);
	}

	function step(delta: 1 | -1) {
		if (!title || !list.sync) return;
		void (delta === 1 ? plusOne(title) : minusOne(title));
	}

	let favourite = $state(false);
	let favouriteBusy = $state(false);
	async function onFavourite() {
		if (!title) return;
		if (session.authState === 'out') return void goto('/login');
		if (favouriteBusy) return;
		favouriteBusy = true;
		favourite = !favourite;
		try {
			await toggleFavourite(title.type, title.id);
		} catch (err) {
			console.error('Failed to toggle favourite:', err);
			favourite = !favourite;
		} finally {
			favouriteBusy = false;
		}
	}

	let shareNote = $state('');
	async function share() {
		const url = location.href;
		try {
			if (navigator.share) await navigator.share({ title: title?.title, url });
			else {
				await navigator.clipboard.writeText(url);
				shareNote = 'Link copied';
				setTimeout(() => (shareNote = ''), 2000);
			}
		} catch {
			// cancelled, or no clipboard access
		}
	}

	function back() {
		if (history.length > 1) history.back();
		else void goto('/');
	}

	// ── Synopsis and tabs ──
	let synopsisOpen = $state(false);
	let spoilersShown = $state(false);
	// manga can have a dozen reading links (one per language): the first few, then "N more"
	const WATCH_PREVIEW = 6;
	let watchOpen = $state(false);
	const spoilerCount = $derived(content?.tags.filter((t) => t.spoiler).length ?? 0);
	const shownTags = $derived(content?.tags.filter((t) => spoilersShown || !t.spoiler) ?? []);
	// a title can carry thirty tags: the best-fitting few (they're ranked by fit), then "N more"
	const TAG_PREVIEW = 8;
	let tagsOpen = $state(false);
	const visibleTags = $derived(tagsOpen ? shownTags : shownTags.slice(0, TAG_PREVIEW));
	type Tab = 'overview' | 'characters' | 'relations' | 'stats' | 'recommendations';
	let tab = $state<Tab>('overview');
	const TABS: { key: Tab; label: string }[] = [
		{ key: 'overview', label: 'Overview' },
		{ key: 'relations', label: 'Relations' },
		{ key: 'characters', label: 'Characters & Staff' },
		{ key: 'stats', label: 'Stats' },
		{ key: 'recommendations', label: 'Recommendations' }
	];

	function onTabKeydown(e: KeyboardEvent) {
		if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
		e.preventDefault();
		const i = TABS.findIndex((t) => t.key === tab);
		const next = TABS[(i + (e.key === 'ArrowRight' ? 1 : -1) + TABS.length) % TABS.length];
		tab = next.key;
		document.getElementById(`tab-${next.key}`)?.focus();
	}

	// on a phone the tabs scroll sideways: bring the open tab fully in when
	// it's cut off (at once: the panel loading in cuts a smooth scroll short)
	$effect(() => {
		const el = document.getElementById(`tab-${tab}`);
		const list = el?.parentElement;
		if (!el || !list) return;
		const a = list.getBoundingClientRect();
		const b = el.getBoundingClientRect();
		// the list's own 16px edge padding
		const left = Math.min(0, b.left - a.left - 16) || Math.max(0, b.right - a.right + 16);
		if (left) list.scrollLeft += left;
	});

	// ── Countdown: live, in the viewer's own timezone ──
	const countdown = $derived.by(() => {
		const next = content?.nextAiring;
		if (!next) return null;
		const left = Math.max(0, next.at - clock.seconds);
		return {
			episode: next.episode,
			parts: [
				{ value: Math.floor(left / 86400), label: 'days' },
				{ value: Math.floor((left % 86400) / 3600), label: 'hrs' },
				{ value: Math.floor((left % 3600) / 60), label: 'min' },
				{ value: left % 60, label: 'sec' }
			],
			when: formatAiringLong(next.at),
			chip: airingChip({ ep: next.episode, in: '', at: next.at }, clock.seconds)
		};
	});
</script>

<svelte:head>
	<!-- the server's search headline (English-first, the next episode) on a first
	     load, which is what search engines read; the viewer's own title after -->
	<title
		>{data.media?.id === id && data.meta?.headline
			? `${data.meta.headline} · miruyo`
			: title
				? `${title.title} · miruyo`
				: 'miruyo'}</title
	>
</svelte:head>

{#snippet statusPanel(compact: boolean)}
	{#if title}
		<div class="flex gap-1.5">
			<button
				type="button"
				onclick={openEditor}
				class="flex h-12 min-w-0 flex-1 press items-center gap-2 rounded-[2px] border px-3.5 text-sm font-semibold"
				style={entry
					? `background:${STATUS_COLOR[entry.status]}1f;border-color:${STATUS_COLOR[entry.status]}59;color:var(--color-ink)`
					: 'background:var(--color-ink);border-color:transparent;color:var(--color-canvas)'}
				data-testid="detail-status"
			>
				{#if entry}
					<span
						class="h-2 w-2 flex-none rounded-full"
						style="background:{STATUS_COLOR[entry.status]}"
						aria-hidden="true"
					></span>
					<span class="flex-1 truncate text-left">{statusLabel(entry.status, isAnime)}</span>
				{:else}
					<span class="material-symbols-rounded text-[20px]!" aria-hidden="true">add</span>
					<span class="flex-1 text-left">Add to list</span>
				{/if}
				<span class="material-symbols-rounded text-[20px]!" aria-hidden="true">edit</span>
			</button>
			{#if !compact}
				<button
					type="button"
					onclick={onFavourite}
					aria-pressed={favourite}
					aria-label={favourite ? 'Remove from favourites' : 'Add to favourites'}
					class="grid h-12 w-12 flex-none press place-items-center rounded-[2px] border border-line hover:border-ink"
					style="color:{favourite ? 'var(--color-pink)' : 'var(--color-muted)'}"
				>
					<span
						class="material-symbols-rounded text-[22px]!"
						style="font-variation-settings:'FILL' {favourite ? 1 : 0}"
						aria-hidden="true">favorite</span
					>
				</button>
			{/if}
		</div>

		{#if entry}
			<div class="flex flex-col gap-3 border-y border-line py-4" data-testid="detail-progress">
				<div class="flex items-center gap-2">
					<div class="font-mono text-[26px] leading-none tabular-nums">
						<Tick value={progress} />
						<!-- the space sits outside the span: Svelte trims it at the start of an element -->
						<span class="text-[15px] text-dim">/ {title.total ?? '?'}</span>
					</div>
					<!-- what's out that you haven't seen, in Home's words -->
					<div
						class="flex-1 text-xs font-semibold"
						style="color:{fresh
							? 'var(--color-green)'
							: waiting
								? 'var(--color-muted)'
								: 'var(--color-muted)'}"
						data-testid="detail-progress-word"
					>
						{fresh
							? `${fresh} ${title.next ? 'new' : 'left'}`
							: waiting
								? 'Caught up'
								: isAnime
									? 'watched'
									: 'read'}
					</div>
					<!-- your score, which opens the editor to set it -->
					<button
						type="button"
						onclick={() => editor.open(title)}
						class="touch-target relative flex items-center gap-1 text-xs font-semibold {myScore
							? 'text-ink'
							: 'text-muted'}"
						aria-label={myScore
							? `Your score ${formatScore(myScore, session.scoreFormat)}, edit`
							: 'Not scored, rate it'}
					>
						<span
							class="material-symbols-rounded !text-[16px]"
							style="color:{myScore
								? 'var(--color-gold)'
								: 'var(--color-dim)'};font-variation-settings:'FILL' {myScore ? 1 : 0}"
							aria-hidden="true">star</span
						>
						{myScore ? `${formatScore(myScore, session.scoreFormat)} yours` : 'Rate it'}
					</button>
				</div>
				<ProgressBar
					value={progress}
					total={title.total}
					color={title.accent}
					track="var(--color-line)"
					full={entry.status === 'COMPLETED'}
					class="h-1"
				/>
				{#if isInProgress(entry.status) || entry.status === 'PLANNING'}
					<div class="flex gap-2">
						<button
							type="button"
							onclick={() => step(-1)}
							disabled={progress <= 0}
							aria-label="One less {isAnime ? 'episode' : 'chapter'}"
							class="grid h-11 w-12 press place-items-center rounded-[2px] border border-line hover:border-ink disabled:opacity-40"
						>
							<span class="material-symbols-rounded text-[22px]!" aria-hidden="true">remove</span>
						</button>
						<button
							type="button"
							onclick={() => step(1)}
							aria-label="Add one {isAnime ? 'episode' : 'chapter'}"
							class="flex h-11 flex-1 press items-center justify-center gap-1 rounded-[2px] bg-ink font-mono text-sm font-bold text-canvas transition-colors hover:bg-muted"
						>
							<span class="material-symbols-rounded text-[20px]!" aria-hidden="true">add</span>1 {title.unit}
						</button>
					</div>
				{/if}
				<div class="flex justify-between border-t border-line pt-3 text-[13px] text-muted">
					<span>Your score</span>
					<span class="font-mono font-semibold text-ink"
						>{formatScore(entry.score ?? 0, session.scoreFormat)}</span
					>
				</div>
			</div>
		{/if}
	{/if}
{/snippet}

{#snippet infoTable()}
	{#if content}
		<dl class="m-0 flex flex-col border-t border-ink">
			{#each content.info as row (row.label)}
				<div class="flex justify-between gap-4 border-b border-line py-2.5 text-[13px]">
					<dt class="pt-px text-[11px] tracking-[0.1em] text-dim uppercase">{row.label}</dt>
					<dd class="m-0 text-right font-mono text-[12.5px] leading-relaxed text-ink">
						{#if row.href}
							<a href={row.href} class="text-ink underline-offset-2 hover:underline">{row.value}</a>
						{:else}{row.value}{/if}
					</dd>
				</div>
			{/each}
		</dl>
	{/if}
{/snippet}

{#snippet characterGrid(limit: number | null)}
	{#if content}
		<div
			class="flex scrollbar-none gap-3 overflow-x-auto lg:grid {limit
				? 'lg:auto-rows-0 lg:grid-rows-[auto] lg:overflow-hidden'
				: 'lg:gap-y-5'} lg:grid-cols-[repeat(auto-fill,minmax(88px,1fr))] lg:gap-x-3"
		>
			{#each limit ? content.characters.slice(0, limit) : content.characters as c (c.id)}
				<a
					href="/character/{c.id}"
					class="group flex w-20 flex-none flex-col gap-1.5 text-ink hover:text-ink lg:w-auto"
				>
					<div
						class="grid aspect-3/4 place-items-center overflow-hidden bg-raised text-dim grayscale-[.3] transition-[filter] group-hover:grayscale-0"
						style={c.image ? `background:${coverBackground(c.image)}` : ''}
					>
						{#if !c.image}<span class="material-symbols-rounded text-[24px]!" aria-hidden="true"
								>person</span
							>{/if}
					</div>
					<div>
						<div class="line-clamp-2 text-[13px] leading-tight font-semibold">{c.name}</div>
						<div class="text-[11px] text-dim">{c.role}</div>
					</div>
				</a>
			{/each}
		</div>
	{/if}
{/snippet}

{#snippet countdownCard()}
	{#if title && countdown && countdown.chip}
		<div class="flex flex-col gap-3 border-y border-line py-4" data-testid="countdown">
			<div class="flex items-center gap-2 text-[13px] font-semibold">
				<span
					class="h-2 w-2 rounded-full bg-green shadow-[0_0_0_4px_rgba(78,217,138,.18)]"
					aria-hidden="true"
				></span>
				{countdown.chip.phase === 'live'
					? `Episode ${countdown.episode} is airing now`
					: `Episode ${countdown.episode} airs in`}
			</div>
			<div class="flex justify-between" aria-live="off">
				{#each countdown.parts as part (part.label)}
					<div class="flex flex-col items-center gap-1">
						<div
							class="font-display text-[30px] leading-none font-light tracking-[-0.03em] tabular-nums"
							style="color:{part.label === 'days' ? title.accent : 'var(--color-ink)'}"
						>
							{String(part.value).padStart(2, '0')}
						</div>
						<div class="text-[10px] tracking-[0.12em] text-dim uppercase">{part.label}</div>
					</div>
				{/each}
			</div>
			<div class="text-xs text-muted">{countdown.when} your time</div>
		</div>
	{/if}
{/snippet}

<!-- related titles on a timeline: a dot in each relation's colour on one rule -->
{#snippet relationCards(limit: number | null)}
	{#if content}
		<ol
			class="m-0 flex list-none p-0 {limit
				? 'scrollbar-none overflow-x-auto pb-1'
				: 'flex-wrap gap-y-8'}"
		>
			{#each limit ? content.relations.slice(0, limit) : content.relations as r (r.id)}
				<li class="relative w-[150px] flex-none pt-7 pr-5 lg:w-[164px]">
					<span class="absolute inset-x-0 top-[7px] h-px bg-line" aria-hidden="true"></span>
					<span
						class="absolute top-[2px] left-0 h-[11px] w-[11px] rounded-full border-[1.5px] bg-canvas"
						style="border-color:{r.color}"
						aria-hidden="true"
					></span>
					<a href="/title/{r.id}" class="group block text-ink hover:text-ink">
						<div
							class="mb-3 aspect-2/3 w-[78px] transition-[box-shadow,transform] duration-(--duration-lift) ease-enter group-hover:-translate-0.5 group-hover:shadow-[5px_5px_0_var(--shade)]"
							style="background:{r.cover};--shade:color-mix(in oklch, {r.color} 50%, var(--color-canvas))"
						></div>
						<div
							class="text-[10.5px] font-semibold tracking-[0.1em] uppercase"
							style="color:{r.color}"
						>
							{r.relation}
						</div>
						<div class="mt-1 line-clamp-2 text-[13px] leading-snug font-semibold">{r.title}</div>
						<div class="mt-0.5 text-[11.5px] text-dim">{r.meta}</div>
					</a>
				</li>
			{/each}
		</ol>
	{/if}
{/snippet}

{#snippet linkChips(links: LinkChip[])}
	<div class="flex flex-wrap gap-2">
		{#each links as l (l.id)}
			<a
				href={l.url}
				target="_blank"
				rel="noreferrer"
				class="flex h-10 press items-center gap-2 rounded-[2px] border border-line pr-3 pl-1.5 text-sm font-semibold text-ink hover:border-ink hover:text-ink"
			>
				<span
					class="grid h-6.5 w-6.5 flex-none place-items-center rounded-[2px]"
					style="background:{l.color ?? 'var(--color-raised-hover)'}"
					aria-hidden="true"
				>
					{#if l.icon}
						<img src={l.icon} alt="" width="16" height="16" class="h-4 w-4" loading="lazy" />
					{:else}
						<span class="material-symbols-rounded text-[16px]!">open_in_new</span>
					{/if}
				</span>
				{l.site}
				{#if l.detail}<span class="text-xs font-normal text-dim">{l.detail}</span>{/if}
				<span class="text-dim" aria-hidden="true">↗</span>
				<span class="sr-only">(opens in a new tab)</span>
			</a>
		{/each}
	</div>
{/snippet}

{#snippet recommendationGrid()}
	{#if content}
		<div class="grid grid-cols-2 gap-x-3 gap-y-5 md:grid-cols-4 lg:grid-cols-6 lg:gap-5">
			{#each content.recommendations as t (t.id)}
				<PosterCard title={t} size="sm" loggedOut={session.authState === 'out'} />
			{/each}
		</div>
	{/if}
{/snippet}

<PageShell nav="browse" tab="browse">
	{#if notFound}
		<div class="flex flex-col items-center gap-3 px-6 py-24 text-center">
			<span class="material-symbols-rounded text-[40px]! text-dim" aria-hidden="true"
				>search_off</span
			>
			<h1 class="m-0 font-display text-2xl font-bold">This title doesn't exist</h1>
			<p class="m-0 text-sm text-muted">It may have been removed from AniList.</p>
			<a href="/browse" class="mt-2 font-semibold">Browse titles →</a>
		</div>
	{:else if detail.failed && !media}
		<div class="px-4 pt-10 lg:px-10 xl:px-20">
			<SectionError
				title="Couldn't load this title"
				onRetry={() => load(id, signedIn)}
				detail={detail.error}
				retryIn={detail.retry.active ? detail.retry.label : undefined}
				rateLimited={detail.rateLimited}
			/>
		</div>
	{:else if !content || !title}
		<div class="flex flex-col gap-6" aria-busy="true" aria-label="Loading title">
			<div class="skeleton-shimmer h-75 lg:h-[360px]"></div>
			<div class="flex flex-col gap-4 px-4 lg:-mt-40 lg:flex-row lg:gap-12 lg:px-10 xl:px-20">
				<Skeleton class="aspect-2/3 w-28 lg:w-60" />
				<div class="flex flex-1 flex-col gap-3 lg:pt-24">
					<Skeleton class="h-4 w-40" />
					<Skeleton class="h-10 w-3/4" />
					<Skeleton class="h-4 w-1/2" />
				</div>
			</div>
		</div>
	{:else}
		<!-- banner: the cover colour owns the page -->
		<div class="relative h-75 overflow-hidden lg:h-[360px]" style="background:{title.accent}">
			{#if content.banner}
				<div
					class="absolute inset-0 opacity-90 mix-blend-multiply brightness-90 contrast-125 grayscale"
					style="background:{content.banner}"
					data-testid="detail-banner"
				></div>
			{:else}
				<div
					class="absolute -inset-16"
					style="background:{title.cover};filter:blur(40px) saturate(1.2)"
					data-testid="detail-banner-fallback"
				></div>
			{/if}
			<div
				class="absolute inset-0"
				style="background:linear-gradient(0deg,#13110F 0%,rgba(19,17,15,.5) 50%,rgba(19,17,15,.1) 100%)"
			></div>
			<div
				class="absolute inset-0"
				style="background:radial-gradient(circle at 1px 1px, rgb(19 17 15 / .55) 1px, transparent 1.5px) 0 0 / 5px 5px"
				aria-hidden="true"
			></div>
			<!-- mobile: back and share over the banner -->
			<div class="absolute inset-x-3 top-3 flex justify-between lg:hidden">
				<button
					type="button"
					onclick={back}
					aria-label="Back"
					class="grid h-11 w-11 place-items-center rounded-full bg-[rgba(19,17,15,.6)] text-ink backdrop-blur-md"
				>
					<span class="material-symbols-rounded text-[22px]!" aria-hidden="true">arrow_back</span>
				</button>
				<button
					type="button"
					onclick={share}
					aria-label="Share"
					class="grid h-11 w-11 place-items-center rounded-full bg-[rgba(19,17,15,.6)] text-ink backdrop-blur-md"
				>
					<span class="material-symbols-rounded text-[22px]!" aria-hidden="true">ios_share</span>
				</button>
			</div>
		</div>

		<div
			class="relative -mt-32.5 grid gap-6 px-4 pb-20 lg:-mt-47.5 lg:grid-cols-[250px_minmax(0,1fr)] lg:gap-14 lg:px-10 xl:gap-16 xl:px-20"
		>
			<!-- the status column: sticky so updating never needs a scroll past the synopsis -->
			<aside class="hidden lg:block">
				<div class="sticky top-20 flex flex-col gap-5">
					<div
						class="mb-2 aspect-2/3 w-[calc(100%-12px)]"
						style="background:{title.cover};box-shadow:12px 12px 0 {shade}"
					></div>
					{@render statusPanel(false)}
					<!-- the next episode, between your progress and the facts -->
					{@render countdownCard()}
					{@render infoTable()}
				</div>
			</aside>

			<div class="flex min-w-0 flex-col gap-6 lg:pt-24">
				<!-- headline (mobile: next to a smaller cover) -->
				<div class="flex items-end gap-3.5 lg:block">
					<div
						class="aspect-2/3 w-28 flex-none lg:hidden"
						style="background:{title.cover};box-shadow:6px 6px 0 {shade}"
					></div>
					<div class="flex min-w-0 flex-col gap-1.5 pb-1 lg:gap-2.5 lg:pb-0">
						<!-- no ANIME / MANGA badge: the mode switch in the top bar already says -->
						<div
							class="hidden rise text-xs font-semibold tracking-[0.14em] text-muted uppercase lg:block"
						>
							{content.overline}
						</div>
						<h1
							class="m-0 rise font-display text-[30px] leading-[0.98] font-semibold tracking-[-0.03em] text-balance [--d:70ms] lg:text-[clamp(44px,5vw,76px)] lg:leading-[0.92] lg:tracking-[-0.045em]"
						>
							{title.title}
						</h1>
						{#if content.altTitles}
							<div
								class="line-clamp-1 text-[13px] text-muted lg:mt-1 lg:line-clamp-none lg:text-[15px]"
							>
								{content.altTitles}
							</div>
						{/if}
						<!-- the score is in the row below, large -->
						<div class="text-xs text-muted lg:hidden">{title.format} · {title.countLabel}</div>
					</div>
				</div>

				<!-- mobile: the countdown strip and the status card -->
				{#if countdown && countdown.chip}
					<div class="flex items-center gap-2 border-y border-line py-2.5 text-[13px] lg:hidden">
						<span class="h-2 w-2 rounded-full bg-green" aria-hidden="true"></span>
						<span class="flex-1 text-[#DDD3C3]">EP {countdown.episode} airs {countdown.when}</span>
						<span class="font-mono text-[13px] font-semibold" style="color:{title.accent}">
							{countdown.parts[0].value}d {String(countdown.parts[1].value).padStart(2, '0')}h {String(
								countdown.parts[2].value
							).padStart(2, '0')}m
						</span>
					</div>
				{/if}
				<div class="flex flex-col gap-3 lg:hidden">
					{@render statusPanel(true)}
				</div>

				<!-- stats row -->
				<div
					class="flex rise flex-wrap items-end gap-x-8 gap-y-4 border-y border-line py-5 [--d:160ms]"
				>
					<div class="flex flex-col gap-1">
						<div
							class="font-display text-[60px] leading-[0.8] font-extralight tracking-[-0.06em]"
							style="color:{title.accent}"
						>
							{title.score || '—'}
						</div>
						<div class="text-[11px] tracking-[0.1em] text-dim uppercase">Average score</div>
					</div>
					{#if content.rank}
						<div class="hidden h-12 w-px bg-line lg:block"></div>
						<div class="flex flex-col gap-1">
							<div class="font-mono text-lg tabular-nums">{content.rank.value}</div>
							<div class="text-[11px] tracking-[0.1em] text-dim uppercase">
								{content.rank.label}
							</div>
						</div>
					{/if}
					<div class="flex flex-col gap-1">
						<div class="font-mono text-lg tabular-nums">{content.members}</div>
						<div class="text-[11px] tracking-[0.1em] text-dim uppercase">Members</div>
					</div>
					{#if content.trailer}
						<a
							href={content.trailer.url}
							target="_blank"
							rel="noreferrer"
							class="flex h-10 press items-center gap-1.5 rounded-[2px] border border-line pr-3.5 pl-2.5 text-sm font-semibold text-ink hover:border-ink hover:text-ink"
							aria-label="Watch the trailer (opens in a new tab)"
						>
							<span
								class="material-symbols-rounded text-[20px]!"
								style="font-variation-settings:'FILL' 1"
								aria-hidden="true">play_arrow</span
							>
							Trailer
						</a>
					{/if}
					<!-- genres as words, not pills -->
					<div class="flex flex-wrap items-baseline text-[14px] text-muted lg:ml-auto">
						{#each title.genres as g, i (g)}
							{#if i}<span class="px-1.5 text-dim" aria-hidden="true">/</span>{/if}<a
								href="/browse?genre={encodeURIComponent(g)}"
								class="text-muted underline-offset-4 hover:text-ink hover:underline">{g}</a
							>
						{/each}
					</div>
				</div>

				{#if title.synopsis}
					<div class="flex max-w-[70ch] flex-col items-start gap-2">
						<p
							class="m-0 text-[15px] leading-relaxed text-pretty whitespace-pre-line text-muted lg:text-base lg:leading-[1.7] lg:first-letter:float-left lg:first-letter:mt-1.5 lg:first-letter:mr-2.5 lg:first-letter:font-display lg:first-letter:text-[66px] lg:first-letter:leading-[0.8] lg:first-letter:font-semibold lg:first-letter:text-(--drop) {synopsisOpen
								? ''
								: 'line-clamp-3'}"
							id="synopsis"
							style="--drop:{title.accent}"
						>
							{title.synopsis}
						</p>
						<button
							type="button"
							onclick={() => (synopsisOpen = !synopsisOpen)}
							aria-expanded={synopsisOpen}
							aria-controls="synopsis"
							class="flex items-center gap-0.5 text-sm font-semibold text-muted hover:text-ink"
						>
							{synopsisOpen ? 'Show less' : 'Read more'}
							<span class="material-symbols-rounded text-[20px]!" aria-hidden="true"
								>{synopsisOpen ? 'expand_less' : 'expand_more'}</span
							>
						</button>
					</div>
				{/if}

				<!-- where to watch / read: above the tabs, so it's there on every tab -->
				{#if content.watch.length}
					<section class="flex flex-col gap-2.5" data-testid="detail-watch">
						<div class="flex items-baseline">
							<h2 class="m-0 flex-1 text-[11px] font-semibold tracking-[0.14em] text-dim uppercase">
								{isAnime ? 'Where to watch' : 'Where to read'}
							</h2>
							{#if content.watch.length > WATCH_PREVIEW}
								<button
									type="button"
									onclick={() => (watchOpen = !watchOpen)}
									aria-expanded={watchOpen}
									class="text-sm font-semibold text-muted hover:text-ink"
								>
									{watchOpen ? 'Show fewer' : `${content.watch.length - WATCH_PREVIEW} more`}
								</button>
							{/if}
						</div>
						{@render linkChips(watchOpen ? content.watch : content.watch.slice(0, WATCH_PREVIEW))}
					</section>
				{/if}

				<!-- on phones the facts sit above the tabs, as the desktop sidebar keeps them on every tab -->
				<div class="lg:hidden">{@render infoTable()}</div>

				<div
					class="sticky top-14 z-10 -mx-4 flex scrollbar-none gap-1 overflow-x-auto border-b border-line bg-canvas/90 px-4 backdrop-blur-md lg:top-16 lg:mx-0 lg:px-0"
					role="tablist"
					aria-label="Title sections"
					tabindex="-1"
					onkeydown={onTabKeydown}
				>
					{#each TABS as t (t.key)}
						{@const on = tab === t.key}
						<button
							type="button"
							role="tab"
							id="tab-{t.key}"
							aria-selected={on}
							aria-controls="panel-{t.key}"
							tabindex={on ? 0 : -1}
							onclick={() => (tab = t.key)}
							class="h-11 flex-none px-3 text-sm whitespace-nowrap {on
								? 'font-semibold text-ink'
								: 'text-muted'}"
							style="box-shadow:{on ? `inset 0 -2px 0 ${accent}` : 'none'}"
						>
							{t.label}
						</button>
					{/each}
				</div>

				<div
					id="panel-{tab}"
					role="tabpanel"
					aria-labelledby="tab-{tab}"
					class="flex flex-col gap-9"
				>
					{#if tab === 'overview'}
						{#if content.tags.length}
							<section class="flex flex-col gap-3.5" data-testid="detail-tags">
								<div class="flex items-baseline">
									<h2 class="m-0 font-display text-[26px] font-medium tracking-[-0.02em]">Tags</h2>
									<span class="mx-4 h-px min-w-4 flex-1 self-center bg-line" aria-hidden="true"
									></span>
									{#if spoilerCount}
										<button
											type="button"
											onclick={() => {
												spoilersShown = !spoilersShown;
												// a spoiler can rank below the fold: showing them shows them all
												if (spoilersShown) tagsOpen = true;
											}}
											aria-pressed={spoilersShown}
											class="text-sm font-semibold text-muted hover:text-ink"
										>
											{spoilersShown
												? 'Hide spoilers'
												: `Show ${spoilerCount} spoiler${spoilerCount === 1 ? '' : 's'}`}
										</button>
									{/if}
								</div>
								{#if shownTags.length}
									<div class="flex flex-wrap items-baseline gap-x-5 gap-y-2" id="detail-tag-list">
										{#each visibleTags as t (t.name)}
											<a
												href="/browse?tag={encodeURIComponent(t.name)}"
												title={t.description ?? undefined}
												class="inline-flex items-baseline gap-1 text-[14px] underline-offset-4 hover:text-ink hover:underline {t.spoiler
													? 'text-anime-soft'
													: 'text-[#DDD3C3]'}"
											>
												{t.name}
												<span class="font-mono text-[11px] text-dim">{t.rank}%</span>
												{#if t.spoiler}<span class="sr-only">(spoiler)</span>{/if}
											</a>
										{/each}
										{#if shownTags.length > TAG_PREVIEW}
											<button
												type="button"
												onclick={() => (tagsOpen = !tagsOpen)}
												aria-expanded={tagsOpen}
												aria-controls="detail-tag-list"
												class="flex items-center gap-0.5 text-[13px] font-semibold text-muted hover:text-ink"
											>
												{tagsOpen ? 'Show fewer' : `${shownTags.length - TAG_PREVIEW} more`}
												<span class="material-symbols-rounded !text-[18px]" aria-hidden="true"
													>{tagsOpen ? 'expand_less' : 'expand_more'}</span
												>
											</button>
										{/if}
									</div>
								{/if}
							</section>
						{/if}

						<!-- manga: publication + authors (anime's countdown sits in the status column) -->
						{#if !isAnime}
							<div class="flex flex-col gap-5 lg:flex-row lg:items-start">
								<div class="relative flex flex-col gap-4 border-t border-ink pt-4 lg:flex-1">
									<div class="text-[11px] font-semibold tracking-wider text-muted uppercase">
										Publication
									</div>
									<div class="grid grid-cols-2 gap-2.5">
										<div class="border-b border-line pb-3">
											<div
												class="font-display text-[40px] leading-none font-light tracking-[-0.04em]"
											>
												{title.total ?? '—'}
											</div>
											<div class="mt-1.5 text-xs text-dim">
												{title.total ? 'Chapters' : 'Chapters (ongoing)'}
											</div>
										</div>
										<div class="border-b border-line pb-3">
											<div
												class="font-display text-[40px] leading-none font-light tracking-[-0.04em]"
											>
												{title.vol ?? '—'}
											</div>
											<div class="mt-1.5 text-xs text-dim">Volumes</div>
										</div>
									</div>
									<div class="flex items-center gap-2 text-[13px] text-[#DDD3C3]">
										<span
											class="rounded-[2px] px-2 py-0.5 text-xs font-semibold"
											style="background:{title.tint};color:{title.accent}">{title.status}</span
										>
										{content.overline}
									</div>
								</div>
								{#if content.authors.length}
									<div class="flex flex-col gap-3.5 border-t border-ink pt-4 lg:flex-1">
										<div class="text-[11px] font-semibold tracking-wider text-muted uppercase">
											Authors
										</div>
										{#each content.authors as a (a.id + a.role)}
											<a
												href="/staff/{a.id}"
												class="flex items-center gap-3 text-ink hover:text-ink"
											>
												<div
													class="h-13 w-13 flex-none rounded-full bg-raised"
													style={a.image ? `background:${coverBackground(a.image)}` : ''}
												></div>
												<div>
													<div class="text-[15px] font-semibold">{a.name}</div>
													<div class="text-[13px] text-dim">{a.role}</div>
												</div>
											</a>
										{/each}
									</div>
								{/if}
							</div>
						{/if}

						{#if content.relations.length}
							<section class="flex flex-col gap-3.5">
								<div class="flex items-baseline">
									<h2 class="m-0 font-display text-[26px] font-medium tracking-[-0.02em]">
										Relations
									</h2>
									<span class="mx-4 h-px min-w-4 flex-1 self-center bg-line" aria-hidden="true"
									></span>
									{#if content.relations.length > 8}
										<button
											type="button"
											onclick={() => (tab = 'relations')}
											class="text-sm font-semibold text-muted hover:text-ink"
											>All {content.relations.length} →</button
										>
									{/if}
								</div>
								{@render relationCards(8)}
							</section>
						{/if}

						{#if content.characters.length}
							<section class="flex flex-col gap-3.5">
								<div class="flex items-baseline">
									<h2 class="m-0 font-display text-[26px] font-medium tracking-[-0.02em]">
										Characters
									</h2>
									<span class="mx-4 h-px min-w-4 flex-1 self-center bg-line" aria-hidden="true"
									></span>
									<button
										type="button"
										onclick={() => (tab = 'characters')}
										class="text-sm font-semibold text-muted hover:text-ink">All →</button
									>
								</div>
								{@render characterGrid(12)}
							</section>
						{/if}

						{#if content.recommendations.length}
							<section class="flex flex-col gap-3.5">
								<h2 class="m-0 font-display text-[26px] font-medium tracking-[-0.02em]">
									If you like this
								</h2>
								{@render recommendationGrid()}
							</section>
						{/if}

						{#if content.links.length}
							<section class="flex flex-col gap-3.5">
								<h2 class="m-0 font-display text-[26px] font-medium tracking-[-0.02em]">Links</h2>
								{@render linkChips(content.links)}
							</section>
						{/if}

						{#if content.synonyms.length}
							<section class="flex flex-col gap-2">
								<h2 class="m-0 font-display text-[26px] font-medium tracking-[-0.02em]">
									Also known as
								</h2>
								<!-- each name isolated, so a right-to-left one doesn't reorder its neighbours -->
								<p class="m-0 text-sm leading-relaxed text-muted">
									{#each content.synonyms as name, i (name)}{#if i}{' · '}{/if}<bdi>{name}</bdi
										>{/each}
								</p>
							</section>
						{/if}
					{:else if tab === 'characters'}
						{#if content.characters.length}
							<!-- credits: the character, a dotted leader, then who voices them -->
							<div class="grid lg:grid-cols-2 lg:gap-x-14">
								{#each content.characters as c (c.id)}
									<div
										class="grid grid-cols-[minmax(0,auto)_minmax(16px,1fr)_minmax(0,auto)] items-center gap-3 border-b border-line py-2.5"
									>
										<a
											href="/character/{c.id}"
											class="group flex min-w-0 items-center gap-3 text-ink hover:text-ink"
										>
											<div
												class="h-11 w-11 flex-none rounded-full bg-raised grayscale-[.3] group-hover:grayscale-0"
												style={c.image ? `background:${coverBackground(c.image)}` : ''}
											></div>
											<div class="min-w-0">
												<div class="truncate text-[14px] font-semibold">{c.name}</div>
												<div class="text-[11.5px] text-dim">{c.role}</div>
											</div>
										</a>
										<span
											class="h-0 translate-y-1 border-b border-dotted border-dim/70"
											aria-hidden="true"
										></span>
										{#if c.voice}
											<a
												href="/staff/{c.voice.id}"
												class="group flex min-w-0 items-center gap-3 text-ink hover:text-ink"
											>
												<div class="min-w-0 text-right">
													<div class="truncate text-[14px] font-semibold">{c.voice.name}</div>
													<div class="text-[11.5px] text-dim">{c.voice.role}</div>
												</div>
												<div
													class="h-11 w-11 flex-none rounded-full bg-raised grayscale-[.3] group-hover:grayscale-0"
													style={c.voice.image
														? `background:${coverBackground(c.voice.image)}`
														: ''}
												></div>
											</a>
										{:else}
											<span></span>
										{/if}
									</div>
								{/each}
							</div>
						{:else}
							<p class="m-0 text-sm text-muted">No characters listed on AniList yet.</p>
						{/if}
					{:else if tab === 'stats'}
						<TitleStats id={title.id} {isAnime} accent={title.accent} />
					{:else if tab === 'relations'}
						{#if content.relations.length}
							{@render relationCards(null)}
						{:else}
							<p class="m-0 text-sm text-muted">No related titles on AniList.</p>
						{/if}
					{:else if content.recommendations.length}
						{@render recommendationGrid()}
					{:else}
						<p class="m-0 text-sm text-muted">No recommendations yet.</p>
					{/if}
				</div>
			</div>
		</div>
	{/if}

	{#if shareNote}
		<div class="fixed inset-x-0 bottom-28 z-50 flex justify-center lg:bottom-8" role="status">
			<div class="rounded-[2px] bg-ink px-4 py-2 text-sm font-semibold text-surface">
				{shareNote}
			</div>
		</div>
	{/if}
</PageShell>
