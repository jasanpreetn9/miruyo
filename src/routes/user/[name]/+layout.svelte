<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { toggleFollow } from '#lib/anilist/client.ts';
	import SectionError from '#lib/components/home/SectionError.svelte';
	import PersonLayout from '#lib/components/person/PersonLayout.svelte';
	import PageShell from '#lib/components/shared/PageShell.svelte';
	import Skeleton from '#lib/components/shared/Skeleton.svelte';
	import { buildProfile } from '#lib/page-data/profile.ts';
	import { buildStats } from '#lib/page-data/stats.ts';
	import { userHeader } from '#lib/page-data/user.ts';
	import { mediaTypeFor, session } from '#lib/state/session.svelte.ts';
	import { setUserPage, UserPage } from '#lib/state/user-page.svelte.ts';
	import type { LayoutProps } from './$types';

	// Someone's page, in the title and staff pages' layout (PersonLayout): the
	// avatar, Follow and a facts card in the left column; the name, bio and the
	// tabs on the right: Overview (favourites and Stats), Anime list and Manga
	// list, each its own address (/user/matchai/animelist) so a tab can be
	// shared. Yours is your profile (the nav's Profile opens it): Settings in
	// place of Follow, and no list tabs, since My List is your list (your list
	// addresses open it). The tabs share one load of the profile (UserPage);
	// their lists load as a tab needs them.

	let { data, children }: LayoutProps = $props();

	const name = $derived(page.params.name ?? '');
	const signedIn = $derived(session.authState === 'in');

	const user = new UserPage(
		() => name,
		() => data.profile
	);
	setUserPage(user);

	$effect(() => {
		if (session.authState === 'loading') return;
		user.loadProfile(signedIn);
	});
	$effect(() => () => user.reset());

	const account = $derived(user.account);
	const notFound = $derived(/not found/i.test(user.profile.error) && !account);
	const own = $derived(user.own);
	// the header: avatar, bio and the facts card ("Member since" from buildProfile,
	// then the Stats cards' numbers for the mode once the list is in, which
	// every tab loads)
	const view = $derived(user.loaded ? buildProfile(user.loaded, { showAdult: false }) : null);
	const list = $derived(user.shownList(mediaTypeFor(session.mode)));
	const numbers = $derived(
		list
			? buildStats(list, {
					isAnime: session.mode === 'anime',
					range: 'all',
					scoreFormat: user.scoreFormat,
					now: new Date()
				}).cards
			: []
	);
	const header = $derived(
		account ? userHeader(account, { own, memberSince: view?.memberSince ?? null, numbers }) : null
	);

	const base = $derived(`/user/${encodeURIComponent(account?.name ?? name)}`);
	const TABS = [
		{ path: '', route: '/user/[name]', label: 'Overview' },
		{ path: '/animelist', route: '/user/[name]/animelist', label: 'Anime list' },
		{ path: '/mangalist', route: '/user/[name]/mangalist', label: 'Manga list' }
	];

	// ── Follow ──
	let followed = $state<Record<number, boolean>>({});
	const following = $derived(
		account ? (followed[account.id] ?? account.isFollowing ?? false) : false
	);
	let followBusy = $state(false);
	async function onFollow() {
		if (!account) return;
		if (!signedIn) return void goto('/login');
		if (followBusy) return;
		followBusy = true;
		const id = account.id;
		const was = following;
		followed[id] = !was;
		try {
			followed[id] = await toggleFollow(id);
		} catch (err) {
			console.error('Failed to toggle follow:', err);
			followed[id] = was;
		} finally {
			followBusy = false;
		}
	}

	let shareNote = $state('');
	async function share() {
		const url = location.href;
		try {
			if (navigator.share) await navigator.share({ title: account?.name, url });
			else {
				await navigator.clipboard.writeText(url);
				shareNote = 'Link copied';
				setTimeout(() => (shareNote = ''), 2000);
			}
		} catch {
			// cancelled, or no clipboard access
		}
	}
</script>

<PageShell nav={own ? 'profile' : undefined} tab={own ? 'profile' : 'browse'} pad="pb-28 lg:pb-0">
	{#if notFound}
		<div class="flex flex-col items-center gap-3 px-6 py-24 text-center">
			<span class="material-symbols-rounded !text-[40px] text-dim" aria-hidden="true"
				>search_off</span
			>
			<h1
				class="m-0 font-display text-[34px] leading-[0.95] font-light tracking-[-0.04em] lg:text-[44px]"
			>
				There’s no one called {name} on AniList
			</h1>
			<p class="m-0 text-sm text-muted">They may have changed their name.</p>
		</div>
	{:else if user.profile.failed && !account}
		<div class="px-4 pt-10 lg:px-10 xl:px-20">
			<SectionError
				title="Couldn't load this profile"
				onRetry={() => user.loadProfile(signedIn)}
				detail={user.profile.error}
				retryIn={user.profile.retry.active ? user.profile.retry.label : undefined}
				rateLimited={user.profile.rateLimited}
			/>
		</div>
	{:else if !account}
		<div class="flex flex-col gap-6" aria-busy="true" aria-label="Loading profile">
			<div class="skeleton-shimmer h-36 lg:h-60"></div>
			<div class="flex items-end gap-3 px-4 lg:-mt-16 lg:px-10 xl:px-20">
				<Skeleton class="h-20 w-20 rounded-[2px] lg:h-28 lg:w-28" />
				<Skeleton class="mb-2 h-8 w-48" />
			</div>
		</div>
	{:else}
		<PersonLayout person={header!} banner={account.bannerImage} square phoneFacts={false}>
			{#snippet actions()}
				<div class="flex gap-2">
					{#if own}
						<a
							href="/settings"
							class="flex h-11 flex-1 items-center justify-center gap-2 btn-quiet px-4 text-sm font-semibold hover:text-ink"
						>
							<span class="material-symbols-rounded !text-[20px]" aria-hidden="true">settings</span>
							Settings
						</a>
					{:else}
						<button
							type="button"
							onclick={onFollow}
							aria-pressed={following}
							class="flex h-11 flex-1 press items-center justify-center gap-2 rounded-[2px] px-4 text-sm font-semibold {following
								? 'btn-quiet'
								: 'btn-ink'}"
						>
							<span class="material-symbols-rounded !text-[20px]" aria-hidden="true"
								>{following ? 'check' : 'person'}</span
							>
							{following ? 'Following' : 'Follow'}
						</button>
					{/if}
					<button
						type="button"
						onclick={share}
						aria-label="Share"
						class="grid h-11 w-11 flex-none place-items-center btn-quiet text-ink"
					>
						<span class="material-symbols-rounded !text-[20px]" aria-hidden="true">ios_share</span>
					</button>
				</div>
			{/snippet}

			<!-- the tabs, in the title page's style: someone else's only, since your
			     own list lives in My List (their addresses open it) -->
			{#if session.authState !== 'loading' && !own}
				<nav
					class="sticky top-14 z-10 -mx-4 flex scrollbar-none gap-1 overflow-x-auto border-b border-line bg-canvas/90 px-4 backdrop-blur-md lg:top-16 lg:mx-0 lg:px-0"
					aria-label="{account.name}’s profile"
				>
					{#each TABS as t (t.route)}
						{@const on = page.route.id === t.route}
						<a
							href="{base}{t.path}"
							aria-current={on ? 'page' : undefined}
							class="flex h-11 flex-none items-center px-3 text-sm whitespace-nowrap hover:text-ink {on
								? 'font-semibold text-ink'
								: 'text-muted'}"
							style="box-shadow:{on
								? `inset 0 -2px 0 ${t.path === '/mangalist' ? 'var(--color-manga)' : 'var(--color-anime)'}`
								: 'none'}"
						>
							{t.label}
						</a>
					{/each}
				</nav>
			{/if}

			{@render children()}
		</PersonLayout>
	{/if}

	{#if shareNote}
		<div class="fixed inset-x-0 bottom-28 z-50 flex justify-center lg:bottom-8" role="status">
			<div class="rounded-[2px] bg-ink px-4 py-2 text-sm font-semibold text-surface">
				{shareNote}
			</div>
		</div>
	{/if}
</PageShell>
