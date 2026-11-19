<script lang="ts">
	import { formatTimeUntil } from '#lib/anilist/humanize.ts';
	import { newEpisodesFor } from '#lib/catalog/progress.ts';
	import { STATUS_COLOR } from '#lib/catalog/status.ts';
	import type { Title } from '#lib/catalog/types.ts';
	import CoverImage from '#lib/components/shared/CoverImage.svelte';
	import ProgressBar from '#lib/components/shared/ProgressBar.svelte';
	import type { ContinueItem } from '#lib/page-data/home.ts';
	import { clock } from '#lib/state/clock.svelte.ts';
	import { changeStatus, plusOne } from '#lib/state/list-actions.ts';
	import SectionHeading from '#lib/components/shared/SectionHeading.svelte';
	import Tick from '#lib/components/shared/Tick.svelte';

	// Continue (design 01): everything you're tracking. Ready titles first
	// (their +1 brighter), then Up next, then those waiting for their next
	// episode (with a countdown); Paused fold into one line at the end. With
	// nothing ready, it leads with "You're caught up".
	//
	// Touch follows the app: a heading and summary over a plain list of rows
	// (two columns on tablets); it comes first on Home there.
	// Desktop is editorial (design/mockups/home-editorial): the title you're
	// furthest behind on leads, large, with a +1 that says where it takes you;
	// the rest follow as ruled rows, and a column beside them lists when the
	// next episodes on your list air. Caught up, a ruled line says so and when
	// the next one airs.

	interface Props {
		items: ContinueItem[];
		/** Caught up on everything: the next to air leads, as a card. */
		caughtUp: ContinueItem | null;
		paused: Title[];
		/** Planning, first few by priority: a +1 starts one. */
		upNext: ContinueItem[];
		isAnime: boolean;
		/** "Continue watching": desktop's heading row (touch has it over the hero). */
		title: string;
		/** "3 new episodes · 2 airing this week": what these rows hold, not the hero's. */
		summary: string;
		summaryFresh: boolean;
	}

	let { items, caughtUp, paused, upNext, isAnime, title, summary, summaryFresh }: Props = $props();

	/** Rows shown before "Show all" (touch: five; desktop: rows of two or three). */
	const SHOWN = 5;
	const SHOWN_WIDE = 6;
	let all = $state(false);
	const visible = $derived(all ? items : items.slice(0, SHOWN));
	const visibleWide = $derived(all ? items : items.slice(0, SHOWN_WIDE));
	/** Where the waiting titles start, for their label (the caught-up card heads them otherwise). */
	const firstWaiting = (rows: ContinueItem[]) => (caughtUp ? -1 : rows.findIndex((i) => i.waiting));
	const waitingLabel = $derived(
		isAnime ? 'Waiting for the next episode' : 'Waiting for the next chapter'
	);

	const countdown = (item: ContinueItem) =>
		item.title.next?.at ? formatTimeUntil(item.title.next.at - clock.seconds) : '';
	/** Episodes out that you haven't seen (0 when the schedule doesn't say). */
	const fresh = (item: ContinueItem) => newEpisodesFor(item.title, item.progress) ?? 0;
	/**
	 * Desktop's lead: of what's ready to watch, the one you're furthest
	 * behind on (the first, when none says how far).
	 */
	const lead = $derived.by(() => {
		const ready = items.filter((i) => !i.waiting && i.status !== 'PLANNING');
		if (!ready.length) return null;
		return ready.reduce((best, i) => (fresh(i) > fresh(best) ? i : best), ready[0]);
	});
	/**
	 * The rows under it: what you can act on first (ready, then Up next) and
	 * the waiting last; each row's line says what it is.
	 */
	const queue = $derived([
		...visibleWide.filter((i) => !i.waiting && i.id !== lead?.id),
		...upNext,
		...visibleWide.filter((i) => i.waiting)
	]);

	/** The schedule column: the next airings on your list, soonest first. */
	const schedule = $derived(
		[...items, ...upNext, ...(caughtUp ? [caughtUp] : [])]
			.filter((i) => i.title.next?.at && i.title.next.at > clock.seconds)
			.filter((i, n, all) => all.findIndex((o) => o.id === i.id) === n)
			.sort((a, b) => a.title.next!.at! - b.title.next!.at!)
			.slice(0, 7)
	);
	const clockTime = (at: number) =>
		new Date(at * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
	/** "Today", "Tomorrow", else the weekday ("Sat"). */
	function airDay(at: number): string {
		const day = new Date(at * 1000);
		const today = new Date(clock.seconds * 1000);
		const days = Math.round(
			(new Date(day.toDateString()).getTime() - new Date(today.toDateString()).getTime()) /
				86_400_000
		);
		if (days === 0) return 'Today';
		if (days === 1) return 'Tomorrow';
		return day.toLocaleDateString([], { weekday: 'short' });
	}
	/** Up next rows say so in their line. */
	const wideSub = (item: ContinueItem) =>
		item.status === 'PLANNING' ? `Up next · ${item.sub}` : item.sub;
	const hasQueue = $derived(!!lead || queue.length > 0 || paused.length > 0);
	const atTotal = (item: ContinueItem) => !!item.title.total && item.progress >= item.title.total;

	/** 384 → "6h 24m", 45 → "45m". */
	const hoursMinutes = (minutes: number) =>
		minutes >= 60
			? `${Math.floor(minutes / 60)}h${minutes % 60 ? ` ${minutes % 60}m` : ''}`
			: `${minutes}m`;
	/** "12 eps", a movie's "1h 46m", "120 ch"; null when AniList doesn't say. */
	function length(title: Title): string | null {
		if (title.isAnime && title.total === 1 && title.duration) return hoursMinutes(title.duration);
		if (!title.total) return null;
		return title.isAnime
			? `${title.total} ${title.total === 1 ? 'ep' : 'eps'}`
			: `${title.total} ch`;
	}

	/**
	 * The title line's other end: when the next episode airs, or (finished)
	 * the time left to finish it; on Up next, how long it is (what helps pick
	 * one to start). Waiting rows already show their countdown on the right.
	 */
	function aside(item: ContinueItem): { text: string; color: string } | null {
		const { title } = item;
		if (item.waiting) return null;
		if (item.status === 'PLANNING') {
			const text = length(title);
			return text ? { text, color: 'var(--color-dim)' } : null;
		}
		if (title.next?.at) {
			return {
				text: `${title.unit} ${title.next.ep} in ${countdown(item)}`,
				color: 'var(--color-muted)'
			};
		}
		const left = (title.total ?? 0) - item.progress;
		return title.duration && left > 0
			? { text: `${hoursMinutes(left * title.duration)} left`, color: 'var(--color-dim)' }
			: null;
	}
</script>

<!-- the row's one thing on the right: +1, Complete, or the countdown while you wait -->
{#snippet action(item: ContinueItem, size: string)}
	{#if item.waiting}
		<span class="flex-none font-mono text-xs text-muted tabular-nums">{countdown(item)}</span>
	{:else if atTotal(item)}
		<button
			type="button"
			onclick={() => changeStatus(item.title, 'COMPLETED')}
			aria-label="Mark {item.title.title} as completed"
			class="touch-target relative grid flex-none press place-items-center rounded-full {size}"
			style="background:var(--color-green);color:#06210F"
		>
			<span class="material-symbols-rounded !text-[20px]" aria-hidden="true">task_alt</span>
		</button>
	{:else if item.status === 'PLANNING'}
		<!-- Up next: a +1 starts it (Watching, at episode 1), so it says Start, not ▶ -->
		<button
			type="button"
			onclick={() => plusOne(item.title)}
			aria-label="Start {item.title.title}"
			title="Move to {isAnime ? 'Watching' : 'Reading'}, with {item.title.unit} 1 done"
			class="touch-target relative flex h-8 flex-none press items-center justify-center rounded-[2px] border border-line px-3 text-[13px] font-semibold text-ink hover:border-ink"
		>
			Start
		</button>
	{:else}
		<!-- quiet, except where there's something new to watch: then filled in ink -->
		{@const isFresh = fresh(item) > 0}
		<button
			type="button"
			onclick={() => plusOne(item.title)}
			aria-label="Add one {isAnime ? 'episode' : 'chapter'} to {item.title.title}"
			title="+1 {isAnime ? 'episode' : 'chapter'}"
			class="touch-target relative grid flex-none press place-items-center rounded-full border {size} {isFresh
				? 'border-ink bg-ink text-canvas hover:bg-muted'
				: 'border-line text-muted hover:border-ink hover:text-ink'}"
		>
			<span class="material-symbols-rounded !text-[20px]" aria-hidden="true">add</span>
		</button>
	{/if}
{/snippet}

<!-- a row's title, with the aside at the other end of its line -->
{#snippet titleLine(item: ContinueItem, cls: string)}
	{@const extra = aside(item)}
	<span class="flex min-w-0 items-baseline gap-2">
		<span
			title={item.title.title}
			class="min-w-0 flex-1 truncate font-semibold transition-colors {cls} {item.waiting
				? 'text-muted'
				: 'text-ink'}">{item.title.title}</span
		>
		{#if extra}
			<span
				class="flex-none font-mono text-[11px] tabular-nums"
				style="color:{extra.color}"
				data-testid="continue-aside">{extra.text}</span
			>
		{/if}
	</span>
{/snippet}

{#snippet cover(item: ContinueItem)}
	<div
		class="relative aspect-2/3 w-11 flex-none overflow-hidden"
		style="background:{item.title.placeholder}"
	>
		<CoverImage title={item.title} thumb />
	</div>
{/snippet}

<!-- nothing watched yet (Up next), no bar: an empty track only adds a line -->
{#snippet bar(item: ContinueItem, cls: string)}
	{#if item.progress > 0}
		<ProgressBar
			value={item.progress}
			total={item.title.total}
			color={item.title.accent}
			track="var(--color-line)"
			class={cls}
		/>
	{/if}
{/snippet}

{#snippet touchRow(item: ContinueItem)}
	<li class="flex items-center gap-3 border-b border-line px-4 py-2.5 md:px-0">
		<a
			href="/title/{item.id}"
			class="flex min-w-0 flex-1 items-center gap-3 text-ink hover:text-ink"
		>
			{@render cover(item)}
			<div class="flex min-w-0 flex-1 flex-col gap-0.5">
				{@render titleLine(item, 'text-[15px]')}
				<span class="truncate text-xs font-medium tabular-nums" style="color:{item.subColor}"
					>{item.sub}</span
				>
				{@render bar(item, 'mt-1 h-[3px]')}
			</div>
		</a>
		{@render action(item, 'h-9 w-9')}
	</li>
{/snippet}

{#snippet pausedLine(cls: string)}
	<a
		href="/list?tab=paused"
		class="flex items-center gap-3 text-ink hover:text-ink {cls}"
		aria-label="{paused.length} paused, in My List"
	>
		<span
			class="grid h-8 w-8 flex-none place-items-center rounded-full border border-line text-muted"
		>
			<span
				class="material-symbols-rounded !text-[18px]"
				style="font-variation-settings:'FILL' 1"
				aria-hidden="true">pause</span
			>
		</span>
		<span class="flex-none text-sm font-semibold">{paused.length} paused</span>
		<span class="min-w-0 flex-1 truncate text-xs text-dim"
			>{paused.map((t) => t.title).join(', ')}</span
		>
		<span class="material-symbols-rounded !text-[20px] text-dim" aria-hidden="true"
			>chevron_right</span
		>
	</a>
{/snippet}

{#snippet showAll(cls: string)}
	<button
		type="button"
		onclick={() => (all = !all)}
		class="touch-target relative self-start text-sm font-medium text-muted hover:text-ink {cls}"
	>
		{all ? 'Show fewer' : `Show all ${items.length}`}
	</button>
{/snippet}

{#snippet myList()}
	<a
		href="/list"
		class="touch-target relative flex-none text-sm font-medium text-muted hover:text-ink"
		>My List →</a
	>
{/snippet}

<section data-testid="continue">
	<!-- ── touch: the app's list ── -->
	<div class="flex flex-col lg:hidden">
		<SectionHeading heading={title} level="h2" class="px-4" end={myList} />
		{#if summary}
			<div
				class="mt-1 px-4 text-[13px] font-semibold"
				style="color:{summaryFresh ? 'var(--color-green)' : 'var(--color-muted)'}"
				data-testid="continue-summary"
			>
				{summary}
			</div>
		{/if}

		{#if caughtUp}
			{@const next = caughtUp.title.next}
			<div class="mx-4 mt-3 border-y border-line py-3">
				<div class="font-display text-lg italic">You're caught up.</div>
				<div class="mt-3 text-[11px] font-semibold tracking-[0.12em] text-dim uppercase">
					Next to air on your list
				</div>
				<div class="mt-2 flex items-center gap-3">
					<a
						href="/title/{caughtUp.id}"
						class="flex min-w-0 flex-1 items-center gap-3 text-ink hover:text-ink"
					>
						{@render cover(caughtUp)}
						<div class="flex min-w-0 flex-col gap-0.5">
							<span class="line-clamp-2 text-[15px] font-semibold">{caughtUp.title.title}</span>
							{#if next}
								<span class="font-mono text-xs text-muted tabular-nums"
									>EP {next.ep} in {countdown(caughtUp)}</span
								>
							{/if}
						</div>
					</a>
					<a
						href="/schedule"
						class="flex h-11 flex-none items-center gap-1.5 rounded-[2px] border border-line px-3 text-sm font-semibold text-ink hover:text-ink"
					>
						<span class="material-symbols-rounded !text-[18px]" aria-hidden="true"
							>calendar_month</span
						>
						Schedule
					</a>
				</div>
			</div>
			{#if visible.length}
				<div class="px-4 pt-4 pb-1 text-[11px] font-semibold tracking-[0.12em] text-dim uppercase">
					Also on its way
				</div>
			{/if}
		{/if}

		<ul class="m-0 mt-2 list-none p-0 md:grid md:grid-cols-2 md:gap-x-8 md:px-4">
			{#each visible as item, i (item.id)}
				{#if i === firstWaiting(visible)}
					<li
						class="px-4 pt-4 pb-1 text-[11px] font-semibold tracking-[0.12em] text-dim uppercase md:col-span-2 md:px-0"
					>
						{waitingLabel}
					</li>
				{/if}
				{@render touchRow(item)}
			{/each}
		</ul>

		{#if items.length > SHOWN}{@render showAll('mx-4 mt-2')}{/if}
		{#if upNext.length}
			<div class="px-4 pt-4 pb-1 text-[11px] font-semibold tracking-[0.12em] text-dim uppercase">
				Up next
			</div>
			<ul class="m-0 list-none p-0 md:grid md:grid-cols-2 md:gap-x-8 md:px-4">
				{#each upNext as item (item.id)}
					{@render touchRow(item)}
				{/each}
			</ul>
		{/if}
		{#if paused.length}{@render pausedLine('px-4 py-3')}{/if}
	</div>

	<!-- ── desktop: editorial — the lead, ruled rows, and the schedule beside them ── -->
	<div class="hidden flex-col gap-5 lg:flex">
		<SectionHeading
			heading={title}
			level="h2"
			jp={isAnime ? '視聴中' : '読書中'}
			subtitle={summary}
			subtitleColor={summaryFresh ? 'var(--color-green)' : 'var(--color-dim)'}
			subtitleTestId="continue-summary-wide"
			end={myList}
		/>

		{#if caughtUp}
			{@const next = caughtUp.title.next}
			<!-- nothing ready: a ruled line says so and when the next one airs -->
			<div class="flex items-center gap-5 border-y border-line py-4" data-testid="caught-up">
				<span class="flex-none font-display text-2xl italic">You're caught up.</span>
				<a
					href="/title/{caughtUp.id}"
					class="flex min-w-0 flex-1 items-center gap-3 text-ink hover:text-ink"
				>
					<span
						class="relative aspect-2/3 w-8 flex-none overflow-hidden"
						style="background:{caughtUp.title.placeholder}"
					>
						<CoverImage title={caughtUp.title} thumb />
					</span>
					<span class="min-w-0 truncate text-sm">
						<span class="text-muted">Next to air:</span>
						<span class="font-semibold">{caughtUp.title.title}</span>
					</span>
				</a>
				{#if next}
					<span class="flex-none font-mono text-[13px] text-muted tabular-nums"
						>EP {next.ep} in {countdown(caughtUp)}</span
					>
				{/if}
				<a
					href="/schedule"
					class="flex h-9 flex-none items-center gap-1.5 rounded-[2px] border border-line px-3 text-sm font-semibold text-ink hover:border-ink hover:text-ink"
				>
					<span class="material-symbols-rounded !text-[18px]" aria-hidden="true"
						>calendar_month</span
					>
					Schedule
				</a>
			</div>
		{/if}

		{#if hasQueue}
			<!-- the schedule column only when something on your list has a date (manga rarely does) -->
			<div
				class="grid gap-12 xl:gap-14 {schedule.length
					? 'grid-cols-[minmax(0,1fr)_260px]'
					: 'grid-cols-1'}"
			>
				<div class="flex min-w-0 flex-col">
					{#if lead}
						{@const total = lead.title.total}
						{@const behind = fresh(lead)}
						<!-- the lead: furthest behind, large, with a +1 that says where it lands -->
						<article
							class="grid grid-cols-[170px_minmax(0,1fr)] gap-9 border-b border-line pt-2 pb-8"
							data-testid="continue-row"
						>
							<a
								href="/title/{lead.id}"
								class="relative aspect-2/3 w-[170px] self-start"
								aria-label="Open {lead.title.title}"
							>
								<span
									class="absolute inset-0 overflow-hidden"
									style="background:{lead.title
										.placeholder};box-shadow:10px 10px 0 color-mix(in oklch, {lead.title
										.accent} 50%, var(--color-canvas))"
								>
									<CoverImage title={lead.title} />
								</span>
							</a>
							<div class="flex min-w-0 flex-col">
								<div
									class="text-[11px] font-semibold tracking-[0.14em] uppercase"
									style="color:{lead.title.accent}"
								>
									{behind > 1 ? 'Furthest behind' : 'Pick up where you left off'}
								</div>
								<a
									href="/title/{lead.id}"
									class="mt-2.5 line-clamp-2 font-display text-[40px] leading-[0.98] font-semibold tracking-[-0.03em] text-balance text-ink hover:text-ink"
									>{lead.title.title}</a
								>
								{#if lead.title.synopsis}
									<p
										class="m-0 mt-3 line-clamp-2 max-w-[68ch] text-[14px] leading-relaxed text-muted"
									>
										{lead.title.synopsis}
									</p>
								{/if}
								<div class="mt-3 flex flex-wrap items-baseline gap-x-3 gap-y-1">
									<span class="text-sm font-semibold tabular-nums" style="color:{lead.subColor}"
										>{lead.sub}</span
									>
									{#if aside(lead)}
										{@const extra = aside(lead)!}
										<span
											class="font-mono text-xs tabular-nums"
											style="color:{extra.color}"
											data-testid="continue-aside">{extra.text}</span
										>
									{/if}
								</div>
								<div class="mt-5 flex flex-wrap items-center gap-x-6 gap-y-3">
									{#if atTotal(lead)}
										{@render action(lead, 'h-11 w-11')}
									{:else}
										<!-- a tally counter: where you are, and the number +1 lands on -->
										<div class="inline-flex items-stretch border border-ink">
											<span
												class="flex items-baseline gap-1.5 px-4 py-2 font-mono text-xl tabular-nums"
												><Tick value={lead.progress} /><span class="text-xs text-dim"
													>/ {total ?? '?'}</span
												></span
											>
											<button
												type="button"
												onclick={() => plusOne(lead.title)}
												aria-label="Add one {isAnime ? 'episode' : 'chapter'} to {lead.title.title}"
												class="press bg-ink px-4 text-sm font-bold text-canvas transition-colors hover:bg-muted"
											>
												+1 → <Tick value={lead.progress + 1} />
											</button>
										</div>
									{/if}
									{#if lead.title.genres.length}
										<span class="text-[13px] text-dim"
											>{lead.title.genres.slice(0, 3).join(' / ')}</span
										>
									{/if}
								</div>
								{@render bar(lead, 'mt-5 h-1 max-w-[520px]')}
							</div>
						</article>
					{/if}

					{#if queue.length}
						<!-- two columns on wide screens, so a row isn't a short title across the page -->
						<ul class="m-0 list-none p-0 xl:grid xl:grid-cols-2 xl:gap-x-12">
							{#each queue as item (item.id)}
								<li
									class="group grid grid-cols-[44px_minmax(0,1fr)_auto] items-center gap-4 border-b border-line py-3"
									style="--hover:{item.title.accent}"
									data-testid="continue-row"
								>
									<a href="/title/{item.id}" class="text-ink hover:text-ink" tabindex="-1">
										{@render cover(item)}
									</a>
									<a
										href="/title/{item.id}"
										class="flex min-w-0 flex-col gap-1 text-ink hover:text-ink"
									>
										{@render titleLine(item, 'text-[15px] group-hover:text-[var(--hover)]')}
										<span
											class="truncate text-xs font-medium tabular-nums"
											style="color:{item.subColor}">{wideSub(item)}</span
										>
										{@render bar(item, 'h-[3px]')}
									</a>
									{@render action(item, 'h-9 w-9')}
								</li>
							{/each}
						</ul>
					{/if}
					{#if paused.length}
						{@render pausedLine('border-b border-line py-3 hover:bg-raised')}
					{/if}
					{#if items.length > SHOWN_WIDE}
						<div class="py-3">{@render showAll('')}</div>
					{/if}
				</div>

				{#if schedule.length}
					<!-- when the next episodes on your list air, on a time rule -->
					<aside
						class="sticky top-24 self-start border-l border-line pl-7"
						aria-label="Airing next on your list"
					>
						<div class="font-display text-xl tracking-[-0.01em]">Airing next</div>
						<div class="mt-0.5 text-xs text-dim">On your list · your time</div>
						{#if schedule.length}
							<ol class="m-0 mt-4 list-none p-0">
								{#each schedule as item (item.id)}
									{@const at = item.title.next!.at!}
									<li class="grid grid-cols-[64px_minmax(0,1fr)] gap-3 py-2">
										<span class="font-mono text-[11px] leading-tight text-dim tabular-nums"
											>{airDay(at)}<br />{clockTime(at)}</span
										>
										<a
											href="/title/{item.id}"
											class="min-w-0 text-[13px] leading-snug font-semibold text-ink hover:text-ink"
										>
											<span class="line-clamp-2">{item.title.title}</span>
											<span class="font-mono text-[11px] font-normal text-dim"
												>{item.title.unit} {item.title.next!.ep}</span
											>
										</a>
									</li>
								{/each}
							</ol>
							<a href="/schedule" class="mt-3 inline-block text-[13px] text-muted hover:text-ink"
								>Full schedule →</a
							>
						{/if}
					</aside>
				{/if}
			</div>
		{/if}
	</div>
</section>
