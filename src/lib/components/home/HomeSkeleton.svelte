<script lang="ts">
	import Skeleton from '#lib/components/shared/Skeleton.svelte';

	// Home while your list loads, in its editorial shape: the masthead, then
	// Continue's lead and rows, then a row of covers.
</script>

<div class="flex flex-col gap-10 px-4 pb-24 lg:gap-14 lg:px-10 lg:pb-20 xl:px-20" aria-busy="true">
	<div>
		<div class="border-b border-line py-3"><Skeleton class="h-3 w-56" /></div>
		<div
			class="flex flex-col gap-4 border-b-[3px] border-double border-line py-7 lg:flex-row lg:items-end lg:justify-between lg:py-10"
		>
			<div class="flex flex-col gap-4">
				<Skeleton class="h-11 w-64 lg:h-[72px] lg:w-[420px]" />
				<Skeleton class="h-3.5 w-72 lg:w-96" />
			</div>
			<div class="flex gap-8">
				{#each Array(3) as _, i (i)}<Skeleton class="h-12 w-14 lg:h-16 lg:w-16" />{/each}
			</div>
		</div>
	</div>

	<div class="flex flex-col gap-5">
		<Skeleton class="h-7 w-56" />
		<div class="flex gap-8 border-b border-line pb-8">
			<Skeleton class="aspect-2/3 w-28 flex-none lg:w-[170px]" />
			<div class="flex flex-1 flex-col gap-3 pt-2">
				<Skeleton class="h-3 w-32" />
				<Skeleton class="h-9 w-3/4 lg:h-11" />
				<Skeleton class="h-3 w-1/2" />
				<Skeleton class="mt-3 h-11 w-44" />
			</div>
		</div>
		<div class="grid gap-x-12 xl:grid-cols-2">
			{#each Array(4) as _, i (i)}
				<div class="flex items-center gap-4 border-b border-line py-3">
					<Skeleton class="aspect-2/3 w-11 flex-none" />
					<div class="flex flex-1 flex-col gap-2">
						<Skeleton class="h-3 w-3/5" />
						<Skeleton class="h-2.5 w-2/5" />
					</div>
				</div>
			{/each}
		</div>
	</div>

	<div class="flex flex-col gap-4">
		<Skeleton class="h-7 w-44" />
		<div class="grid grid-cols-3 gap-3 lg:grid-cols-7 lg:gap-5">
			{#each Array(7) as _, i (i)}<Skeleton class="aspect-2/3 w-full" />{/each}
		</div>
	</div>
</div>
