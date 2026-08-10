-- Applies the first Drizzle migration and records it as applied.
-- Run this once in the Supabase SQL Editor when provisioning the project.

CREATE SCHEMA IF NOT EXISTS "drizzle";

CREATE TABLE IF NOT EXISTS "drizzle"."__drizzle_migrations" (
	"id" SERIAL PRIMARY KEY,
	"hash" text NOT NULL,
	"created_at" bigint
);

CREATE TABLE IF NOT EXISTS "demo_counter" (
	"id" integer PRIMARY KEY DEFAULT 1 NOT NULL,
	"value" integer DEFAULT 0 NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);

INSERT INTO "drizzle"."__drizzle_migrations" ("hash", "created_at")
SELECT 'e93d3c124315a2970319c8726eba6c2099003441bcc0213bfa54abc2dfc2f2e2', 1786392600000
WHERE NOT EXISTS (
	SELECT 1
	FROM "drizzle"."__drizzle_migrations"
	WHERE "hash" = 'e93d3c124315a2970319c8726eba6c2099003441bcc0213bfa54abc2dfc2f2e2'
);
