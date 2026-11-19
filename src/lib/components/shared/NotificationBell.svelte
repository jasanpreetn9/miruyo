<script lang="ts">
	import { tick } from 'svelte';
	import { fetchNotifications } from '#lib/anilist/client.ts';
	import {
		buildNotifications,
		groupNotifications,
		type NotificationItem
	} from '#lib/page-data/notifications.ts';
	import { session } from '#lib/state/session.svelte.ts';

	interface Props {
		/** The phone header: a smaller button, and the panel spans the screen. */
		compact?: boolean;
		/** The dot's colour (the mode's accent). */
		accent: string;
	}

	let { compact = false, accent }: Props = $props();

	let open = $state(false);
	let items = $state<NotificationItem[]>([]);
	let loading = $state(false);
	let error = $state('');

	let trigger = $state<HTMLButtonElement>();
	let panel = $state<HTMLElement>();

	const unread = $derived(session.user?.unreadNotificationCount ?? 0);
	const ROW = 'flex min-h-11 items-center gap-3 rounded-[2px] px-2.5 py-2';
	const panelId = $derived(compact ? 'notifications-compact' : 'notifications');

	/** Fetching marks them read on AniList, so the dot clears once they're in. */
	async function load() {
		const unreadCount = unread;
		loading = true;
		error = '';
		try {
			const list = await fetchNotifications();
			items = buildNotifications(list, { now: Math.floor(Date.now() / 1000), unreadCount });
			session.setUnreadCount(0);
		} catch (err) {
			error = err instanceof Error ? err.message : String(err);
		} finally {
			loading = false;
		}
	}

	async function show() {
		open = true;
		load();
		await tick();
		panel?.focus();
	}

	function close(refocus = true) {
		open = false;
		if (refocus) trigger?.focus();
	}

	function onWindowPointerDown(e: PointerEvent) {
		if (!open) return;
		const target = e.target as Node;
		if (panel?.contains(target) || trigger?.contains(target)) return;
		close(false);
	}
</script>

{#snippet row(item: NotificationItem)}
	{#if item.image}
		<img
			src={item.image}
			alt=""
			class="flex-none object-cover {item.imageShape === 'cover'
				? 'h-12 w-8.5'
				: 'h-9 w-9 rounded-full'}"
		/>
	{:else if item.imageShape === 'avatar'}
		<span
			class="grid h-9 w-9 flex-none place-items-center rounded-full bg-raised text-sm font-semibold text-muted"
			aria-hidden="true">{item.parts[0]?.text.charAt(0).toUpperCase()}</span
		>
	{:else}
		<span
			class="grid h-12 w-8.5 flex-none place-items-center bg-raised text-muted"
			aria-hidden="true"
		>
			<span class="material-symbols-rounded text-[18px]!">image_not_supported</span>
		</span>
	{/if}
	<span class="min-w-0 flex-1">
		<span class="line-clamp-2 text-[13px] leading-snug text-muted">
			{#each item.parts as part, i (i)}
				{#if part.strong}<strong class="font-semibold text-ink">{part.text}</strong
					>{:else}{part.text}{/if}
			{/each}
		</span>
		<span class="mt-0.5 block text-xs text-dim">{item.when}</span>
	</span>
	{#if item.unread}
		<span class="h-2 w-2 flex-none rounded-full" style="background:{accent}" aria-hidden="true"
		></span>
		<span class="sr-only">New</span>
	{/if}
{/snippet}

<svelte:window
	onpointerdown={onWindowPointerDown}
	onkeydown={(e) => {
		if (open && e.key === 'Escape') close();
	}}
/>

<div class={compact ? '' : 'relative'}>
	<button
		bind:this={trigger}
		type="button"
		onclick={() => (open ? close() : show())}
		aria-expanded={open}
		aria-controls={panelId}
		aria-label={unread > 0 ? `Notifications, ${unread} unread` : 'Notifications'}
		class="relative grid place-items-center rounded-[2px] text-muted transition-colors hover:text-ink {compact
			? 'touch-target h-8 w-8'
			: 'h-10 w-10'}"
	>
		<span
			class="material-symbols-rounded {compact ? 'text-[20px]!' : 'text-[22px]!'}"
			aria-hidden="true">notifications</span
		>
		{#if unread > 0}
			<span
				data-testid="unread-dot"
				class="absolute h-2 w-2 rounded-full {compact
					? 'top-1.25 right-1.5'
					: 'top-2.25 right-2.5'}"
				style="background:{accent};box-shadow:0 0 0 2px var(--color-surface)"
			></span>
		{/if}
	</button>

	{#if open}
		<div
			bind:this={panel}
			id={panelId}
			role="dialog"
			aria-label="Notifications"
			tabindex="-1"
			class="z-50 flex max-h-[min(70vh,560px)] pop-in flex-col overflow-hidden layer outline-none {compact
				? 'fixed top-14 right-3 left-3'
				: 'absolute top-12 right-0 w-96'}"
		>
			<div class="flex items-center justify-between border-b border-line/60 px-4 py-3">
				<h2 class="text-sm font-semibold text-ink">Notifications</h2>
				<a
					href="https://anilist.co/notifications"
					target="_blank"
					rel="noreferrer"
					class="flex items-center gap-1 text-xs font-medium text-muted hover:text-ink"
				>
					All on AniList
					<span class="material-symbols-rounded text-[14px]!" aria-hidden="true">open_in_new</span>
				</a>
			</div>

			<div class="overflow-y-auto p-1.5" aria-busy={loading}>
				{#if loading && !items.length}
					{#each [0, 1, 2, 3] as i (i)}
						<div class="flex items-center gap-3 px-2.5 py-2.5">
							<div class="h-9 w-9 flex-none animate-pulse rounded-full bg-white/5"></div>
							<div class="flex-1 space-y-1.5">
								<div class="h-3 w-4/5 animate-pulse rounded bg-white/5"></div>
								<div class="h-3 w-1/4 animate-pulse rounded bg-white/5"></div>
							</div>
						</div>
					{/each}
				{:else if error}
					<div class="px-3 py-6 text-center">
						<p class="text-sm text-muted">Couldn't load your notifications.</p>
						<button type="button" onclick={load} class="mt-3 h-9 btn-quiet px-3 text-sm font-medium"
							>Try again</button
						>
					</div>
				{:else if !items.length}
					<p class="px-3 py-8 text-center text-sm text-muted">No notifications yet.</p>
				{:else}
					{#each groupNotifications( items, { now: Math.floor(Date.now() / 1000) } ) as group (group.label)}
						<h3
							class="m-0 px-2.5 pt-2.5 pb-1 text-[11px] font-semibold tracking-wider text-dim uppercase"
						>
							{group.label}
						</h3>
						<ul>
							{#each group.items as item (item.id)}
								<!-- unread: a faint wash and the dot, not a block of the accent -->
								<li
									class={item.unread
										? 'bg-white/[.03] shadow-[inset_2px_0_0_var(--color-anime)]'
										: ''}
								>
									{#if item.href}
										<a
											href={item.href}
											target={item.external ? '_blank' : undefined}
											rel={item.external ? 'noreferrer' : undefined}
											onclick={() => close(false)}
											class="{ROW} transition-colors hover:bg-white/5">{@render row(item)}</a
										>
									{:else}
										<div class={ROW}>{@render row(item)}</div>
									{/if}
								</li>
							{/each}
						</ul>
					{/each}
				{/if}
			</div>
		</div>
	{/if}
</div>
