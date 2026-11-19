<script lang="ts">
	import { session } from '#lib/state/session.svelte.ts';
	import { goto } from '$app/navigation';
	import { openSearch } from '#lib/state/search.svelte.ts';
	import NotificationBell from './NotificationBell.svelte';
	import SessionNotice from './SessionNotice.svelte';

	interface Props {
		/** The section to highlight; none on pages outside the nav (Settings, errors). */
		active?: 'home' | 'browse' | 'seasonal' | 'list' | 'profile';
	}

	let { active }: Props = $props();

	let showUserMenu = $state(false);

	const isAnime = $derived(session.mode === 'anime');
	const accent = $derived(isAnime ? 'var(--color-anime)' : 'var(--color-manga)');
	const accentInk = $derived(isAnime ? 'var(--color-anime-ink)' : 'var(--color-manga-ink)');
	const loggedOut = $derived(session.authState === 'out');
	const isLoading = $derived(session.authState === 'loading');

	const links = $derived(
		(
			[
				['home', 'Home'],
				['browse', 'Browse'],
				['seasonal', isAnime ? 'Seasonal' : 'New releases'],
				['list', 'My List'],
				['profile', 'Profile']
			] as const
		).map(([key, label]) => ({ key, label, isActive: key === active }))
	);

	// keep the bell's count current while the tab is open
	const UNREAD_REFRESH_MS = 5 * 60_000;
	$effect(() => {
		if (session.authState !== 'in') return;
		const refresh = () => {
			if (document.visibilityState === 'visible') session.refreshUnreadCount();
		};
		const timer = setInterval(refresh, UNREAD_REFRESH_MS);
		document.addEventListener('visibilitychange', refresh);
		return () => {
			clearInterval(timer);
			document.removeEventListener('visibilitychange', refresh);
		};
	});

	function handleLogout() {
		showUserMenu = false;
		session.logout();
		goto('/login');
	}
</script>

<header class="sticky top-0 z-50 w-full border-b border-line bg-canvas/85 backdrop-blur-md">
	<!-- Desktop Header. Tablets (md–lg) get a compact version: mark-only logo,
	     icon-only mode toggle and search; the full design fits from xl. -->
	<div class="hidden h-16 items-center gap-4 px-5 lg:flex lg:gap-6 lg:px-6 xl:gap-7 xl:px-8">
		<a href="/" class="flex items-center gap-2">
			<span
				class="grid h-6.5 w-6.5 place-items-center rounded-[3px] font-jp text-[15px] font-bold"
				style="background:{accent};color:{accentInk}">見</span
			>
			<span class="hidden font-display text-[22px] font-bold tracking-[-0.02em] text-ink lg:inline"
				>miruyo</span
			>
		</a>

		<!-- the mode as two words: the current one in ink and underlined -->
		<div class="flex items-baseline text-[13px]">
			<button
				onclick={() => session.setMode('anime')}
				data-testid="toggle-anime"
				aria-pressed={isAnime}
				class="touch-target relative px-1 py-2 transition-colors hover:text-ink"
				style="font-weight:{isAnime ? 650 : 450};color:{isAnime
					? 'var(--color-ink)'
					: 'var(--color-dim)'};box-shadow:{isAnime ? `inset 0 -1.5px 0 ${accent}` : 'none'}"
			>
				Anime
			</button>
			<span class="px-0.5 text-dim" aria-hidden="true">/</span>
			<button
				onclick={() => session.setMode('manga')}
				data-testid="toggle-manga"
				aria-pressed={!isAnime}
				class="touch-target relative px-1 py-2 transition-colors hover:text-ink"
				style="font-weight:{!isAnime ? 650 : 450};color:{!isAnime
					? 'var(--color-ink)'
					: 'var(--color-dim)'};box-shadow:{!isAnime ? `inset 0 -1.5px 0 ${accent}` : 'none'}"
			>
				Manga
			</button>
		</div>

		<nav class="flex gap-1 self-stretch">
			{#each links as link (link.key)}
				<a
					href={link.key === 'home'
						? '/'
						: link.key === 'seasonal' && !isAnime
							? '/schedule'
							: link.key === 'profile' && session.user
								? `/user/${encodeURIComponent(session.user.name)}`
								: `/${link.key}`}
					class="flex h-full items-center px-2.5 text-sm whitespace-nowrap transition-colors hover:text-ink lg:px-3"
					style="font-weight:{link.isActive ? 600 : 500};color:{link.isActive
						? 'var(--color-ink)'
						: 'var(--color-muted)'};box-shadow:{link.isActive
						? `inset 0 -2px 0 ${accent}`
						: 'none'}"
				>
					{link.label}
				</a>
			{/each}
		</nav>

		<div class="flex-1"></div>

		<!-- Not a search box: it takes you to Browse with its search focused -->
		<button
			type="button"
			onclick={() => openSearch()}
			class="flex h-9 w-10 flex-none items-center justify-center gap-2 border-b border-line text-dim transition-colors hover:border-ink hover:text-ink lg:w-auto lg:min-w-44 lg:justify-start lg:px-0.5"
			aria-keyshortcuts="Meta+K Control+K"
		>
			<span class="material-symbols-rounded text-[20px]!" aria-hidden="true">search</span>
			<span class="sr-only text-sm font-medium lg:not-sr-only">Search</span>
			<kbd class="ml-auto hidden font-mono text-[11px] xl:inline" aria-hidden="true">⌘K</kbd>
		</button>

		{#if isLoading}
			<!-- Skeleton Loader while token/Viewer is being fetched -->
			<div class="flex items-center gap-2">
				<div class="h-9 w-9 animate-pulse rounded-[2px] bg-white/5"></div>
				<div class="h-9 w-18 animate-pulse rounded-full border border-line bg-white/5"></div>
			</div>
		{:else if loggedOut}
			<a
				href="/login"
				class="flex h-10 flex-none items-center gap-2 rounded-[2px] px-4 text-sm font-semibold whitespace-nowrap transition-opacity hover:opacity-90"
				style="background:{accent};color:{accentInk}"
			>
				<span>Log in{' '}<span class="hidden xl:inline">with AniList</span></span>
			</a>
		{:else}
			<!-- Authenticated User Controls -->
			<div class="relative flex items-center gap-2">
				<NotificationBell {accent} />

				<!-- Profile Pill Trigger -->
				<button
					type="button"
					onclick={() => (showUserMenu = !showUserMenu)}
					aria-label="Account"
					class="flex items-center gap-1.5 rounded-full border border-line p-0.75 pr-1.5 transition-colors hover:bg-white/5"
					aria-expanded={showUserMenu}
				>
					{#if session.user?.avatar?.medium}
						<img
							src={session.user.avatar.medium}
							alt={session.user.name}
							class="h-8 w-8 rounded-full object-cover"
						/>
					{:else}
						<div
							class="grid h-8 w-8 place-items-center rounded-full text-xs font-bold text-white"
							style="background:linear-gradient(135deg,#5AB0FF,#A08CFF)"
						>
							{session.user?.name?.slice(0, 2).toUpperCase() ?? 'AL'}
						</div>
					{/if}
					<span
						class="material-symbols-rounded text-[18px]! text-muted transition-transform {showUserMenu
							? 'rotate-180'
							: ''}"
					>
						expand_more
					</span>
				</button>

				<!-- Desktop User Dropdown -->
				{#if showUserMenu}
					<div class="absolute top-12 right-0 z-50 w-52 pop-in layer p-1">
						<div class="border-b border-line/60 px-3 py-2">
							<div class="text-[11px] font-medium text-muted">Signed in as</div>
							<div class="truncate text-sm font-semibold text-ink">
								{session.user?.name ?? 'User'}
							</div>
						</div>

						<div class="py-1">
							<a
								href={session.user
									? `https://anilist.co/user/${session.user.name}`
									: 'https://anilist.co'}
								target="_blank"
								rel="noreferrer"
								class="flex items-center gap-2 rounded-[2px] px-3 py-2 text-[13px] text-ink transition-colors hover:bg-white/5"
							>
								<span class="material-symbols-rounded text-[18px]! text-muted">open_in_new</span>
								AniList Profile
							</a>
							<a
								href="/settings"
								class="flex items-center gap-2 rounded-[2px] px-3 py-2 text-[13px] text-ink transition-colors hover:bg-white/5"
							>
								<span class="material-symbols-rounded text-[18px]! text-muted">settings</span>
								Settings
							</a>
						</div>

						<div class="border-t border-line/60 pt-1">
							<button
								type="button"
								onclick={handleLogout}
								class="flex w-full items-center gap-2 rounded-[2px] px-3 py-2 text-left text-[13px] text-rose-400 transition-colors hover:bg-rose-500/10"
							>
								<span class="material-symbols-rounded text-[18px]!">logout</span>
								Log Out
							</button>
						</div>
					</div>
				{/if}
			</div>
		{/if}
	</div>

	<!-- Mobile Header -->
	<div class="flex h-14 items-center gap-2.5 px-4 lg:hidden">
		<a href="/" class="flex items-center gap-2.5">
			<span
				class="grid h-6.5 w-6.5 place-items-center rounded-[3px] font-jp text-[15px] font-bold"
				style="background:{accent};color:{accentInk}">見</span
			>
		</a>
		<span class="flex-1 font-display text-xl font-bold tracking-[-0.02em] text-ink">miruyo</span>

		<!-- the mode as two words: the current one in ink and underlined -->
		<div class="flex items-baseline text-[13px]">
			<button
				onclick={() => session.setMode('anime')}
				aria-pressed={isAnime}
				class="touch-target relative px-1 py-1.5"
				style="font-weight:{isAnime ? 650 : 450};color:{isAnime
					? 'var(--color-ink)'
					: 'var(--color-dim)'};box-shadow:{isAnime ? `inset 0 -1.5px 0 ${accent}` : 'none'}"
			>
				Anime
			</button>
			<span class="px-0.5 text-dim" aria-hidden="true">/</span>
			<button
				onclick={() => session.setMode('manga')}
				aria-pressed={!isAnime}
				class="touch-target relative px-1 py-1.5"
				style="font-weight:{!isAnime ? 650 : 450};color:{!isAnime
					? 'var(--color-ink)'
					: 'var(--color-dim)'};box-shadow:{!isAnime ? `inset 0 -1.5px 0 ${accent}` : 'none'}"
			>
				Manga
			</button>
		</div>

		{#if loggedOut}
			<a
				href="/login"
				class="touch-target relative flex h-8 press items-center rounded-[2px] px-2.5 text-[12px] font-semibold"
				style="background:{accent};color:{accentInk}"
			>
				Log In
			</a>
		{:else if session.user}
			<NotificationBell compact {accent} />
		{/if}
		{#if !loggedOut && session.user?.avatar?.medium}
			<a
				href="/settings"
				aria-label="Settings"
				class="touch-target relative h-7.5 w-7.5 rounded-full border border-line"
			>
				<img
					src={session.user.avatar.medium}
					alt={session.user.name}
					class="h-full w-full rounded-full object-cover"
				/>
			</a>
		{/if}
	</div>

	<SessionNotice />
</header>
