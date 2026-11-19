<script lang="ts">
	import { fade } from 'svelte/transition';
	import type { HeroPick } from '#lib/page-data/home.ts';
	import { DURATION } from '#lib/motion.ts';
	import CoverImage from '#lib/components/shared/CoverImage.svelte';
	import PickHero from './PickHero.svelte';

	interface Props {
		heroes: HeroPick[];
		/** "Not this" on a For You pick. */
		onDismiss: (hero: HeroPick) => void;
	}

	let { heroes, onDismiss }: Props = $props();

	// Picked for you: what to watch next, each with its reason. It never moves
	// on its own, so a title doesn't slide away while you reach for Plan. Swipe
	// to page, or pick a dot. On desktop the dots are a numbered list of the
	// picks at the feature's right, so its empty side says what else there is.

	/** Horizontal travel (px) that counts as a swipe on touch. */
	const SWIPE = 40;

	let index = $state(0);

	const count = $derived(heroes.length);
	// the list can shrink under us (e.g. a title removed) — stay in range
	const current = $derived(heroes[Math.min(index, count - 1)]);

	function show(i: number) {
		index = (i + count) % count;
	}

	let swipeStart: number | null = null;

	function onPointerDown(e: PointerEvent) {
		if (e.pointerType !== 'mouse') swipeStart = e.clientX;
	}

	function onPointerUp(e: PointerEvent) {
		if (swipeStart === null) return;
		const dx = e.clientX - swipeStart;
		swipeStart = null;
		if (Math.abs(dx) >= SWIPE) show(index + (dx < 0 ? 1 : -1));
	}

	function onDotsKeydown(e: KeyboardEvent) {
		if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
		e.preventDefault();
		show(index + (e.key === 'ArrowRight' ? 1 : -1));
		// keep keyboard focus on the dot for the slide now showing
		(e.currentTarget as HTMLElement)
			.querySelectorAll<HTMLButtonElement>('button')
			[(index + count) % count]?.focus();
	}
</script>

{#snippet dots(extra: string)}
	{#if count > 1}
		<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
		<div
			class="flex gap-2 {extra}"
			role="group"
			aria-label="Choose slide"
			onkeydown={onDotsKeydown}
		>
			{#each heroes as hero, i (hero.title.id)}
				{@const on = i === index}
				<button
					type="button"
					onclick={() => show(i)}
					aria-label="Show {hero.title.title} ({i + 1} of {count})"
					aria-current={on ? 'true' : undefined}
					tabindex={on ? 0 : -1}
					class="touch-target relative grid h-4 place-items-center"
				>
					<span
						class="block h-1 rounded-full transition-[width,background-color] duration-(--duration-lift) ease-enter"
						style="width:{on ? 28 : 12}px;background:{on
							? 'var(--color-ink)'
							: 'rgb(239 231 218 / .25)'}"
					></span>
				</button>
			{/each}
		</div>
	{/if}
{/snippet}

{#if current}
	<section
		class="relative"
		aria-roledescription="carousel"
		aria-label="Picked for you"
		onpointerdown={onPointerDown}
		onpointerup={onPointerUp}
		onpointercancel={() => (swipeStart = null)}
	>
		<!-- slides cross-fade: both sit in the same grid cell while one leaves -->
		<div class="grid" aria-live="polite">
			{#key current.title.id}
				<div
					class="[grid-area:1/1]"
					role="group"
					aria-roledescription="slide"
					aria-label="{index + 1} of {count}"
					transition:fade={{ duration: DURATION.panel }}
					onoutrostart={(e) => ((e.currentTarget as HTMLElement).inert = true)}
				>
					<PickHero
						slide={current}
						onDismiss={current.pick ? () => onDismiss(current) : undefined}
						listed={count > 1}
					/>
				</div>
			{/key}
		</div>

		<!-- desktop: the picks, numbered, down the feature's right side -->
		{#if count > 1}
			<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
			<div
				class="absolute top-1/2 right-10 z-10 hidden w-[290px] -translate-y-1/2 lg:block xl:right-20 xl:w-[320px]"
				role="group"
				aria-label="Choose slide"
				onkeydown={onDotsKeydown}
			>
				<div class="mb-2 text-[11px] font-semibold tracking-[0.14em] text-dim uppercase">
					{count} picks
				</div>
				<div class="border-t border-line">
					{#each heroes as hero, i (hero.title.id)}
						{@const on = i === index}
						<button
							type="button"
							onclick={() => show(i)}
							aria-label="Show {hero.title.title} ({i + 1} of {count})"
							aria-current={on ? 'true' : undefined}
							tabindex={on ? 0 : -1}
							class="group grid w-full grid-cols-[30px_30px_minmax(0,1fr)] items-center gap-3 border-b border-line py-2 text-left"
						>
							<span
								class="font-display text-[22px] leading-none font-light tracking-[-0.04em] transition-colors"
								style="color:{on ? hero.title.accent : 'var(--color-dim)'}"
								>{String(i + 1).padStart(2, '0')}</span
							>
							<span
								class="relative aspect-2/3 w-[30px] overflow-hidden transition-opacity {on
									? ''
									: 'opacity-60 group-hover:opacity-100'}"
								style="background:{hero.title.placeholder}"
							>
								<CoverImage title={hero.title} thumb />
							</span>
							<span
								class="line-clamp-2 text-[13px] leading-snug font-semibold transition-colors {on
									? 'text-ink'
									: 'text-muted group-hover:text-ink'}">{hero.title.title}</span
							>
						</button>
					{/each}
				</div>
			</div>
		{/if}
		<!-- mobile: centred under the card -->
		{@render dots('mt-3 justify-center lg:hidden')}
	</section>
{/if}
