<script lang="ts">
	import PosterRow from '#lib/components/shared/PosterRow.svelte';
	import type { Pick } from '#lib/page-data/for-you.ts';

	// For You on Home (design 08): picks grouped by the title they come from,
	// a row for each of the top two ("Because you loved Cowboy Bebop"),
	// rather than the same reason under every poster. Only full rows: a row of
	// four left most of the screen empty.

	interface Props {
		/** Every visible pick, best first. */
		picks: Pick[];
	}

	let { picks }: Props = $props();

	/** Posters per row. */
	const ROW = 10;
	/** Fewer than this from one title, and it doesn't get a row. */
	const FULL = 6;

	const rows = $derived.by(() => {
		// by the seed that contributed most, in the order the picks rank
		const groups = new Map<number, Pick[]>();
		for (const p of picks) groups.set(p.because.id, [...(groups.get(p.because.id) ?? []), p]);
		return [...groups.values()].filter((g) => g.length >= FULL).slice(0, 2);
	});
</script>

{#if rows.length}
	{#each rows as group, i (group[0].because.id)}
		<PosterRow
			heading="Because you loved"
			em={group[0].because.title}
			titles={group.slice(0, ROW).map((p) => p.title)}
			seeAllHref={i === 0 ? '/for-you' : undefined}
		/>
	{/each}
{:else if picks.length >= FULL}
	<!-- too few per seed to group: one row, still without the repeated line -->
	<PosterRow
		heading="For You"
		jp="おすすめ"
		subtitle="From titles you rated highly"
		titles={picks.slice(0, ROW).map((p) => p.title)}
		seeAllHref="/for-you"
	/>
{/if}
