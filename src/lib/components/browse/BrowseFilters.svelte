<script lang="ts">
	import type { AniListTag } from '#lib/anilist/types.ts';
	import {
		ANIME_FORMATS,
		COUNTRIES,
		MANGA_FORMATS,
		SCORE_MAX,
		SEASONS,
		SORTS,
		STATUSES,
		type BrowseState
	} from '#lib/browse/params.ts';

	interface Props {
		state: BrowseState;
		isAnime: boolean;
		/** Hide-on-list needs an account. */
		signedIn: boolean;
		genres: string[];
		tags: AniListTag[];
		onChange: (patch: Partial<BrowseState>) => void;
		/** The mobile sheet puts Sort here; desktop has it above the results. */
		showSort?: boolean;
		/** Keeps ids unique when the rail and the sheet are both in the DOM. */
		idPrefix: string;
	}

	let {
		state: filters,
		isAnime,
		signedIn,
		genres,
		tags,
		onChange,
		showSort = false,
		idPrefix
	}: Props = $props();

	const accent = $derived(isAnime ? 'var(--color-anime)' : 'var(--color-manga)');
	const accentInk = $derived(isAnime ? 'var(--color-anime-ink)' : 'var(--color-manga-ink)');
	const chipBg = $derived(isAnime ? 'rgba(255,106,85,.14)' : 'rgba(160,140,255,.16)');
	const chipBorder = $derived(
		isAnime ? '1px solid rgba(255,106,85,.4)' : '1px solid rgba(160,140,255,.45)'
	);
	const chipFg = $derived(isAnime ? '#FFB3A6' : '#CFC4FF');
	const formats = $derived(isAnime ? ANIME_FORMATS : MANGA_FORMATS);

	const thisYear = new Date().getFullYear();
	const years = Array.from({ length: thisYear + 2 - 1960 }, (_, i) => thisYear + 1 - i);

	function toggle(list: string[], value: string): string[] {
		return list.includes(value) ? list.filter((v) => v !== value) : [...list, value];
	}

	/** A genre goes in, then out (excluded), then back to neither. */
	function cycleGenre(g: string) {
		const without = (list: string[]) => list.filter((v) => v !== g);
		if (filters.genres.includes(g)) {
			onChange({ genres: without(filters.genres), notGenres: [...filters.notGenres, g] });
		} else if (filters.notGenres.includes(g)) {
			onChange({ notGenres: without(filters.notGenres) });
		} else {
			onChange({ genres: [...filters.genres, g] });
		}
	}

	// ── Tags: a search box over AniList's ~400 tags ──
	let tagQuery = $state('');
	const tagMatches = $derived.by(() => {
		const q = tagQuery.trim().toLowerCase();
		if (!q) return [];
		return tags
			.filter(
				(t) =>
					!filters.tags.includes(t.name) &&
					!filters.notTags.includes(t.name) &&
					t.name.toLowerCase().includes(q)
			)
			.sort(
				(a, b) =>
					Number(!a.name.toLowerCase().startsWith(q)) - Number(!b.name.toLowerCase().startsWith(q))
			)
			.slice(0, 8);
	});

	function addTag(name: string, exclude = false) {
		onChange(exclude ? { notTags: [...filters.notTags, name] } : { tags: [...filters.tags, name] });
		tagQuery = '';
	}

	function onTagKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter' && tagMatches[0]) {
			e.preventDefault();
			addTag(tagMatches[0].name);
		} else if (e.key === 'Escape') {
			tagQuery = '';
		}
	}

	// ── Score: shown live while dragging, applied on release ──
	let scoreMin = $derived(filters.scoreMin);
	let scoreMax = $derived(filters.scoreMax);
	const scoreLabel = $derived(
		scoreMin === 0 && scoreMax === SCORE_MAX
			? 'Any'
			: `${scoreMin.toFixed(1)} – ${scoreMax === SCORE_MAX ? '10' : scoreMax.toFixed(1)}`
	);

	function commitScore() {
		if (scoreMin !== filters.scoreMin || scoreMax !== filters.scoreMax) {
			onChange({ scoreMin, scoreMax });
		}
	}
</script>

{#snippet heading(text: string, id: string, count = 0)}
	<div class="text-[11px] font-semibold tracking-wider text-dim uppercase" {id}>
		{text}{count ? ` · ${count}` : ''}
	</div>
{/snippet}

<div class="flex flex-col gap-6">
	{#if showSort}
		<div class="flex flex-col gap-2.5">
			{@render heading('Sort', `${idPrefix}-sort`)}
			<div
				class="flex flex-wrap gap-x-5 gap-y-1"
				role="radiogroup"
				aria-labelledby="{idPrefix}-sort"
			>
				{#each SORTS as s (s.key)}
					{@const on = filters.sort === s.key}
					<button
						type="button"
						role="radio"
						aria-checked={on}
						onclick={() => onChange({ sort: s.key })}
						class="h-10 press px-1 text-sm {on
							? 'font-semibold text-ink shadow-[inset_0_-2px_0_var(--color-anime)]'
							: 'text-muted hover:text-ink'}"
					>
						{s.label}
					</button>
				{/each}
			</div>
		</div>
	{/if}

	<!-- no genres yet (AniList busy): no heading over nothing -->
	{#if genres.length}
		<div class="flex flex-col gap-2.5">
			<div class="flex items-baseline justify-between gap-2">
				{@render heading(
					'Genres',
					`${idPrefix}-genres`,
					filters.genres.length + filters.notGenres.length
				)}
				<span class="text-[11px] text-dim">Tap twice to exclude</span>
			</div>
			<div class="flex flex-wrap gap-1.5" role="group" aria-labelledby="{idPrefix}-genres">
				{#each genres as g (g)}
					{@const on = filters.genres.includes(g)}
					{@const out = filters.notGenres.includes(g)}
					<button
						type="button"
						aria-pressed={on}
						aria-label={out ? `${g}, excluded` : undefined}
						onclick={() => cycleGenre(g)}
						class="touch-target relative flex h-8 press items-center gap-0.5 rounded-[2px] px-3 text-[13px] transition-colors"
						style="font-weight:{on ? 600 : 500};background:{on
							? chipBg
							: out
								? 'transparent'
								: 'var(--color-raised)'};border:{on
							? chipBorder
							: out
								? '1px dashed rgb(255 255 255 / 0.28)'
								: '1px solid rgb(255 255 255 / 0.08)'};color:{on
							? chipFg
							: out
								? 'var(--color-dim)'
								: 'var(--color-muted)'}"
					>
						{#if out}<span class="material-symbols-rounded -ml-1 !text-[15px]" aria-hidden="true"
								>block</span
							>{/if}
						<span class={out ? 'line-through' : ''}>{g}</span>
					</button>
				{/each}
			</div>
		</div>
	{/if}

	<div class="flex flex-col gap-2.5">
		{@render heading('Tags', `${idPrefix}-tags`, filters.tags.length + filters.notTags.length)}
		<div class="relative">
			<div class="flex h-10 items-center gap-2 field-line px-0.5 text-sm">
				<span class="material-symbols-rounded !text-[18px] text-dim" aria-hidden="true">sell</span>
				<input
					bind:value={tagQuery}
					onkeydown={onTagKeydown}
					placeholder="Search {tags.length > 100
						? `${Math.floor(tags.length / 100) * 100}+ `
						: ''}tags…"
					aria-labelledby="{idPrefix}-tags"
					class="min-w-0 flex-1 border-0 bg-transparent p-0 text-sm text-ink outline-none placeholder:text-dim"
				/>
			</div>
			{#if tagMatches.length}
				<div
					class="absolute inset-x-0 top-11 z-20 flex max-h-72 flex-col overflow-y-auto layer p-1"
				>
					{#each tagMatches as t (t.name)}
						<div class="flex items-center gap-1 rounded-[2px] hover:bg-white/5">
							<button
								type="button"
								onclick={() => addTag(t.name)}
								class="flex min-w-0 flex-1 items-baseline justify-between gap-2 px-2.5 py-2 text-left text-sm"
							>
								<span>{t.name}</span>
								<span class="truncate text-[11px] text-dim">{t.category}</span>
							</button>
							<button
								type="button"
								onclick={() => addTag(t.name, true)}
								aria-label="Exclude tag {t.name}"
								title="Exclude"
								class="grid h-8 w-8 flex-none place-items-center rounded-[2px] text-dim hover:bg-white/5 hover:text-ink"
							>
								<span class="material-symbols-rounded !text-[18px]" aria-hidden="true">block</span>
							</button>
						</div>
					{/each}
				</div>
			{/if}
		</div>
		{#if filters.tags.length || filters.notTags.length}
			<div class="flex flex-wrap gap-1.5">
				{#each filters.tags as t (t)}
					<button
						type="button"
						onclick={() => onChange({ tags: filters.tags.filter((x) => x !== t) })}
						aria-label="Remove tag {t}"
						class="flex h-7 items-center gap-0.5 rounded-[2px] bg-raised-hover pr-1.5 pl-2.5 text-xs text-[#DDD3C3]"
					>
						{t}
						<span class="material-symbols-rounded !text-[16px] text-dim" aria-hidden="true"
							>close</span
						>
					</button>
				{/each}
				{#each filters.notTags as t (t)}
					<button
						type="button"
						onclick={() => onChange({ notTags: filters.notTags.filter((x) => x !== t) })}
						aria-label="Remove excluded tag {t}"
						class="flex h-7 items-center gap-0.5 rounded-[2px] border border-dashed border-white/25 pr-1.5 pl-2 text-xs text-dim"
					>
						<span class="material-symbols-rounded !text-[14px]" aria-hidden="true">block</span>
						<span class="line-through">{t}</span>
						<span class="material-symbols-rounded !text-[16px]" aria-hidden="true">close</span>
					</button>
				{/each}
			</div>
		{/if}
	</div>

	{#if isAnime}
		<div class="flex flex-col gap-2.5">
			{@render heading('Season', `${idPrefix}-season`)}
			<div class="grid grid-cols-2 gap-2">
				<select
					value={filters.season}
					onchange={(e) => onChange({ season: e.currentTarget.value as BrowseState['season'] })}
					aria-label="Season"
					class="h-10 field-line px-0.5 text-sm text-ink"
				>
					<option value="">Any season</option>
					{#each SEASONS as s (s.key)}
						<option value={s.key}>{s.label}</option>
					{/each}
				</select>
				<select
					value={filters.year ?? ''}
					onchange={(e) =>
						onChange({ year: e.currentTarget.value ? Number(e.currentTarget.value) : null })}
					aria-label="Year"
					class="h-10 field-line px-0.5 font-mono text-sm text-ink"
				>
					<option value="">Any year</option>
					{#each years as y (y)}
						<option value={y}>{y}</option>
					{/each}
				</select>
			</div>
		</div>
	{:else}
		<div class="flex flex-col gap-2.5">
			{@render heading('Country of origin', `${idPrefix}-country`)}
			<div
				class="grid grid-cols-4 gap-1 border-b border-line"
				role="radiogroup"
				aria-labelledby="{idPrefix}-country"
			>
				{#each [{ key: '', label: 'All', long: 'All countries' }, ...COUNTRIES] as c (c.key)}
					{@const on = filters.country === c.key}
					<button
						type="button"
						role="radio"
						aria-checked={on}
						aria-label={c.long}
						title={c.long}
						onclick={() => onChange({ country: c.key as BrowseState['country'] })}
						class="grid h-[34px] place-items-center text-[13px] {on
							? 'font-semibold text-ink shadow-[inset_0_-1.5px_0_var(--color-anime)]'
							: 'text-muted hover:text-ink'}"
					>
						{c.label}
					</button>
				{/each}
			</div>
		</div>
	{/if}

	<div class="flex flex-col gap-2.5">
		{@render heading('Format', `${idPrefix}-format`)}
		<div class="flex flex-col gap-0.5" role="group" aria-labelledby="{idPrefix}-format">
			{#each formats as f (f.key)}
				{@const on = filters.formats.includes(f.key)}
				<button
					type="button"
					role="checkbox"
					aria-checked={on}
					onclick={() => onChange({ formats: toggle(filters.formats, f.key) })}
					class="touch-target relative flex h-9 items-center gap-2.5 text-sm text-[#DDD3C3]"
				>
					<span
						class="grid h-5 w-5 place-items-center rounded-[2px]"
						style="background:{on ? accent : 'transparent'};border:{on
							? '0'
							: '1.5px solid rgb(255 255 255 / 0.2)'};color:{accentInk}"
						aria-hidden="true"
					>
						<span class="material-symbols-rounded !text-[16px]" style="opacity:{on ? 1 : 0}"
							>check</span
						>
					</span>
					<span class="flex-1 text-left">{f.label}</span>
				</button>
			{/each}
		</div>
	</div>

	<div class="flex flex-col gap-2.5">
		{@render heading(isAnime ? 'Status' : 'Publishing status', `${idPrefix}-status`)}
		<select
			value={filters.status}
			onchange={(e) => onChange({ status: e.currentTarget.value })}
			aria-labelledby="{idPrefix}-status"
			class="h-10 field-line px-0.5 text-sm text-ink"
		>
			<option value="">Any status</option>
			{#each STATUSES as s (s.key)}
				<option value={s.key}>{s.label}</option>
			{/each}
		</select>
	</div>

	<div class="flex flex-col gap-3.5">
		<div class="flex justify-between">
			{@render heading('Score', `${idPrefix}-score`)}
			<div class="font-mono text-xs text-[#DDD3C3]">{scoreLabel}</div>
		</div>
		<div class="relative h-5" role="group" aria-labelledby="{idPrefix}-score">
			<div class="absolute inset-x-0 top-2 h-1 rounded-full bg-raised-hover"></div>
			<div
				class="absolute top-2 h-1 rounded-full"
				style="left:{(scoreMin / SCORE_MAX) * 100}%;right:{100 -
					(scoreMax / SCORE_MAX) * 100}%;background:{accent}"
			></div>
			<input
				type="range"
				class="range-dual"
				min="0"
				max={SCORE_MAX}
				step="0.5"
				bind:value={() => scoreMin, (v) => (scoreMin = Math.min(Number(v), scoreMax))}
				onchange={commitScore}
				aria-label="Minimum score"
			/>
			<input
				type="range"
				class="range-dual"
				min="0"
				max={SCORE_MAX}
				step="0.5"
				bind:value={() => scoreMax, (v) => (scoreMax = Math.max(Number(v), scoreMin))}
				onchange={commitScore}
				aria-label="Maximum score"
			/>
		</div>
	</div>

	{#if signedIn}
		<button
			type="button"
			role="switch"
			aria-checked={filters.hideOnList}
			onclick={() => onChange({ hideOnList: !filters.hideOnList })}
			class="flex items-center justify-between border-t border-line py-3 text-left"
		>
			<span class="flex flex-col gap-0.5">
				<span class="text-sm">Hide titles on my list</span>
				<span class="text-xs text-dim">Discover only</span>
			</span>
			<span
				class="h-[26px] w-11 flex-none rounded-full p-[3px] transition-colors"
				style="background:{filters.hideOnList ? accent : 'var(--color-raised-hover)'}"
				aria-hidden="true"
			>
				<span
					class="block h-5 w-5 rounded-full bg-ink transition-transform"
					style="transform:translateX({filters.hideOnList ? '18px' : '0'})"
				></span>
			</span>
		</button>
	{/if}
</div>
