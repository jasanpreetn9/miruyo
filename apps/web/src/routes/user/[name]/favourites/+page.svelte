<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';

	// Favourites are on the Overview again; old links forward there.
	$effect(() => {
		void goto(`/user/${encodeURIComponent(page.params.name ?? '')}`, { replace: true });
	});
</script>
