<script lang="ts">
	import {
		hasChart,
		SEASON_NAMES,
		sameSeason,
		seasonHref,
		seasonWindow,
		shiftSeason
	} from '#lib/page-data/season-chart.ts';
	import { seasonOf, type SeasonRef } from '#lib/page-data/seasonal.ts';

	// AniChart's header, shared by the season chart (/seasonal) and the
	// week's schedule (/schedule): season tabs, then "Airing".

	interface Props {
		/** The season on show, or 'airing' on the schedule. */
		active: SeasonRef | 'airing';
		now: Date;
	}

	let { active, now }: Props = $props();

	const shown = $derived(active === 'airing' ? seasonOf(now) : active);
	// only seasons with a chart: none before 1940 or more than two years out
	const tabs = $derived(seasonWindow(shown).filter((s) => hasChart(s, now)));
	const onChart = $derived(active !== 'airing');
	const earlier = $derived(shiftSeason(shown, -1));
	const later = $derived(shiftSeason(shown, 1));
</script>

<!-- the seasons as words: the one on show in ink, underlined in vermilion -->
<nav
	class="flex [scrollbar-width:none] items-center gap-1 overflow-x-auto border-b border-line px-2 lg:gap-2 lg:px-10 xl:px-20"
	aria-label="Seasons"
	data-testid="season-header"
>
	{#if onChart && hasChart(earlier, now)}
		<a
			href={seasonHref(earlier, now)}
			aria-label="Earlier season"
			class="grid h-12 w-9 flex-none place-items-center text-muted hover:text-ink"
		>
			<span class="material-symbols-rounded !text-[22px]" aria-hidden="true">chevron_left</span>
		</a>
	{/if}
	{#each tabs as s (`${s.season}${s.year}`)}
		{@const on = onChart && sameSeason(s, shown)}
		<a
			href={seasonHref(s, now)}
			aria-current={on ? 'page' : undefined}
			class="flex h-12 flex-none items-baseline gap-1.5 px-2.5 pt-3.5 lg:px-3.5 {on
				? 'text-ink shadow-[inset_0_-2px_0_var(--color-anime)]'
				: 'text-muted hover:text-ink'}"
		>
			<span class="text-[14px] {on ? 'font-semibold' : 'font-medium'}"
				>{SEASON_NAMES[s.season]}</span
			>
			<span class="font-mono text-[11px] {on ? 'text-muted' : 'text-dim'}">{s.year}</span>
		</a>
	{/each}
	{#if onChart && hasChart(later, now)}
		<a
			href={seasonHref(later, now)}
			aria-label="Later season"
			class="grid h-12 w-9 flex-none place-items-center text-muted hover:text-ink"
		>
			<span class="material-symbols-rounded !text-[22px]" aria-hidden="true">chevron_right</span>
		</a>
	{/if}
	<span class="mx-1 h-5 w-px flex-none bg-line lg:mx-3" aria-hidden="true"></span>
	<a
		href="/schedule"
		aria-current={active === 'airing' ? 'page' : undefined}
		class="flex h-12 flex-none items-center gap-1.5 px-2.5 text-[14px] {active === 'airing'
			? 'font-semibold text-ink shadow-[inset_0_-2px_0_var(--color-anime)]'
			: 'font-medium text-muted hover:text-ink'}"
	>
		<span class="material-symbols-rounded !text-[18px]" aria-hidden="true">calendar_month</span>
		Airing
	</a>
</nav>
