<script lang="ts">
	import { Button } from '$lib/components/ui/button';

	let { data } = $props();
</script>

<svelte:head>
	<title>Expenses Divider</title>
	<meta name="description" content="Expenses Divider — an easier way to split travel expenses." />
</svelte:head>

<main class="mx-auto flex min-h-screen max-w-xl items-center px-6 py-16">
	<section class="w-full rounded-2xl border bg-card p-8 text-center shadow-sm">
		<p class="text-sm font-medium text-muted-foreground">Expenses Divider</p>
		<h1 class="mt-2 text-3xl font-semibold tracking-tight">Stack connection check</h1>
		<p class="mt-3 text-muted-foreground">
			This button writes to the shared Supabase Postgres database through Drizzle.
		</p>

		<p class="my-8 text-6xl font-semibold tabular-nums" aria-live="polite">{data.counter}</p>

		<form method="POST" action="?/increment">
			<Button type="submit" size="lg">Increase counter</Button>
		</form>
	</section>
</main>
