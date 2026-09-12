ALTER TABLE "users" ALTER COLUMN "password_hash" DROP NOT NULL;

CREATE TABLE "auth_accounts" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "provider" VARCHAR(50) NOT NULL,
    "provider_account_id" VARCHAR(255) NOT NULL,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "auth_accounts_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "auth_accounts_provider_provider_account_id_key"
ON "auth_accounts"("provider", "provider_account_id");

CREATE INDEX "auth_accounts_user_id_idx" ON "auth_accounts"("user_id");

ALTER TABLE "auth_accounts"
ADD CONSTRAINT "auth_accounts_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
