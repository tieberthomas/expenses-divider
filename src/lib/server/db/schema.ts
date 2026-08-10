import { integer, pgTable, timestamp } from 'drizzle-orm/pg-core';

/**
 * A one-row table used only to prove the complete app-to-database connection.
 * The real expense-divider tables will replace this in the next milestone.
 */
export const demoCounter = pgTable('demo_counter', {
	id: integer('id').primaryKey().default(1),
	value: integer('value').notNull().default(0),
	updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow()
});
