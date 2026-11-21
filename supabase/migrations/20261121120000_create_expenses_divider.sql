DROP TABLE IF EXISTS "demo_counter";
--> statement-breakpoint
CREATE TYPE "public"."expense_split_mode" AS ENUM('even', 'custom');
--> statement-breakpoint
CREATE TYPE "public"."group_access_mode" AS ENUM('public', 'private');
--> statement-breakpoint
CREATE TABLE "groups" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"currency_code" char(3) NOT NULL,
	"access_mode" "group_access_mode" NOT NULL,
	"creator_member_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "groups_id_creator_member_id_unique" UNIQUE("id", "creator_member_id"),
	CONSTRAINT "groups_currency_code_format" CHECK ("groups"."currency_code" ~ '^[A-Z]{3}$')
);
--> statement-breakpoint
CREATE TABLE "group_members" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"group_id" uuid NOT NULL,
	"name" text NOT NULL,
	"email" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "group_members_group_id_groups_id_fk"
		FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE,
	CONSTRAINT "group_members_group_id_id_unique" UNIQUE("group_id", "id")
);
--> statement-breakpoint
ALTER TABLE "groups"
	ADD CONSTRAINT "groups_creator_same_group_fk"
	FOREIGN KEY ("id", "creator_member_id")
	REFERENCES "public"."group_members"("group_id", "id")
	ON DELETE RESTRICT
	DEFERRABLE INITIALLY DEFERRED;
--> statement-breakpoint
CREATE UNIQUE INDEX "group_members_group_name_unique"
	ON "group_members" USING btree ("group_id", lower("name"));
--> statement-breakpoint
CREATE UNIQUE INDEX "group_members_group_email_unique"
	ON "group_members" USING btree ("group_id", lower("email"))
	WHERE "email" IS NOT NULL;
--> statement-breakpoint
CREATE TABLE "group_access_grants" (
	"group_id" uuid NOT NULL,
	"auth_user_id" uuid NOT NULL,
	CONSTRAINT "group_access_grants_group_id_auth_user_id_pk" PRIMARY KEY("group_id", "auth_user_id"),
	CONSTRAINT "group_access_grants_group_id_groups_id_fk"
		FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE,
	CONSTRAINT "group_access_grants_auth_user_id_auth_users_fk"
		FOREIGN KEY ("auth_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE
);
--> statement-breakpoint
CREATE TABLE "group_member_identities" (
	"group_id" uuid NOT NULL,
	"group_member_id" uuid NOT NULL,
	"auth_user_id" uuid NOT NULL,
	CONSTRAINT "group_member_identities_group_id_auth_user_id_pk" PRIMARY KEY("group_id", "auth_user_id"),
	CONSTRAINT "group_member_identities_member_same_group_fk"
		FOREIGN KEY ("group_id", "group_member_id")
		REFERENCES "public"."group_members"("group_id", "id") ON DELETE CASCADE,
	CONSTRAINT "group_member_identities_auth_user_id_auth_users_fk"
		FOREIGN KEY ("auth_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE
);
--> statement-breakpoint
CREATE TABLE "expenses" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"group_id" uuid NOT NULL,
	"description" text,
	"amount_cents" integer NOT NULL,
	"split_mode" "expense_split_mode" NOT NULL,
	"recorded_by_member_id" uuid NOT NULL,
	"updated_by_member_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "expenses_amount_cents_positive" CHECK ("expenses"."amount_cents" > 0),
	CONSTRAINT "expenses_group_id_id_unique" UNIQUE("group_id", "id"),
	CONSTRAINT "expenses_group_id_groups_id_fk"
		FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE,
	CONSTRAINT "expenses_recorded_by_same_group_fk"
		FOREIGN KEY ("group_id", "recorded_by_member_id")
		REFERENCES "public"."group_members"("group_id", "id") ON DELETE RESTRICT,
	CONSTRAINT "expenses_updated_by_same_group_fk"
		FOREIGN KEY ("group_id", "updated_by_member_id")
		REFERENCES "public"."group_members"("group_id", "id") ON DELETE RESTRICT
);
--> statement-breakpoint
CREATE TABLE "payments" (
	"group_id" uuid NOT NULL,
	"expense_id" uuid NOT NULL,
	"member_id" uuid NOT NULL,
	"amount_cents" integer NOT NULL,
	CONSTRAINT "payments_expense_id_member_id_pk" PRIMARY KEY("expense_id", "member_id"),
	CONSTRAINT "payments_amount_cents_positive" CHECK ("payments"."amount_cents" > 0),
	CONSTRAINT "payments_expense_id_expenses_id_fk"
		FOREIGN KEY ("expense_id") REFERENCES "public"."expenses"("id") ON DELETE CASCADE,
	CONSTRAINT "payments_member_id_group_members_id_fk"
		FOREIGN KEY ("member_id") REFERENCES "public"."group_members"("id") ON DELETE RESTRICT,
	CONSTRAINT "payments_expense_same_group_fk"
		FOREIGN KEY ("group_id", "expense_id")
		REFERENCES "public"."expenses"("group_id", "id") ON DELETE CASCADE,
	CONSTRAINT "payments_member_same_group_fk"
		FOREIGN KEY ("group_id", "member_id")
		REFERENCES "public"."group_members"("group_id", "id") ON DELETE RESTRICT
);
--> statement-breakpoint
CREATE TABLE "cost_shares" (
	"group_id" uuid NOT NULL,
	"expense_id" uuid NOT NULL,
	"member_id" uuid NOT NULL,
	"amount_cents" integer NOT NULL,
	CONSTRAINT "cost_shares_expense_id_member_id_pk" PRIMARY KEY("expense_id", "member_id"),
	CONSTRAINT "cost_shares_amount_cents_non_negative" CHECK ("cost_shares"."amount_cents" >= 0),
	CONSTRAINT "cost_shares_expense_id_expenses_id_fk"
		FOREIGN KEY ("expense_id") REFERENCES "public"."expenses"("id") ON DELETE CASCADE,
	CONSTRAINT "cost_shares_member_id_group_members_id_fk"
		FOREIGN KEY ("member_id") REFERENCES "public"."group_members"("id") ON DELETE RESTRICT,
	CONSTRAINT "cost_shares_expense_same_group_fk"
		FOREIGN KEY ("group_id", "expense_id")
		REFERENCES "public"."expenses"("group_id", "id") ON DELETE CASCADE,
	CONSTRAINT "cost_shares_member_same_group_fk"
		FOREIGN KEY ("group_id", "member_id")
		REFERENCES "public"."group_members"("group_id", "id") ON DELETE RESTRICT
);
--> statement-breakpoint
CREATE OR REPLACE FUNCTION public.group_has_no_grants(p_group_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
	SELECT NOT EXISTS (
		SELECT 1
		FROM public.group_access_grants g
		WHERE g.group_id = p_group_id
	);
$$;
--> statement-breakpoint
CREATE OR REPLACE FUNCTION public.has_group_grant(p_group_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
	SELECT EXISTS (
		SELECT 1
		FROM public.group_access_grants g
		WHERE g.group_id = p_group_id
			AND g.auth_user_id = auth.uid()
	);
$$;
--> statement-breakpoint
CREATE OR REPLACE FUNCTION public.group_is_public(p_group_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
	SELECT EXISTS (
		SELECT 1
		FROM public.groups g
		WHERE g.id = p_group_id
			AND g.access_mode = 'public'
	);
$$;
--> statement-breakpoint
CREATE OR REPLACE FUNCTION public.group_email_matches_uid(p_group_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
	SELECT EXISTS (
		SELECT 1
		FROM public.group_members m
		WHERE m.group_id = p_group_id
			AND m.email IS NOT NULL
			AND lower(m.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
	);
$$;
--> statement-breakpoint
CREATE OR REPLACE FUNCTION public.acting_member_id(p_group_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
	SELECT i.group_member_id
	FROM public.group_member_identities i
	WHERE i.group_id = p_group_id
		AND i.auth_user_id = auth.uid()
	LIMIT 1;
$$;
--> statement-breakpoint
CREATE OR REPLACE FUNCTION public.is_group_creator(p_group_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
	SELECT EXISTS (
		SELECT 1
		FROM public.groups g
		INNER JOIN public.group_member_identities i
			ON i.group_id = g.id
			AND i.group_member_id = g.creator_member_id
		WHERE g.id = p_group_id
			AND i.auth_user_id = auth.uid()
	);
$$;
--> statement-breakpoint
CREATE OR REPLACE FUNCTION public.can_write_expense(p_group_id uuid, p_recorded_by uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
	SELECT public.is_group_creator(p_group_id)
		OR public.acting_member_id(p_group_id) IS NOT DISTINCT FROM p_recorded_by;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION public.group_has_no_grants(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.has_group_grant(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.group_is_public(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.group_email_matches_uid(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.acting_member_id(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_group_creator(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_write_expense(uuid, uuid) FROM PUBLIC;
--> statement-breakpoint
GRANT EXECUTE ON FUNCTION public.group_has_no_grants(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.has_group_grant(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.group_is_public(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.group_email_matches_uid(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.acting_member_id(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_group_creator(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_expense(uuid, uuid) TO anon, authenticated;
--> statement-breakpoint
ALTER TABLE "groups" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "group_members" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "group_access_grants" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "group_member_identities" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "expenses" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "payments" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "cost_shares" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
CREATE POLICY "groups_select" ON "groups" AS PERMISSIVE FOR SELECT TO "anon", "authenticated" USING (public.has_group_grant("groups"."id"));
--> statement-breakpoint
CREATE POLICY "groups_insert" ON "groups" AS PERMISSIVE FOR INSERT TO "anon", "authenticated" WITH CHECK (auth.uid() IS NOT NULL);
--> statement-breakpoint
CREATE POLICY "groups_update" ON "groups" AS PERMISSIVE FOR UPDATE TO "anon", "authenticated" USING (public.is_group_creator("groups"."id")) WITH CHECK (public.is_group_creator("groups"."id"));
--> statement-breakpoint
CREATE POLICY "groups_delete" ON "groups" AS PERMISSIVE FOR DELETE TO "anon", "authenticated" USING (public.is_group_creator("groups"."id"));
--> statement-breakpoint
CREATE POLICY "group_access_grants_select" ON "group_access_grants" AS PERMISSIVE FOR SELECT TO "anon", "authenticated" USING ("group_access_grants"."auth_user_id" = auth.uid());
--> statement-breakpoint
CREATE POLICY "group_access_grants_insert" ON "group_access_grants" AS PERMISSIVE FOR INSERT TO "anon", "authenticated" WITH CHECK ("group_access_grants"."auth_user_id" = auth.uid()
				AND (
					public.group_is_public("group_access_grants"."group_id")
					OR public.group_email_matches_uid("group_access_grants"."group_id")
				));
--> statement-breakpoint
CREATE POLICY "group_access_grants_delete" ON "group_access_grants" AS PERMISSIVE FOR DELETE TO "anon", "authenticated" USING ("group_access_grants"."auth_user_id" = auth.uid());
--> statement-breakpoint
CREATE POLICY "group_members_select" ON "group_members" AS PERMISSIVE FOR SELECT TO "anon", "authenticated" USING (public.has_group_grant("group_members"."group_id"));
--> statement-breakpoint
CREATE POLICY "group_members_insert" ON "group_members" AS PERMISSIVE FOR INSERT TO "anon", "authenticated" WITH CHECK (public.is_group_creator("group_members"."group_id")
				OR public.has_group_grant("group_members"."group_id")
				OR (auth.uid() IS NOT NULL AND public.group_has_no_grants("group_members"."group_id")));
--> statement-breakpoint
CREATE POLICY "group_members_update" ON "group_members" AS PERMISSIVE FOR UPDATE TO "anon", "authenticated" USING (public.is_group_creator("group_members"."group_id")) WITH CHECK (public.is_group_creator("group_members"."group_id"));
--> statement-breakpoint
CREATE POLICY "group_members_delete" ON "group_members" AS PERMISSIVE FOR DELETE TO "anon", "authenticated" USING (public.is_group_creator("group_members"."group_id"));
--> statement-breakpoint
CREATE POLICY "group_member_identities_select" ON "group_member_identities" AS PERMISSIVE FOR SELECT TO "anon", "authenticated" USING (public.has_group_grant("group_member_identities"."group_id") OR "group_member_identities"."auth_user_id" = auth.uid());
--> statement-breakpoint
CREATE POLICY "group_member_identities_insert" ON "group_member_identities" AS PERMISSIVE FOR INSERT TO "anon", "authenticated" WITH CHECK ("group_member_identities"."auth_user_id" = auth.uid() AND public.has_group_grant("group_member_identities"."group_id"));
--> statement-breakpoint
CREATE POLICY "group_member_identities_update" ON "group_member_identities" AS PERMISSIVE FOR UPDATE TO "anon", "authenticated" USING ("group_member_identities"."auth_user_id" = auth.uid()) WITH CHECK ("group_member_identities"."auth_user_id" = auth.uid() AND public.has_group_grant("group_member_identities"."group_id"));
--> statement-breakpoint
CREATE POLICY "group_member_identities_delete" ON "group_member_identities" AS PERMISSIVE FOR DELETE TO "anon", "authenticated" USING ("group_member_identities"."auth_user_id" = auth.uid() OR public.is_group_creator("group_member_identities"."group_id"));
--> statement-breakpoint
CREATE POLICY "expenses_select" ON "expenses" AS PERMISSIVE FOR SELECT TO "anon", "authenticated" USING (public.has_group_grant("expenses"."group_id"));
--> statement-breakpoint
CREATE POLICY "expenses_insert" ON "expenses" AS PERMISSIVE FOR INSERT TO "anon", "authenticated" WITH CHECK (public.acting_member_id("expenses"."group_id") IS NOT NULL
				AND "expenses"."recorded_by_member_id" IS NOT DISTINCT FROM public.acting_member_id("expenses"."group_id")
				AND "expenses"."updated_by_member_id" IS NOT DISTINCT FROM public.acting_member_id("expenses"."group_id"));
--> statement-breakpoint
CREATE POLICY "expenses_update" ON "expenses" AS PERMISSIVE FOR UPDATE TO "anon", "authenticated" USING (public.can_write_expense("expenses"."group_id", "expenses"."recorded_by_member_id")) WITH CHECK (public.can_write_expense("expenses"."group_id", "expenses"."recorded_by_member_id")
				AND "expenses"."updated_by_member_id" IS NOT DISTINCT FROM public.acting_member_id("expenses"."group_id"));
--> statement-breakpoint
CREATE POLICY "expenses_delete" ON "expenses" AS PERMISSIVE FOR DELETE TO "anon", "authenticated" USING (public.can_write_expense("expenses"."group_id", "expenses"."recorded_by_member_id"));
--> statement-breakpoint
CREATE POLICY "payments_select" ON "payments" AS PERMISSIVE FOR SELECT TO "anon", "authenticated" USING (public.has_group_grant("payments"."group_id"));
--> statement-breakpoint
CREATE POLICY "payments_insert" ON "payments" AS PERMISSIVE FOR INSERT TO "anon", "authenticated" WITH CHECK (public.can_write_expense("payments"."group_id", (SELECT e.recorded_by_member_id FROM public.expenses e WHERE e.id = "payments"."expense_id")));
--> statement-breakpoint
CREATE POLICY "payments_update" ON "payments" AS PERMISSIVE FOR UPDATE TO "anon", "authenticated" USING (public.can_write_expense("payments"."group_id", (SELECT e.recorded_by_member_id FROM public.expenses e WHERE e.id = "payments"."expense_id"))) WITH CHECK (public.can_write_expense("payments"."group_id", (SELECT e.recorded_by_member_id FROM public.expenses e WHERE e.id = "payments"."expense_id")));
--> statement-breakpoint
CREATE POLICY "payments_delete" ON "payments" AS PERMISSIVE FOR DELETE TO "anon", "authenticated" USING (public.can_write_expense("payments"."group_id", (SELECT e.recorded_by_member_id FROM public.expenses e WHERE e.id = "payments"."expense_id")));
--> statement-breakpoint
CREATE POLICY "cost_shares_select" ON "cost_shares" AS PERMISSIVE FOR SELECT TO "anon", "authenticated" USING (public.has_group_grant("cost_shares"."group_id"));
--> statement-breakpoint
CREATE POLICY "cost_shares_insert" ON "cost_shares" AS PERMISSIVE FOR INSERT TO "anon", "authenticated" WITH CHECK (public.can_write_expense("cost_shares"."group_id", (SELECT e.recorded_by_member_id FROM public.expenses e WHERE e.id = "cost_shares"."expense_id")));
--> statement-breakpoint
CREATE POLICY "cost_shares_update" ON "cost_shares" AS PERMISSIVE FOR UPDATE TO "anon", "authenticated" USING (public.can_write_expense("cost_shares"."group_id", (SELECT e.recorded_by_member_id FROM public.expenses e WHERE e.id = "cost_shares"."expense_id"))) WITH CHECK (public.can_write_expense("cost_shares"."group_id", (SELECT e.recorded_by_member_id FROM public.expenses e WHERE e.id = "cost_shares"."expense_id")));
--> statement-breakpoint
CREATE POLICY "cost_shares_delete" ON "cost_shares" AS PERMISSIVE FOR DELETE TO "anon", "authenticated" USING (public.can_write_expense("cost_shares"."group_id", (SELECT e.recorded_by_member_id FROM public.expenses e WHERE e.id = "cost_shares"."expense_id")));
--> statement-breakpoint
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.groups TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.group_members TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.group_access_grants TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.group_member_identities TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.expenses TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.payments TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.cost_shares TO anon, authenticated;
