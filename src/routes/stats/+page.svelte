<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';

	// Stats became part of the profile; old links (and bookmarks) forward there,
	// keeping ?range=.
	$effect(() => {
		void goto(`/profile${page.url.search}`, { replace: true });
	});
</script>
