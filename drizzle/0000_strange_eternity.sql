CREATE TABLE `records` (
	`id` text PRIMARY KEY NOT NULL,
	`type` text NOT NULL,
	`date` text NOT NULL,
	`name` text NOT NULL,
	`product` text DEFAULT '' NOT NULL,
	`qty` real DEFAULT 0 NOT NULL,
	`amount` integer NOT NULL,
	`paid` integer DEFAULT 0 NOT NULL,
	`ref` text DEFAULT '' NOT NULL,
	`note` text DEFAULT '' NOT NULL
);
