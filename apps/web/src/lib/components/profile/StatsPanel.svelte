<script lang="ts">
	import { STATUS_COLOR } from '#lib/catalog/status.ts';
	import SectionError from '#lib/components/home/SectionError.svelte';
	import Skeleton from '#lib/components/shared/Skeleton.svelte';
	import {
		rangeLabel,
		STATS_RANGES,
		type HeatCell,
		type Stats,
		type StatsRange,
		type Tone
	} from '#lib/page-data/stats.ts';
	import { session } from '#lib/state/session.svelte.ts';

	// A profile's Stats, yours or someone else's, built from their
	// list by the page (buildStats), with the Anime / Manga switch and the time
	// range in the heading. One accent per chart, neutral greys for the rest;
	// status colours only where status is the data. Every bar is labelled.

	interface Props {
		stats: Stats | null;
		heatmap: (HeatCell | null)[][] | null;
		/** List updates in the heatmap's 26 weeks, for its label. */
		historyTotal: number;
		historyFailed: boolean;
		onRetryHistory: () => void;
		loading: boolean;
		failed: boolean;
		error?: string;
		retryIn?: string;
		rateLimited?: boolean;
		onRetry: () => void;
		range: StatsRange;
		onRange: (range: StatsRange) => void;
		isAnime: boolean;
		now: Date;
		/** "your" / "matchai's". */
		whose: string;
		/** Your own profile: offers to rate titles, and to browse when the list is empty. */
		own: boolean;
		/** "matchai keeps their list private": shown instead of the stats. */
		privateList?: string | null;
	}

	let {
		stats,
		heatmap,
		historyTotal,
		historyFailed,
		onRetryHistory,
		loading,
		failed,
		error,
		retryIn,
		rateLimited,
		onRetry,
		range,
		onRange,
		isAnime,
		now,
		whose,
		own,
		privateList = null
	}: Props = $props();

	// ── Colours ──
	const accent = $derived(isAnime ? '#FF6A55' : '#A08CFF');
	const accentText = $derived(isAnime ? '#FF8A78' : '#B9A9FF');
	const accentRgb = $derived(isAnime ? '255,106,85' : '160,140,255');

	function tone(t: Tone): string {
		switch (t) {
			case 'accent':
				return accent;
			case 'accent-soft':
				return `rgba(${accentRgb},${isAnime ? 0.45 : 0.5})`;
			case 'ink':
				return '#EEF0F6';
			case 'dim':
				return 'var(--color-dim)';
			case 'mute':
				return '#3A4054';
		}
	}

	const heatLevels = $derived([
		'var(--color-raised)',
		`rgba(${accentRgb},.25)`,
		`rgba(${accentRgb},.5)`,
		`rgba(${accentRgb},.75)`,
		accent
	]);

	/** Format slices as a conic gradient, with a hairline gap between them. */
	const donut = $derived.by(() => {
		if (!stats?.total) return 'var(--color-raised)';
		let at = 0;
		const parts = stats.formats.map((f) => {
			const from = at;
			at += f.share * 360;
			const gap = stats.formats.length > 1 ? 1.5 : 0;
			return `${tone(f.tone)} ${from}deg ${at - gap}deg, var(--color-canvas) ${at - gap}deg ${at}deg`;
		});
		return `conic-gradient(${parts.join(',')})`;
	});

	const maxScore = $derived(Math.max(1, ...(stats?.scores.map((b) => b.count) ?? [])));
	const maxMonth = $derived(Math.max(1, ...(stats?.months.map((m) => m.count) ?? [])));

	const unit = $derived(isAnime ? 'episodes' : 'chapters');
</script>

<div class="min-w-0">
	<!-- header -->
	<div class="flex items-center gap-3 lg:gap-4">
		<h2
			class="m-0 flex-1 font-display text-[24px] leading-tight font-medium tracking-[-0.02em] lg:text-[26px]"
		>
			Stats
		</h2>
		<div class="hidden gap-4 lg:inline-flex" role="radiogroup" aria-label="Mode">
			{#each [['anime', 'Anime'], ['manga', 'Manga']] as const as [m, label] (m)}
				{@const on = session.mode === m}
				<button
					type="button"
					role="radio"
					aria-checked={on}
					onclick={() => session.setMode(m)}
					class="h-9.5 text-sm {on ? 'font-semibold' : 'font-medium'}"
					style="color:{on ? 'var(--color-ink)' : 'var(--color-muted)'};box-shadow:{on
						? `inset 0 -2px 0 ${m === 'anime' ? 'var(--color-anime)' : 'var(--color-manga)'}`
						: 'none'}">{label}</button
				>
			{/each}
		</div>
		<label class="relative flex h-11 items-center field-line pr-1 pl-0.5 text-sm">
			<span class="sr-only">Time range</span>
			<select
				value={range}
				onchange={(e) => onRange(e.currentTarget.value as StatsRange)}
				class="h-9 appearance-none border-0 bg-transparent bg-none py-0 pr-7 pl-0 text-sm text-ink outline-none focus:ring-0"
			>
				{#each STATS_RANGES as r (r)}
					<option value={r}>{rangeLabel(r, now)}</option>
				{/each}
			</select>
			<span
				class="material-symbols-rounded pointer-events-none absolute right-2.5 !text-[20px] text-dim"
				aria-hidden="true">expand_more</span
			>
		</label>
	</div>

	<div class="flex flex-col gap-3 pt-4 lg:gap-5">
		{#if privateList}
			<div
				class="flex flex-col items-center gap-3 rounded-[2px] border border-dashed border-line px-6 py-14 text-center"
				data-testid="private-list"
			>
				<span class="material-symbols-rounded !text-[36px] text-dim" aria-hidden="true"
					>visibility_off</span
				>
				<h2
					class="m-0 font-display text-[24px] leading-tight font-medium tracking-[-0.02em] lg:text-[26px]"
				>
					{privateList}
				</h2>
				<p class="m-0 max-w-sm text-sm text-muted">
					Their stats come from their list, so there's nothing to show here.
				</p>
			</div>
		{:else if failed}
			<SectionError
				title="Couldn't load {whose} stats"
				{onRetry}
				detail={error}
				{retryIn}
				{rateLimited}
			/>
		{:else if loading || !stats}
			<div class="flex flex-col gap-3 lg:gap-5" aria-busy="true" aria-label="Loading {whose} stats">
				<div class="grid grid-cols-2 gap-2.5 md:grid-cols-4 lg:gap-5">
					{#each { length: 4 } as _, i (i)}
						<Skeleton class="h-[76px] rounded-[2px] lg:h-[136px] lg:rounded-[2px]" />
					{/each}
				</div>
				<div class="grid gap-3 lg:gap-5 2xl:grid-cols-[1.3fr_1fr]">
					<Skeleton class="h-[200px] rounded-[2px] lg:h-[340px]" />
					<Skeleton class="h-[200px] rounded-[2px] lg:h-[340px]" />
				</div>
			</div>
		{:else if stats.total === 0}
			<div
				class="flex flex-col items-center gap-3 rounded-[2px] border border-dashed border-line px-6 py-14 text-center"
			>
				<span class="material-symbols-rounded !text-[36px] text-dim" aria-hidden="true"
					>bar_chart</span
				>
				<h2
					class="m-0 font-display text-[24px] leading-tight font-medium tracking-[-0.02em] lg:text-[26px]"
				>
					{range === 'all'
						? `No ${isAnime ? 'anime' : 'manga'} on ${whose} list yet`
						: `Nothing started or finished in ${rangeLabel(range, now).replace('Last', 'the last')}`}
				</h2>
				<p class="m-0 max-w-sm text-sm text-muted">
					{range !== 'all'
						? 'Try a longer time range.'
						: own
							? 'Add a few titles and your stats will show up here.'
							: 'Nothing here yet.'}
				</p>
				{#if range === 'all' && own}
					<a
						href="/browse"
						class="mt-1 flex h-11 items-center btn-quiet px-4 text-sm font-semibold hover:text-ink"
						>Browse {isAnime ? 'anime' : 'manga'}</a
					>
				{:else if range !== 'all'}
					<button
						type="button"
						onclick={() => onRange('all')}
						class="mt-1 flex h-11 items-center btn-quiet px-4 text-sm font-semibold"
						>Show all time</button
					>
				{/if}
			</div>
		{:else}
			<!-- headline numbers -->
			<div class="grid grid-cols-2 gap-2.5 md:grid-cols-4 lg:gap-5" data-testid="stat-cards">
				{#each stats.cards as c (c.label)}
					<div class="flex flex-col gap-1.5 border-t border-ink pt-3.5 lg:gap-2.5 lg:pt-4">
						<div class="flex items-center gap-2 text-xs text-muted lg:text-[13px]">
							<span class="hidden lg:contents" aria-hidden="true"
								><span class="material-symbols-rounded !text-[18px]" style="color:{accentText}"
									>{c.icon}</span
								></span
							>{c.label}
						</div>
						<div
							class="font-display text-[34px] leading-none font-light tracking-[-0.045em] lg:text-[56px]"
						>
							{c.value}
						</div>
						{#if c.detail}
							<div
								class="hidden text-xs lg:block"
								style="color:{c.positive ? 'var(--color-green)' : 'var(--color-dim)'}"
							>
								{c.detail}
							</div>
						{/if}
					</div>
				{/each}
			</div>

			<div class="grid gap-3 lg:gap-5 2xl:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)]">
				<!-- score distribution -->
				<section class="flex min-w-0 flex-col gap-3 border-t border-ink pt-4 lg:gap-4 lg:pt-5">
					<div class="flex items-baseline justify-between gap-3">
						<h2 class="m-0 font-display text-[19px] font-medium tracking-[-0.01em] lg:text-[22px]">
							Score distribution
						</h2>
						<div class="text-xs text-muted lg:text-[13px]">
							{#if stats.mean !== null}
								Mean <b class="font-mono font-medium text-ink">{stats.mean.toFixed(1)}</b>
								· σ {stats.deviation?.toFixed(1)}
							{:else}
								Nothing scored yet
							{/if}
						</div>
					</div>
					<div>
						<div
							class="grid h-[120px] grid-cols-10 items-end gap-1.5 pt-5 lg:h-60 lg:gap-2.5 lg:bg-[repeating-linear-gradient(0deg,rgba(255,255,255,.06)_0_1px,transparent_1px_60px)]"
							role="list"
							aria-label="Titles per score, 1 to 10"
						>
							{#each stats.scores as b, i (b.score)}
								<div
									class="group relative flex h-full flex-col items-center justify-end gap-1.5"
									role="listitem"
									aria-label="{b.count} {b.count === 1 ? 'title' : 'titles'} scored {b.score}"
								>
									<div
										class="hidden font-mono text-xs font-medium text-dim group-hover:text-ink lg:block"
									>
										{b.count}
									</div>
									<div
										class="w-full grow-y transition-[height,background] duration-300 ease-enter group-hover:!bg-ink"
										style="--d:{i * 35}ms;height:{b.count
											? Math.max(2, Math.round((b.count / maxScore) * 100))
											: 1}%;background:{tone(b.tone)}"
									></div>
									<div
										class="pointer-events-none absolute -top-2 left-1/2 z-10 hidden -translate-x-1/2 -translate-y-full rounded-[2px] border border-line bg-raised-hover px-2.5 py-1.5 text-xs whitespace-nowrap shadow-lg group-hover:block"
									>
										<b class="font-mono">{b.count}</b>
										{b.count === 1 ? 'title' : 'titles'} scored {b.score}
									</div>
								</div>
							{/each}
						</div>
						<div class="mt-2 grid grid-cols-10 gap-1.5 lg:gap-2.5" aria-hidden="true">
							{#each stats.scores as b (b.score)}
								<div class="text-center font-mono text-[11px] font-medium text-dim lg:text-xs">
									{b.score}
								</div>
							{/each}
						</div>
					</div>
					<!-- most of the list unscored: the stats (and For You) need ratings -->
					{#if own && stats.total - stats.scored >= 10 && stats.scored < stats.total / 2}
						<a
							href="/list?tab=completed&sort=updated"
							class="-mx-1 flex items-center gap-2 rounded-[2px] px-1 py-1 text-[13px] text-muted hover:text-muted"
							data-testid="rate-prompt"
						>
							<span
								class="material-symbols-rounded !text-[18px]"
								style="color:var(--color-gold)"
								aria-hidden="true">star</span
							>
							<span class="flex-1">
								{stats.total - stats.scored} titles have no score yet. Rating them sharpens your stats
								and For You.
							</span>
							<span class="font-semibold" style="color:{accentText}">Rate them →</span>
						</a>
					{/if}
				</section>

				<!-- format + status -->
				<section class="flex min-w-0 flex-col gap-3 border-t border-ink pt-4 lg:gap-4 lg:pt-5">
					<h2 class="m-0 font-display text-[19px] font-medium tracking-[-0.01em] lg:text-[22px]">
						Format
					</h2>
					<div class="flex items-center gap-5 lg:gap-7">
						<div
							class="relative h-32 w-32 flex-none rounded-full lg:h-45 lg:w-45"
							style="background:{donut}"
							aria-hidden="true"
						>
							<div
								class="absolute inset-5 flex flex-col items-center justify-center rounded-full bg-raised lg:inset-7"
							>
								<div
									class="font-display text-2xl leading-none font-light tracking-[-0.03em] lg:text-[34px]"
								>
									{stats.total}
								</div>
								<div class="text-xs text-dim">titles</div>
							</div>
						</div>
						<ul class="m-0 flex min-w-0 flex-1 list-none flex-col gap-3 p-0">
							{#each stats.formats as f (f.label)}
								<li class="flex items-center gap-2.5 text-sm">
									<span
										class="h-2.5 w-2.5 flex-none rounded-[3px]"
										style="background:{tone(f.tone)}"
										aria-hidden="true"
									></span>
									<span class="min-w-0 flex-1 truncate text-[#DDD3C3]">{f.label}</span>
									<span class="font-mono text-[13px] font-medium text-muted">{f.count}</span>
									<span class="w-11 text-right font-mono text-xs font-medium text-dim"
										>{Math.round(f.share * 100)}%</span
									>
								</li>
							{/each}
						</ul>
					</div>
					<div class="flex flex-col gap-2 border-t border-line pt-3.5">
						<div class="text-[13px] text-muted">By status</div>
						<div class="flex h-3 gap-0.5 overflow-hidden rounded-[2px]" aria-hidden="true">
							{#each stats.statuses as s (s.status)}
								<div
									class="h-full"
									style="flex:{s.count};background:{STATUS_COLOR[s.status]}"
								></div>
							{/each}
						</div>
						<ul class="m-0 flex list-none flex-wrap gap-x-3.5 gap-y-1.5 p-0">
							{#each stats.statuses as s (s.status)}
								<li class="flex items-center gap-1.5 text-xs text-muted">
									<span
										class="h-2 w-2 rounded-full"
										style="background:{STATUS_COLOR[s.status]}"
										aria-hidden="true"
									></span>
									{s.label}
									<span class="font-mono text-ink">{s.count}</span>
								</li>
							{/each}
						</ul>
					</div>
				</section>
			</div>

			<div class="grid gap-3 lg:gap-5 2xl:grid-cols-[minmax(0,1fr)_minmax(0,1.3fr)]">
				<!-- top genres -->
				<section class="flex min-w-0 flex-col gap-3 border-t border-ink pt-4 lg:gap-4 lg:pt-5">
					<div class="flex items-baseline justify-between gap-3">
						<h2 class="m-0 font-display text-[19px] font-medium tracking-[-0.01em] lg:text-[22px]">
							Top genres
						</h2>
						<div class="hidden text-xs text-dim lg:block">count · mean score</div>
					</div>
					<ul class="m-0 flex list-none flex-col gap-3 p-0 lg:gap-3.5">
						{#each stats.genres as g (g.genre)}
							<li
								class="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-x-3 gap-y-1.5 lg:grid-cols-[110px_minmax(0,1fr)_40px_40px]"
							>
								<div class="truncate text-[13px] text-[#DDD3C3] lg:text-sm">{g.genre}</div>
								<div
									class="col-span-2 row-start-2 h-1.5 rounded-[3px] bg-white/5 lg:col-span-1 lg:row-start-auto lg:h-2.5 lg:rounded-[2px]"
									aria-hidden="true"
								>
									<div
										class="h-full rounded-[inherit]"
										style="width:{Math.round(g.width * 100)}%;background:{tone(g.tone)}"
									></div>
								</div>
								<div class="text-right font-mono text-[13px] font-medium text-muted lg:text-ink">
									{g.count}<span class="sr-only"> titles</span>
								</div>
								<div class="hidden text-right font-mono text-xs font-medium text-muted lg:block">
									<span class="sr-only">mean score </span>{g.mean === null
										? '—'
										: g.mean.toFixed(1)}
								</div>
							</li>
						{/each}
					</ul>
				</section>

				<!-- activity -->
				<section class="flex min-w-0 flex-col gap-3 border-t border-ink pt-4 lg:gap-4 lg:pt-5">
					<div class="flex items-baseline justify-between gap-3">
						<h2 class="m-0 font-display text-[19px] font-medium tracking-[-0.01em] lg:text-[22px]">
							Finished · last 12 months
						</h2>
						<div class="text-xs text-muted lg:text-[13px]">Titles per month</div>
					</div>
					<div>
						<div
							class="grid h-40 grid-cols-12 items-end gap-1.5 bg-[repeating-linear-gradient(0deg,rgba(255,255,255,.06)_0_1px,transparent_1px_50px)] lg:h-50 lg:gap-2"
							role="list"
							aria-label="Titles finished per month"
						>
							{#each stats.months as m, i (m.name)}
								<div
									class="group relative flex h-full flex-col items-center justify-end gap-1.5"
									role="listitem"
									aria-label="{m.count} finished in {m.name}"
								>
									<div
										class="font-mono text-[11px] font-medium group-hover:!text-ink"
										style="color:{m.tone === 'accent' ? accentText : 'var(--color-dim)'}"
									>
										{m.count}
									</div>
									<div
										class="w-full grow-y group-hover:!bg-ink"
										style="--d:{i * 30}ms;height:{m.count
											? Math.round((m.count / maxMonth) * 85)
											: 1}%;background:{tone(m.tone)}"
									></div>
									<div
										class="pointer-events-none absolute -top-2 left-1/2 z-10 hidden -translate-x-1/2 -translate-y-full rounded-[2px] border border-line bg-raised-hover px-2.5 py-1.5 text-xs whitespace-nowrap shadow-lg group-hover:block"
									>
										<b class="font-mono">{m.count}</b> finished in {m.name}
									</div>
								</div>
							{/each}
						</div>
						<div class="mt-1.5 grid grid-cols-12 gap-1.5 lg:gap-2" aria-hidden="true">
							{#each stats.months as m (m.name)}
								<div class="text-center font-mono text-[11px] font-medium text-dim">
									{m.label}
								</div>
							{/each}
						</div>
					</div>
					<div class="flex flex-col gap-2 border-t border-line pt-3">
						<div class="flex items-baseline justify-between gap-3">
							<div class="text-[13px] text-muted">Daily activity · last 26 weeks</div>
							<div class="text-xs text-dim">anime and manga</div>
						</div>
						{#if heatmap}
							<div
								class="grid grid-flow-col grid-cols-[repeat(26,minmax(0,1fr))] grid-rows-[repeat(7,8px)] gap-[2px] lg:grid-rows-[repeat(7,10px)] lg:gap-[3px]"
								data-testid="heatmap"
								role="img"
								aria-label="{historyTotal} list updates in the last 26 weeks"
							>
								{#each heatmap as week, w (w)}
									{#each week as cell, d (d)}
										<div
											class="rounded-[2px]"
											style="background:{cell ? heatLevels[cell.level] : 'transparent'}"
											title={cell
												? `${cell.amount} ${cell.amount === 1 ? 'update' : 'updates'} on ${cell.date}`
												: undefined}
										></div>
									{/each}
								{/each}
							</div>
						{:else if historyFailed}
							<div class="text-xs text-dim">
								Couldn't load {whose} activity.
								<button type="button" class="text-anime-soft underline" onclick={onRetryHistory}
									>Try again</button
								>
							</div>
						{:else}
							<Skeleton class="h-[74px] lg:h-[88px]" />
						{/if}
					</div>
				</section>
			</div>

			<p class="m-0 text-xs text-dim">
				{#if range === 'all'}
					Every title on {whose} {isAnime ? 'anime' : 'manga'} list. Rewatches count in full.
				{:else}
					Titles {own ? 'you' : 'they'} started or finished in {rangeLabel(range, now).replace(
						'Last',
						'the last'
					)}. Their {unit} count in full.
				{/if}
				Scores are shown out of 10.
			</p>
		{/if}
	</div>
</div>
