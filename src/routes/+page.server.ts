import { db } from '$lib/server/db';
import { demoCounter } from '$lib/server/db/schema';
import { sql } from 'drizzle-orm';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async () => {
	const current = await db.query.demoCounter.findFirst({
		where: (counter, { eq }) => eq(counter.id, 1)
	});

	return { counter: current?.value ?? 0 };
};

export const actions: Actions = {
	increment: async () => {
		await db
			.insert(demoCounter)
			.values({ id: 1, value: 1 })
			.onConflictDoUpdate({
				target: demoCounter.id,
				set: {
					value: sql`${demoCounter.value} + 1`,
					updatedAt: new Date()
				}
			});
	}
};
