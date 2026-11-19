<script lang="ts">
	import UserList from '#lib/components/profile/UserList.svelte';
	import { possessive } from '#lib/page-data/user.ts';
	import { getUserPage } from '#lib/state/user-page.svelte.ts';

	const user = getUserPage();
</script>

<svelte:head>
	<title
		>{user.account
			? `${user.own ? 'Your' : possessive(user.account.name)} anime list · miruyo`
			: 'miruyo'}</title
	>
</svelte:head>

<UserList type="ANIME" />
