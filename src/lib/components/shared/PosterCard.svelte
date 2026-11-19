<script lang="ts">
	import { goto } from '$app/navigation';
	import { prefersReducedMotion } from 'svelte/motion';
	import type { MediaListStatus } from '#lib/anilist/types.ts';
	import { isInProgress, STATUS_COLOR, statusLabel } from '#lib/catalog/status.ts';
	import type { Title } from '#lib/catalog/types.ts';
	import { DURATION, slide } from '#lib/motion.ts';
	import { entryFromTitle, list } from '#lib/state/list.svelte.ts';
	import { editor } from '#lib/state/editor.svelte.ts';
	import { changeStatus, plusOne } from '#lib/state/list-actions.ts';
	import { session } from '#lib/state/session.svelte.ts';
	import CountdownChip from './CountdownChip.svelte';
	import CoverImage from './CoverImage.svelte';
	import ProgressBar from './ProgressBar.svelte';
	import StatusMenu from './StatusMenu.svelte';

	interface Props {
		title: Title;
		size?: 'md' | 'sm';
		loggedOut?: boolean;
		reason?: string;
		countdown?: boolean;
		meta?: 'default' | 'season';
		noHover?: boolean;
		/** Its cover loads right away (above the fold), or first of all (`priority`). */
		eager?: boolean;
		priority?: boolean;
	}

	let {
		title,
		size = 'md',
		loggedOut = false,
		reason = '',
		countdown = false,
		meta: metaMode = 'default',
		noHover = false,
		eager = false,
		priority = false
	}: Props = $props();

	let hover = $state(false);
	/** Overlay opened by a long-press on touch. */
	let pressed = $state(false);
	let menuOpen = $state(false);
	let revealed = $state(false);
	let card = $state<HTMLDivElement>();

	const isAnime = $derived(title.isAnime);
	const entry = $derived(loggedOut ? null : list.entryFor(title));
	const progress = $derived(entry?.progress ?? 0);
	const total = $derived(title.total);
	const inProgress = $derived(!!entry && isInProgress(entry.status));
	const atTotal = $derived(inProgress && !!total && progress >= total);
	const next = $derived(title.next);

	// 18+ covers stay blurred unless the viewer's AniList setting allows them
	const hidden = $derived(!!title.adult && !session.showAdultContent && !revealed);

	const metaText = $derived(
		hidden
			? 'Enable 18+ in your AniList settings'
			: metaMode === 'season'
				? [title.format, title.season].filter(Boolean).join(' · ')
				: [title.format, title.countLabel, isAnime ? title.studio : title.author?.split(' · ')[0]]
						.filter(Boolean)
						.join(' · ')
	);

	const active = $derived((hover || pressed || menuOpen) && !noHover && !hidden);
	// every card gets the same hover row: a primary action and the status menu
	const showOverlay = $derived(active);
	const lift = $derived(hover && !noHover && !hidden && !prefersReducedMotion.current);
	const statusColor = $derived(entry ? STATUS_COLOR[entry.status] : '#fff');
	const statusText = $derived(
		entry
			? inProgress
				? `${statusLabel(entry.status, isAnime)} · ${progress}/${total ?? '?'}`
				: statusLabel(entry.status, isAnime)
			: ''
	);

	const accentBtn = $derived(isAnime ? 'var(--color-anime)' : 'var(--color-manga)');
	const accentInk = $derived(isAnime ? 'var(--color-anime-ink)' : 'var(--color-manga-ink)');

	/**
	 * Edits only go through while the list syncs to AniList — otherwise they'd
	 * look saved and silently vanish. Signed out, they lead to log in instead;
	 * while the account is still loading or unreachable, they wait.
	 */
	function canEdit(): boolean {
		if (list.sync) return true;
		if (loggedOut || session.authState === 'out') void goto('/login');
		return false;
	}

	function increment(e: MouseEvent) {
		e.stopPropagation();
		doIncrement();
	}

	function complete(e: MouseEvent) {
		e.stopPropagation();
		doComplete();
	}

	function setStatus(status: MediaListStatus) {
		if (canEdit()) void changeStatus(title, status);
	}

	/**
	 * The hover row's main button: "Planning" for titles not on the list, and
	 * for titles on it, the likeliest next step for their status.
	 */
	const primary = $derived.by(() => {
		const watch = isAnime ? 'watching' : 'reading';
		if (!entry) return { label: 'Planning', icon: 'add', run: () => setStatus('PLANNING') };
		if (atTotal)
			return { label: 'Mark completed', icon: 'task_alt', complete: true, run: doComplete };
		if (inProgress) {
			return {
				label: `1 ${title.unit}`,
				icon: 'add',
				aria: `Add one ${isAnime ? 'episode' : 'chapter'}`,
				run: doIncrement
			};
		}
		if (entry.status === 'PLANNING') {
			return { label: `Start ${watch}`, icon: 'play_arrow', run: () => setStatus('CURRENT') };
		}
		if (entry.status === 'COMPLETED') {
			return {
				label: isAnime ? 'Rewatch' : 'Reread',
				icon: 'replay',
				run: () => setStatus('REPEATING')
			};
		}
		return { label: 'Resume', icon: 'play_arrow', run: () => setStatus('CURRENT') };
	});

	function doIncrement() {
		if (canEdit()) void plusOne(title);
	}

	function doComplete() {
		if (canEdit()) void changeStatus(title, 'COMPLETED');
	}

	function runPrimary(e: MouseEvent) {
		e.stopPropagation();
		primary.run();
	}

	// Touch: a long-press reveals the same overlay that hover does on desktop
	const LONG_PRESS_MS = 450;
	let pressTimer: ReturnType<typeof setTimeout> | undefined;

	function onPointerDown(e: PointerEvent) {
		if (e.pointerType === 'mouse' || noHover) return;
		clearTimeout(pressTimer);
		pressTimer = setTimeout(() => (pressed = true), LONG_PRESS_MS);
	}

	function cancelPress() {
		clearTimeout(pressTimer);
	}

	/**
	 * The cover opens the title page (the title text is the keyboard/AT link).
	 * Not right after a long-press, which opened the overlay instead.
	 */
	function openTitle() {
		if (pressed) return;
		void goto(`/title/${title.id}`);
	}

	function onWindowPointerDown(e: PointerEvent) {
		if (pressed && !card?.contains(e.target as Node)) pressed = false;
	}
</script>

<svelte:window onpointerdown={onWindowPointerDown} />

<div
	bind:this={card}
	class="flex w-full min-w-0 flex-col gap-2.5"
	role="group"
	aria-label={hidden ? 'Hidden 18+ title' : title.title}
	onpointerenter={(e) => e.pointerType === 'mouse' && (hover = true)}
	onpointerleave={(e) => e.pointerType === 'mouse' && (hover = false)}
	onpointerdown={onPointerDown}
	onpointerup={cancelPress}
	onpointercancel={cancelPress}
	onpointermove={(e) => e.pointerType !== 'mouse' && (e.movementX || e.movementY) && cancelPress()}
	oncontextmenu={(e) => pressed && e.preventDefault()}
>
	<div
		onclick={openTitle}
		role="presentation"
		class="relative aspect-2/3 cursor-pointer overflow-hidden rounded-[2px] transition-[transform,box-shadow] duration-(--duration-lift) ease-enter select-none"
		style="background:{title.coverMissing
			? 'var(--color-raised-hover)'
			: title.placeholder};box-shadow:{hover && !noHover && !hidden
			? `6px 6px 0 color-mix(in oklch, ${title.accent} 55%, var(--color-canvas))`
			: 'none'};transform:{lift ? 'translate(-2px, -2px)' : 'none'}"
	>
		<div class="absolute inset-0">
			<CoverImage {title} {eager} {priority} />
		</div>
		{#if title.coverMissing}
			<div class="absolute inset-0 flex flex-col items-center justify-center gap-2 p-4 text-center">
				<span class="material-symbols-rounded !text-[28px] text-dim" aria-hidden="true"
					>image_not_supported</span
				>
				<div class="font-display text-[15px] leading-[1.15] font-medium text-muted">
					{hidden ? 'Hidden title' : title.title}
				</div>
			</div>
		{/if}

		{#if hidden}
			<div
				class="absolute inset-0 backdrop-blur-xl"
				style="background:{title.coverMissing ? 'transparent' : 'rgba(19,17,15,.45)'}"
			></div>
			<div
				class="absolute inset-0 flex flex-col items-center justify-center gap-2.5 p-3 text-center"
			>
				<span class="material-symbols-rounded !text-[28px]" aria-hidden="true">visibility_off</span>
				<div class="text-xs font-semibold">18+ · Hidden</div>
				<button
					onclick={(e) => {
						e.stopPropagation();
						revealed = true;
					}}
					class="touch-target relative h-8 press rounded-[2px] border border-white/20 bg-[rgba(19,17,15,.6)] px-3 text-xs font-semibold text-ink"
				>
					Reveal
				</button>
			</div>
		{/if}

		{#if showOverlay}
			<div
				class="absolute inset-0 flex flex-col justify-end gap-2 p-2.5"
				style="background:linear-gradient(180deg,rgba(19,17,15,0) 25%,rgba(19,17,15,.94) 100%)"
				transition:slide={{ y: 10, duration: DURATION.overlay }}
			>
				{#if entry}
					<div
						class="flex items-center gap-[5px] text-[11px] font-semibold"
						style="color:{statusColor}"
					>
						<span class="h-1.5 w-1.5 flex-none rounded-full" style="background:{statusColor}"
						></span>
						<span class="truncate">{statusText}</span>
					</div>
				{/if}
				<div class="text-xs leading-snug text-[#DDD3C3]">{title.genres.join(' · ')}</div>
				<div class="flex gap-1.5">
					<button
						onclick={runPrimary}
						aria-label={primary.aria}
						class="flex h-9 min-w-0 flex-1 press items-center justify-center gap-1 rounded-[2px] text-[13px] font-semibold"
						style="background:{primary.complete
							? 'var(--color-green)'
							: accentBtn};color:{primary.complete ? '#06210F' : accentInk}"
					>
						<span class="material-symbols-rounded !text-[18px]" aria-hidden="true"
							>{primary.icon}</span
						>
						<span class="truncate {primary.icon === 'add' && entry ? 'font-mono' : ''}"
							>{primary.label}</span
						>
					</button>
					<StatusMenu
						status={entry?.status ?? null}
						{isAnime}
						onSelect={setStatus}
						variant="icon"
						bind:open={menuOpen}
						class="h-9 w-9 bg-white/15"
						label={entry ? 'Manage list entry' : 'More options'}
						onOpenEditor={loggedOut || session.authState === 'out'
							? undefined
							: () => editor.open(title)}
					/>
				</div>
			</div>
		{/if}

		{#if entry}
			<div
				class="absolute inset-x-0 bottom-0 flex items-center justify-between gap-1.5 px-2 pt-2 pb-[11px] {showOverlay
					? 'invisible'
					: ''}"
				style="background:linear-gradient(180deg,rgba(19,17,15,0),rgba(19,17,15,.88))"
			>
				<div
					class="flex h-[22px] min-w-0 items-center gap-[5px] rounded-[2px] bg-[rgba(19,17,15,.85)] px-2 text-[11px] font-semibold whitespace-nowrap"
					style="color:{statusColor}"
				>
					<span class="h-1.5 w-1.5 flex-none rounded-full" style="background:{statusColor}"></span>
					<span class="truncate">{statusText}</span>
				</div>
				{#if atTotal}
					<!-- the total never auto-completes; offer it instead of +1 -->
					<button
						onclick={complete}
						aria-label="Mark as completed"
						class="touch-target relative flex h-7 flex-none press items-center gap-0.5 rounded-[2px] px-[9px] pl-[5px] text-[11px] font-bold"
						style="background:var(--color-green);color:#06210F"
					>
						<span class="material-symbols-rounded !text-[16px]">task_alt</span>
						Done
					</button>
				{:else if inProgress}
					<button
						onclick={increment}
						aria-label="Add one {isAnime ? 'episode' : 'chapter'}"
						class="touch-target relative flex h-7 flex-none press items-center rounded-[2px] bg-ink px-[9px] pl-[5px] font-mono text-[11px] font-bold text-surface"
					>
						<span class="material-symbols-rounded !text-[16px]">add</span>
						1
					</button>
				{/if}
			</div>
			<ProgressBar
				value={progress}
				{total}
				color={statusColor}
				full={entry.status === 'COMPLETED'}
				class="absolute inset-x-0 bottom-0 h-[3px]"
			/>
		{/if}
	</div>

	<div class="flex flex-col gap-1">
		<a
			href="/title/{title.id}"
			class="line-clamp-2 font-semibold text-ink hover:text-ink hover:underline"
			style="font-size:{size === 'sm' ? '13px' : '14px'}"
		>
			{hidden ? 'Hidden title' : title.title}
		</a>
		{#if reason}
			<div class="flex gap-1 text-xs leading-snug text-muted">
				<span
					class="material-symbols-rounded mt-px !text-[14px]"
					style="color:var(--color-anime-soft)">auto_awesome</span
				>
				<span>{reason}</span>
			</div>
		{/if}
		{#if countdown && next && !hidden}
			<CountdownChip {next} />
		{/if}
		<div class="truncate text-xs text-dim">{metaText}</div>
	</div>
</div>
