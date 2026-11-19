<script lang="ts">
	import Tick from './Tick.svelte';
	import type { MediaListStatus } from '#lib/anilist/types.ts';
	import ProgressBar from './ProgressBar.svelte';

	interface Props {
		value: number;
		total: number | null;
		unit: 'EP' | 'CH';
		status: MediaListStatus;
		/** The title's cover-derived accent, for the bar. */
		color: string;
		onIncrement: () => void;
		onDecrement?: () => void;
		onComplete: () => void;
		/** 'inline' for rows and cards; 'full' for Detail and the list editor. */
		variant?: 'inline' | 'full';
		/** Inline label, e.g. "EP 5 / 24"; defaults to "5/24". */
		label?: string;
		isAnime?: boolean;
	}

	let {
		value,
		total,
		unit,
		status,
		color,
		onIncrement,
		onDecrement,
		onComplete,
		variant = 'inline',
		label,
		isAnime = unit === 'EP'
	}: Props = $props();

	const noun = $derived(unit === 'EP' ? 'episode' : 'chapter');
	// reaching the total offers to complete, it never completes on its own
	const atTotal = $derived(!!total && value >= total && status !== 'COMPLETED');
	const accent = $derived(isAnime ? 'var(--color-anime)' : 'var(--color-manga)');
	const accentInk = $derived(isAnime ? 'var(--color-anime-ink)' : 'var(--color-manga-ink)');
</script>

{#snippet completePrompt()}
	<div
		class="flex items-center gap-2.5 rounded-[2px] border px-3 py-2"
		style="background:rgba(78,217,138,.1);border-color:rgba(78,217,138,.3)"
		role="status"
	>
		<span class="material-symbols-rounded !text-[20px] text-green" aria-hidden="true">task_alt</span
		>
		<div class="flex-1 text-[13px] leading-snug">
			{noun[0].toUpperCase() + noun.slice(1)}
			{value} of {total}. Mark as completed?
		</div>
		<button
			onclick={onComplete}
			class="touch-target relative h-8 flex-none press rounded-[2px] px-2.5 text-xs font-semibold"
			style="background:var(--color-green);color:#06210F"
		>
			Complete
		</button>
	</div>
{/snippet}

{#if variant === 'full'}
	<div class="flex flex-col gap-3.5">
		<div class="flex items-baseline justify-between">
			<div class="font-mono text-[30px] leading-none tabular-nums">
				<Tick {value} />
				<span class="text-lg text-dim">/ {total ?? '?'}</span>
			</div>
			<div class="text-xs text-muted">{noun}s</div>
		</div>
		<ProgressBar {value} {total} {color} class="h-1.5 rounded-[3px]" track="var(--color-line)" />
		{#if atTotal}
			{@render completePrompt()}
		{:else}
			<div class="flex gap-2">
				{#if onDecrement}
					<button
						onclick={onDecrement}
						disabled={value <= 0}
						aria-label="Minus one {noun}"
						class="grid h-11 w-11 press place-items-center btn-quiet text-ink disabled:opacity-40"
					>
						<span class="material-symbols-rounded !text-[22px]">remove</span>
					</button>
				{/if}
				<button
					onclick={onIncrement}
					class="flex h-11 flex-1 press items-center justify-center gap-1 rounded-[2px] font-mono text-[15px] font-bold"
					style="background:{accent};color:{accentInk}"
				>
					<span class="material-symbols-rounded !text-[22px]">add</span>1 {noun}
				</button>
			</div>
		{/if}
	</div>
{:else if atTotal}
	<!-- compact for narrow cards: the count stays as the label above -->
	<div class="flex flex-col gap-1.5">
		<div class="font-mono text-xs text-muted">{label ?? `${value}/${total}`}</div>
		<div
			class="flex items-center gap-2 rounded-[2px] border py-1 pr-1 pl-2.5"
			style="background:rgba(78,217,138,.1);border-color:rgba(78,217,138,.3)"
			role="status"
		>
			<div class="min-w-0 flex-1 text-[13px] leading-tight">Mark as completed?</div>
			<button
				onclick={onComplete}
				class="touch-target relative h-8 flex-none press rounded-[2px] px-2.5 text-xs font-semibold"
				style="background:var(--color-green);color:#06210F"
			>
				Complete
			</button>
		</div>
	</div>
{:else}
	<div class="flex items-center gap-2.5">
		<div class="flex min-w-0 flex-1 flex-col gap-1.5">
			<div class="font-mono text-xs text-muted">{label ?? `${value}/${total ?? '?'}`}</div>
			<ProgressBar {value} {total} {color} track="var(--color-line)" />
		</div>
		{#if onDecrement}
			<button
				onclick={onDecrement}
				disabled={value <= 0}
				aria-label="Minus one {noun}"
				class="grid h-11 w-9 flex-none press place-items-center rounded-[2px] border border-line text-muted hover:border-ink hover:text-ink disabled:opacity-40"
			>
				<span class="material-symbols-rounded !text-[20px]">remove</span>
			</button>
		{/if}
		<!-- +1 is the biggest target, on the right under the thumb -->
		<button
			onclick={onIncrement}
			aria-label="Add one {noun}"
			class="grid h-11 w-11 flex-none press place-items-center btn-quiet"
		>
			<span class="material-symbols-rounded !text-[22px]">add</span>
		</button>
	</div>
{/if}
