<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import { openSearch } from '#lib/state/search.svelte.ts';

	// Search & browse are one screen: the Search tab opens Browse
	// with the search box focused, and ?q= searches straight away.
	onMount(() => openSearch({ replace: true, q: page.url.searchParams.get('q') ?? '' }));
</script>
