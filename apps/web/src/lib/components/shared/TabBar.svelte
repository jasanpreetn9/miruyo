<script lang="ts">
	import { session } from '#lib/state/session.svelte.ts';

	interface Props {
		active?: 'home' | 'browse' | 'seasonal' | 'list' | 'profile';
	}

	let { active = 'home' }: Props = $props();

	const isAnime = $derived(session.mode === 'anime');

	// Profile: the account, favourites and Stats.
	// Seasonal is the season chart; manga has no seasons, so its slot is New
	// releases. Search lives in Browse (and ⌘K).
	const HREF = $derived({
		home: '/',
		browse: '/browse',
		seasonal: isAnime ? '/seasonal' : '/schedule',
		list: '/list',
		// your profile is your own user page; signed out, /profile asks you to log in
		profile: session.user ? `/user/${encodeURIComponent(session.user.name)}` : '/profile'
	});
	const accent = $derived(isAnime ? 'var(--color-anime)' : 'var(--color-manga)');

	// `icon: '…'` so icons.test.ts can check each is in app.html's icon font
	const tabs = $derived(
		(
			[
				{ key: 'home', label: 'Home', icon: 'home' },
				{ key: 'browse', label: 'Browse', icon: 'explore' },
				{
					key: 'seasonal',
					label: isAnime ? 'Seasonal' : 'Releases',
					icon: isAnime ? 'calendar_month' : 'new_releases'
				},
				{ key: 'list', label: 'My List', icon: 'bookmarks' },
				{ key: 'profile', label: 'Profile', icon: 'person' }
			] as const
		).map((tab) => ({ ...tab, isActive: tab.key === active }))
	);
</script>

<nav
	class="fixed inset-x-0 bottom-0 z-50 grid grid-cols-5 border-t border-line bg-canvas/92 px-2 pb-6 backdrop-blur-xl lg:hidden"
>
	{#each tabs as tab (tab.key)}
		<a
			href={HREF[tab.key]}
			class="flex h-[58px] flex-col items-center justify-center gap-0.5"
			style="color:{tab.isActive ? 'var(--color-ink)' : 'var(--color-dim)'};box-shadow:{tab.isActive
				? `inset 0 2px 0 ${accent}`
				: 'none'}"
		>
			<span class="grid h-[30px] w-14 place-items-center">
				<span
					class="material-symbols-rounded !text-[24px]"
					style="font-variation-settings:'FILL' {tab.isActive ? 1 : 0}">{tab.icon}</span
				>
			</span>
			<span class="text-[11px]" style="font-weight:{tab.isActive ? 600 : 500}">{tab.label}</span>
		</a>
	{/each}
</nav>
