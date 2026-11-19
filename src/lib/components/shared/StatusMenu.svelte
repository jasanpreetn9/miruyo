<script lang="ts">
	import { tick } from 'svelte';
	import type { MediaListStatus } from '#lib/anilist/types.ts';
	import { LIST_STATUSES, STATUS_COLOR, statusLabel } from '#lib/catalog/status.ts';
	import { DURATION, slide } from '#lib/motion.ts';

	interface Props {
		/** null = not on the list yet. */
		status: MediaListStatus | null;
		isAnime: boolean;
		onSelect: (status: MediaListStatus) => void;
		/** Shows "Open full editor" when set (the list editor arrives in Phase 4). */
		onOpenEditor?: () => void;
		/**
		 * 'button' = labelled dropdown; 'icon' = compact chevron for cards;
		 * 'add' = a round + until the title is on the list, then its status
		 * (the season chart's cards).
		 */
		variant?: 'button' | 'icon' | 'add';
		open?: boolean;
		/** Extra classes for the trigger (e.g. positioning on a card). */
		class?: string;
		label?: string;
	}

	let {
		status,
		isAnime,
		onSelect,
		onOpenEditor,
		variant = 'button',
		open = $bindable(false),
		class: className = '',
		label = status ? 'Change list status' : 'Add to list'
	}: Props = $props();

	let trigger = $state<HTMLButtonElement>();
	let menu = $state<HTMLDivElement>();
	let position = $state({ top: 0, left: 0 });

	const MENU_WIDTH = 220;

	/**
	 * Renders the menu under <body>: inside a card, an overflow-hidden or
	 * transformed ancestor (the hover lift) would otherwise clip it and become
	 * the containing block for `position: fixed`.
	 */
	function portal(node: HTMLElement) {
		document.body.appendChild(node);
		return () => node.remove();
	}

	function place() {
		if (!trigger) return;
		const rect = trigger.getBoundingClientRect();
		const left = Math.min(Math.max(8, rect.right - MENU_WIDTH), window.innerWidth - MENU_WIDTH - 8);
		const below = rect.bottom + 6;
		const menuHeight = menu?.offsetHeight ?? 300;
		const top =
			below + menuHeight > window.innerHeight - 8 ? Math.max(8, rect.top - 6 - menuHeight) : below;
		position = { top, left };
	}

	function items(): HTMLElement[] {
		return menu ? [...menu.querySelectorAll<HTMLElement>('[role^="menuitem"]')] : [];
	}

	async function show() {
		open = true;
		place();
		await tick();
		place();
		const all = items();
		(all.find((el) => el.getAttribute('aria-checked') === 'true') ?? all[0])?.focus();
	}

	function close(refocus = true) {
		open = false;
		if (refocus) trigger?.focus();
	}

	function choose(next: MediaListStatus) {
		close();
		if (next !== status) onSelect(next);
	}

	function onMenuKeydown(e: KeyboardEvent) {
		const all = items();
		const i = all.indexOf(document.activeElement as HTMLElement);
		if (e.key === 'ArrowDown') all[(i + 1) % all.length]?.focus();
		else if (e.key === 'ArrowUp') all[(i - 1 + all.length) % all.length]?.focus();
		else if (e.key === 'Home') all[0]?.focus();
		else if (e.key === 'End') all.at(-1)?.focus();
		else if (e.key === 'Escape' || e.key === 'Tab') return close(e.key === 'Escape');
		else return;
		e.preventDefault();
	}

	function onWindowPointerDown(e: PointerEvent) {
		if (!open) return;
		const target = e.target as Node;
		if (menu?.contains(target) || trigger?.contains(target)) return;
		close(false);
	}

	const dot = $derived(status ? STATUS_COLOR[status] : null);
</script>

<svelte:window
	onpointerdown={onWindowPointerDown}
	onresize={() => open && close(false)}
	onscrollcapture={() => open && close(false)}
/>

{#if variant === 'button'}
	<button
		bind:this={trigger}
		type="button"
		onclick={(e) => {
			e.stopPropagation();
			if (open) close();
			else show();
		}}
		aria-haspopup="menu"
		aria-expanded={open}
		class="flex h-10 w-[180px] press items-center gap-2 rounded-[2px] border border-line pr-2.5 pl-3 text-sm font-medium text-ink hover:border-ink {className}"
	>
		{#if dot}
			<span class="h-2 w-2 rounded-full" style="background:{dot}" aria-hidden="true"></span>
		{:else}
			<span class="material-symbols-rounded !text-[18px]" aria-hidden="true">add</span>
		{/if}
		<span class="flex-1 text-left">{status ? statusLabel(status, isAnime) : 'Add to list'}</span>
		<span class="material-symbols-rounded !text-[20px] text-muted" aria-hidden="true"
			>{open ? 'expand_less' : 'expand_more'}</span
		>
	</button>
{:else if variant === 'add'}
	<button
		bind:this={trigger}
		type="button"
		onclick={(e) => {
			e.stopPropagation();
			if (open) close();
			else show();
		}}
		aria-haspopup="menu"
		aria-expanded={open}
		aria-label={label}
		class="touch-target relative flex h-8 flex-none press items-center justify-center border text-ink {status
			? 'gap-1.5 rounded-[2px] border-line bg-canvas/80 px-2.5 text-xs font-semibold hover:border-ink'
			: 'w-8 rounded-full border-line text-muted hover:border-ink hover:text-ink'} {className}"
	>
		{#if status}
			<span class="h-2 w-2 rounded-full" style="background:{dot}" aria-hidden="true"></span>
			{statusLabel(status, isAnime)}
		{:else}
			<span class="material-symbols-rounded !text-[20px]" aria-hidden="true">add</span>
		{/if}
	</button>
{:else}
	<button
		bind:this={trigger}
		type="button"
		onclick={(e) => {
			e.stopPropagation();
			if (open) close();
			else show();
		}}
		aria-haspopup="menu"
		aria-expanded={open}
		aria-label={label}
		class="touch-target grid press place-items-center rounded-[2px] text-ink {className}"
	>
		<span class="material-symbols-rounded !text-[20px]" aria-hidden="true"
			>{open ? 'expand_less' : 'expand_more'}</span
		>
	</button>
{/if}

{#if open}
	<div
		bind:this={menu}
		{@attach portal}
		role="menu"
		tabindex="-1"
		aria-label={label}
		onkeydown={onMenuKeydown}
		onclick={(e) => e.stopPropagation()}
		transition:slide={{ y: -6, duration: DURATION.overlay }}
		class="fixed z-[70] flex flex-col layer p-1"
		style="top:{position.top}px;left:{position.left}px;width:{MENU_WIDTH}px"
	>
		{#each LIST_STATUSES as s (s)}
			<button
				type="button"
				role="menuitemradio"
				aria-checked={s === status}
				onclick={() => choose(s)}
				class="flex h-9 items-center gap-2.5 rounded-[2px] px-2.5 text-left text-sm text-ink hover:bg-white/6 focus-visible:bg-white/6"
				style:background={s === status ? 'rgba(255,255,255,.06)' : undefined}
			>
				<span class="h-2 w-2 rounded-full" style="background:{STATUS_COLOR[s]}" aria-hidden="true"
				></span>
				<span class="flex-1">{statusLabel(s, isAnime)}</span>
				<span
					class="material-symbols-rounded !text-[18px]"
					style:opacity={s === status ? 1 : 0}
					aria-hidden="true">check</span
				>
			</button>
		{/each}
		{#if onOpenEditor}
			<div class="mx-1 my-1 h-px bg-line"></div>
			<button
				type="button"
				role="menuitem"
				onclick={() => {
					close(false);
					onOpenEditor?.();
				}}
				class="flex h-9 items-center gap-2.5 rounded-[2px] px-2.5 text-left text-sm text-muted hover:bg-white/6 focus-visible:bg-white/6"
			>
				<span class="material-symbols-rounded !text-[18px]" aria-hidden="true">edit</span>
				Open full editor
			</button>
		{/if}
	</div>
{/if}
