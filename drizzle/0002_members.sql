CREATE TABLE members (id TEXT PRIMARY KEY NOT NULL,name TEXT NOT NULL,nik TEXT NOT NULL DEFAULT '',farmer_group TEXT NOT NULL DEFAULT '',address TEXT NOT NULL DEFAULT '',updated_at TEXT NOT NULL);
--> statement-breakpoint
ALTER TABLE records ADD COLUMN sale_kind TEXT NOT NULL DEFAULT '';
--> statement-breakpoint
ALTER TABLE records ADD COLUMN member_id TEXT NOT NULL DEFAULT '';
