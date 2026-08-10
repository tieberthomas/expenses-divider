CREATE TABLE "demo_counter" (
	"id" integer PRIMARY KEY DEFAULT 1 NOT NULL,
	"value" integer DEFAULT 0 NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
