CREATE TYPE "public"."address_type" AS ENUM('BTC', 'ETH', 'USDC', 'USDT');--> statement-breakpoint
CREATE TYPE "public"."lending_status" AS ENUM('ACTIVE', 'COMPLETED', 'TERMINATED');--> statement-breakpoint
CREATE TYPE "public"."withdrawal_status" AS ENUM('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED');--> statement-breakpoint
CREATE TABLE "address_verifications" (
	"id" serial PRIMARY KEY NOT NULL,
	"address_id" integer NOT NULL,
	"token" text NOT NULL,
	"expires_at" timestamp NOT NULL,
	"verified_at" timestamp,
	CONSTRAINT "address_verifications_token_unique" UNIQUE("token")
);
--> statement-breakpoint
CREATE TABLE "lending_positions" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" integer NOT NULL,
	"asset" text NOT NULL,
	"amount" numeric(20, 8) NOT NULL,
	"duration_days" integer NOT NULL,
	"apy" numeric(5, 2) NOT NULL,
	"status" "lending_status" DEFAULT 'ACTIVE' NOT NULL,
	"accrued_yield" numeric(20, 8) DEFAULT '0' NOT NULL,
	"start_date" timestamp DEFAULT now() NOT NULL,
	"end_date" timestamp NOT NULL
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" serial PRIMARY KEY NOT NULL,
	"email" text NOT NULL,
	"password" text NOT NULL,
	"two_factor_secret" text,
	"two_factor_enabled" boolean DEFAULT false NOT NULL,
	"two_factor_backup_codes" text,
	"created_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "users_email_unique" UNIQUE("email")
);
--> statement-breakpoint
CREATE TABLE "withdrawal_addresses" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" integer NOT NULL,
	"address" text NOT NULL,
	"address_type" "address_type" NOT NULL,
	"label" text NOT NULL,
	"is_verified" boolean DEFAULT false NOT NULL,
	"is_primary" boolean DEFAULT false NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"verified_at" timestamp,
	"deactivated_at" timestamp
);
--> statement-breakpoint
CREATE TABLE "withdrawals" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" integer NOT NULL,
	"from_address_id" integer NOT NULL,
	"amount" numeric(20, 8) NOT NULL,
	"asset" text NOT NULL,
	"to_address" text NOT NULL,
	"status" "withdrawal_status" DEFAULT 'PENDING' NOT NULL,
	"tx_hash" text,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"completed_at" timestamp,
	"failure_reason" text
);
--> statement-breakpoint
ALTER TABLE "address_verifications" ADD CONSTRAINT "address_verifications_address_id_withdrawal_addresses_id_fk" FOREIGN KEY ("address_id") REFERENCES "public"."withdrawal_addresses"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "lending_positions" ADD CONSTRAINT "lending_positions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "withdrawal_addresses" ADD CONSTRAINT "withdrawal_addresses_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "withdrawals" ADD CONSTRAINT "withdrawals_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "withdrawals" ADD CONSTRAINT "withdrawals_from_address_id_withdrawal_addresses_id_fk" FOREIGN KEY ("from_address_id") REFERENCES "public"."withdrawal_addresses"("id") ON DELETE no action ON UPDATE no action;