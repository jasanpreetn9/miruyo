<script lang="ts">
	interface Props {
		value: number;
		/** null = total unknown (ongoing): an open-ended bar that fades out instead of implying 100%. */
		total: number | null;
		color: string;
		/** Draw it full (completed entries). */
		full?: boolean;
		/** Height/rounding classes, e.g. "h-1 rounded-full". */
		class?: string;
		track?: string;
	}

	let {
		value,
		total,
		color,
		full = false,
		class: className = 'h-1 rounded-full',
		track = 'rgba(255,255,255,.1)'
	}: Props = $props();

	const pct = $derived(
		full ? 100 : total ? Math.min(100, Math.round((value / total) * 100)) : null
	);
</script>

{#if pct !== null}
	<div class="overflow-hidden {className}" style="background:{track}">
		<div
			class="h-full rounded-[inherit] transition-[width] duration-(--duration-panel) ease-enter"
			style="background:{color};width:{pct}%"
		></div>
	</div>
{:else}
	<div
		class="overflow-hidden {className}"
		style="background:repeating-linear-gradient(90deg,{track} 0 6px,transparent 6px 10px)"
		title="Total unknown"
	>
		<div
			class="h-full w-[70%] rounded-[inherit]"
			style="background:linear-gradient(90deg,{color} 70%,transparent)"
		></div>
	</div>
{/if}
