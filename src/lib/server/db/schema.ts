import { sql, type SQLWrapper } from 'drizzle-orm';
import {
	char,
	check,
	foreignKey,
	integer,
	pgEnum,
	pgPolicy,
	pgTable,
	primaryKey,
	text,
	timestamp,
	unique,
	uniqueIndex,
	uuid
} from 'drizzle-orm/pg-core';
import { anonRole, authenticatedRole } from 'drizzle-orm/supabase';

const rlsTo = [anonRole, authenticatedRole];

export const expenseSplitMode = pgEnum('expense_split_mode', ['even', 'custom']);
export const groupAccessMode = pgEnum('group_access_mode', ['public', 'private']);

function canWriteExpenseSql(groupId: SQLWrapper, expenseId: SQLWrapper) {
	return sql`public.can_write_expense(${groupId}, (SELECT e.recorded_by_member_id FROM public.expenses e WHERE e.id = ${expenseId}))`;
}

/** A trip. Creator is a member (`creator_member_id`); the FK is deferred in SQL. */
export const groups = pgTable(
	'groups',
	{
		id: uuid('id').defaultRandom().primaryKey(),
		name: text('name').notNull(),
		currencyCode: char('currency_code', { length: 3 }).notNull(),
		accessMode: groupAccessMode('access_mode').notNull(),
		creatorMemberId: uuid('creator_member_id').notNull(),
		createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow()
	},
	(table) => [
		unique('groups_id_creator_member_id_unique').on(table.id, table.creatorMemberId),
		check('groups_currency_code_format', sql`${table.currencyCode} ~ '^[A-Z]{3}$'`),
		pgPolicy('groups_select', {
			as: 'permissive',
			for: 'select',
			to: rlsTo,
			using: sql`public.has_group_grant(${table.id})`
		}),
		pgPolicy('groups_insert', {
			as: 'permissive',
			for: 'insert',
			to: rlsTo,
			withCheck: sql`auth.uid() IS NOT NULL`
		}),
		pgPolicy('groups_update', {
			as: 'permissive',
			for: 'update',
			to: rlsTo,
			using: sql`public.is_group_creator(${table.id})`,
			withCheck: sql`public.is_group_creator(${table.id})`
		}),
		pgPolicy('groups_delete', {
			as: 'permissive',
			for: 'delete',
			to: rlsTo,
			using: sql`public.is_group_creator(${table.id})`
		})
	]
).enableRLS();

/** A named person on the trip. */
export const groupMembers = pgTable(
	'group_members',
	{
		id: uuid('id').defaultRandom().primaryKey(),
		groupId: uuid('group_id')
			.notNull()
			.references(() => groups.id, { onDelete: 'cascade' }),
		name: text('name').notNull(),
		email: text('email'),
		createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow()
	},
	(table) => [
		unique('group_members_group_id_id_unique').on(table.groupId, table.id),
		uniqueIndex('group_members_group_name_unique')
			.on(table.groupId, sql`lower(${table.name})`),
		uniqueIndex('group_members_group_email_unique')
			.on(table.groupId, sql`lower(${table.email})`)
			.where(sql`${table.email} IS NOT NULL`),
		pgPolicy('group_members_select', {
			as: 'permissive',
			for: 'select',
			to: rlsTo,
			using: sql`public.has_group_grant(${table.groupId})`
		}),
		pgPolicy('group_members_insert', {
			as: 'permissive',
			for: 'insert',
			to: rlsTo,
			withCheck: sql`public.is_group_creator(${table.groupId})
				OR public.has_group_grant(${table.groupId})
				OR (auth.uid() IS NOT NULL AND public.group_has_no_grants(${table.groupId}))`
		}),
		pgPolicy('group_members_update', {
			as: 'permissive',
			for: 'update',
			to: rlsTo,
			using: sql`public.is_group_creator(${table.groupId})`,
			withCheck: sql`public.is_group_creator(${table.groupId})`
		}),
		pgPolicy('group_members_delete', {
			as: 'permissive',
			for: 'delete',
			to: rlsTo,
			using: sql`public.is_group_creator(${table.groupId})`
		})
	]
).enableRLS();

/** This Auth user may see this group (opened the URL, or private email match). */
export const groupAccessGrants = pgTable(
	'group_access_grants',
	{
		groupId: uuid('group_id')
			.notNull()
			.references(() => groups.id, { onDelete: 'cascade' }),
		// References auth.users.id. FK is created in SQL.
		authUserId: uuid('auth_user_id').notNull()
	},
	(table) => [
		primaryKey({ columns: [table.groupId, table.authUserId] }),
		pgPolicy('group_access_grants_select', {
			as: 'permissive',
			for: 'select',
			to: rlsTo,
			using: sql`${table.authUserId} = auth.uid()`
		}),
		pgPolicy('group_access_grants_insert', {
			as: 'permissive',
			for: 'insert',
			to: rlsTo,
			withCheck: sql`${table.authUserId} = auth.uid()
				AND (
					public.group_is_public(${table.groupId})
					OR public.group_email_matches_uid(${table.groupId})
				)`
		}),
		pgPolicy('group_access_grants_delete', {
			as: 'permissive',
			for: 'delete',
			to: rlsTo,
			using: sql`${table.authUserId} = auth.uid()`
		})
	]
).enableRLS();

/** This Auth user acts as this member in this group. */
export const groupMemberIdentities = pgTable(
	'group_member_identities',
	{
		groupId: uuid('group_id').notNull(),
		groupMemberId: uuid('group_member_id').notNull(),
		// References auth.users.id. FK is created in SQL.
		authUserId: uuid('auth_user_id').notNull()
	},
	(table) => [
		primaryKey({ columns: [table.groupId, table.authUserId] }),
		foreignKey({
			columns: [table.groupId, table.groupMemberId],
			foreignColumns: [groupMembers.groupId, groupMembers.id],
			name: 'group_member_identities_member_same_group_fk'
		}).onDelete('cascade'),
		pgPolicy('group_member_identities_select', {
			as: 'permissive',
			for: 'select',
			to: rlsTo,
			using: sql`public.has_group_grant(${table.groupId}) OR ${table.authUserId} = auth.uid()`
		}),
		pgPolicy('group_member_identities_insert', {
			as: 'permissive',
			for: 'insert',
			to: rlsTo,
			withCheck: sql`${table.authUserId} = auth.uid() AND public.has_group_grant(${table.groupId})`
		}),
		pgPolicy('group_member_identities_update', {
			as: 'permissive',
			for: 'update',
			to: rlsTo,
			using: sql`${table.authUserId} = auth.uid()`,
			withCheck: sql`${table.authUserId} = auth.uid() AND public.has_group_grant(${table.groupId})`
		}),
		pgPolicy('group_member_identities_delete', {
			as: 'permissive',
			for: 'delete',
			to: rlsTo,
			using: sql`${table.authUserId} = auth.uid() OR public.is_group_creator(${table.groupId})`
		})
	]
).enableRLS();

/** A bill to split. */
export const expenses = pgTable(
	'expenses',
	{
		id: uuid('id').defaultRandom().primaryKey(),
		groupId: uuid('group_id')
			.notNull()
			.references(() => groups.id, { onDelete: 'cascade' }),
		description: text('description'),
		amountCents: integer('amount_cents').notNull(),
		splitMode: expenseSplitMode('split_mode').notNull(),
		recordedByMemberId: uuid('recorded_by_member_id').notNull(),
		updatedByMemberId: uuid('updated_by_member_id').notNull(),
		createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
		updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow()
	},
	(table) => [
		unique('expenses_group_id_id_unique').on(table.groupId, table.id),
		check('expenses_amount_cents_positive', sql`${table.amountCents} > 0`),
		foreignKey({
			columns: [table.groupId, table.recordedByMemberId],
			foreignColumns: [groupMembers.groupId, groupMembers.id],
			name: 'expenses_recorded_by_same_group_fk'
		}).onDelete('restrict'),
		foreignKey({
			columns: [table.groupId, table.updatedByMemberId],
			foreignColumns: [groupMembers.groupId, groupMembers.id],
			name: 'expenses_updated_by_same_group_fk'
		}).onDelete('restrict'),
		pgPolicy('expenses_select', {
			as: 'permissive',
			for: 'select',
			to: rlsTo,
			using: sql`public.has_group_grant(${table.groupId})`
		}),
		pgPolicy('expenses_insert', {
			as: 'permissive',
			for: 'insert',
			to: rlsTo,
			withCheck: sql`public.acting_member_id(${table.groupId}) IS NOT NULL
				AND ${table.recordedByMemberId} IS NOT DISTINCT FROM public.acting_member_id(${table.groupId})
				AND ${table.updatedByMemberId} IS NOT DISTINCT FROM public.acting_member_id(${table.groupId})`
		}),
		pgPolicy('expenses_update', {
			as: 'permissive',
			for: 'update',
			to: rlsTo,
			using: sql`public.can_write_expense(${table.groupId}, ${table.recordedByMemberId})`,
			withCheck: sql`public.can_write_expense(${table.groupId}, ${table.recordedByMemberId})
				AND ${table.updatedByMemberId} IS NOT DISTINCT FROM public.acting_member_id(${table.groupId})`
		}),
		pgPolicy('expenses_delete', {
			as: 'permissive',
			for: 'delete',
			to: rlsTo,
			using: sql`public.can_write_expense(${table.groupId}, ${table.recordedByMemberId})`
		})
	]
).enableRLS();

/** Who paid how much of an expense. */
export const payments = pgTable(
	'payments',
	{
		groupId: uuid('group_id').notNull(),
		expenseId: uuid('expense_id')
			.notNull()
			.references(() => expenses.id, { onDelete: 'cascade' }),
		memberId: uuid('member_id')
			.notNull()
			.references(() => groupMembers.id, { onDelete: 'restrict' }),
		amountCents: integer('amount_cents').notNull()
	},
	(table) => [
		primaryKey({ columns: [table.expenseId, table.memberId] }),
		check('payments_amount_cents_positive', sql`${table.amountCents} > 0`),
		foreignKey({
			columns: [table.groupId, table.expenseId],
			foreignColumns: [expenses.groupId, expenses.id],
			name: 'payments_expense_same_group_fk'
		}).onDelete('cascade'),
		foreignKey({
			columns: [table.groupId, table.memberId],
			foreignColumns: [groupMembers.groupId, groupMembers.id],
			name: 'payments_member_same_group_fk'
		}).onDelete('restrict'),
		pgPolicy('payments_select', {
			as: 'permissive',
			for: 'select',
			to: rlsTo,
			using: sql`public.has_group_grant(${table.groupId})`
		}),
		pgPolicy('payments_insert', {
			as: 'permissive',
			for: 'insert',
			to: rlsTo,
			withCheck: canWriteExpenseSql(table.groupId, table.expenseId)
		}),
		pgPolicy('payments_update', {
			as: 'permissive',
			for: 'update',
			to: rlsTo,
			using: canWriteExpenseSql(table.groupId, table.expenseId),
			withCheck: canWriteExpenseSql(table.groupId, table.expenseId)
		}),
		pgPolicy('payments_delete', {
			as: 'permissive',
			for: 'delete',
			to: rlsTo,
			using: canWriteExpenseSql(table.groupId, table.expenseId)
		})
	]
).enableRLS();

/** Who is responsible for how much of an expense. */
export const costShares = pgTable(
	'cost_shares',
	{
		groupId: uuid('group_id').notNull(),
		expenseId: uuid('expense_id')
			.notNull()
			.references(() => expenses.id, { onDelete: 'cascade' }),
		memberId: uuid('member_id')
			.notNull()
			.references(() => groupMembers.id, { onDelete: 'restrict' }),
		amountCents: integer('amount_cents').notNull()
	},
	(table) => [
		primaryKey({ columns: [table.expenseId, table.memberId] }),
		check('cost_shares_amount_cents_non_negative', sql`${table.amountCents} >= 0`),
		foreignKey({
			columns: [table.groupId, table.expenseId],
			foreignColumns: [expenses.groupId, expenses.id],
			name: 'cost_shares_expense_same_group_fk'
		}).onDelete('cascade'),
		foreignKey({
			columns: [table.groupId, table.memberId],
			foreignColumns: [groupMembers.groupId, groupMembers.id],
			name: 'cost_shares_member_same_group_fk'
		}).onDelete('restrict'),
		pgPolicy('cost_shares_select', {
			as: 'permissive',
			for: 'select',
			to: rlsTo,
			using: sql`public.has_group_grant(${table.groupId})`
		}),
		pgPolicy('cost_shares_insert', {
			as: 'permissive',
			for: 'insert',
			to: rlsTo,
			withCheck: canWriteExpenseSql(table.groupId, table.expenseId)
		}),
		pgPolicy('cost_shares_update', {
			as: 'permissive',
			for: 'update',
			to: rlsTo,
			using: canWriteExpenseSql(table.groupId, table.expenseId),
			withCheck: canWriteExpenseSql(table.groupId, table.expenseId)
		}),
		pgPolicy('cost_shares_delete', {
			as: 'permissive',
			for: 'delete',
			to: rlsTo,
			using: canWriteExpenseSql(table.groupId, table.expenseId)
		})
	]
).enableRLS();
