<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';

	// Stats are on the Overview again; old links forward there, keeping ?range=.
	$effect(() => {
		void goto(`/user/${encodeURIComponent(page.params.name ?? '')}${page.url.search}`, {
			replace: true
		});
	});
</script>
