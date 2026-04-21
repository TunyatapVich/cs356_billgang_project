-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "email" VARCHAR(255) NOT NULL,
    "password_hash" TEXT NOT NULL,
    "display_name" VARCHAR(255),
    "avatar_url" TEXT,
    "promptpay_number" VARCHAR(50),
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bills" (
    "id" UUID NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "date" TIMESTAMP(6) NOT NULL,
    "created_by" UUID NOT NULL,
    "status" VARCHAR(50) NOT NULL,
    "receipt_image_url" TEXT,
    "service_charge_pct" DECIMAL(5,2),
    "vat_pct" DECIMAL(5,2),
    "invite_code" VARCHAR(100) NOT NULL,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "bills_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bill_items" (
    "id" UUID NOT NULL,
    "bill_id" UUID NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "quantity" INTEGER NOT NULL,
    "unit_price" DECIMAL(12,2) NOT NULL,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "bill_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bill_members" (
    "id" UUID NOT NULL,
    "bill_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "role" VARCHAR(50) NOT NULL,
    "joined_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "bill_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "item_assigns" (
    "id" UUID NOT NULL,
    "bill_item_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "assigned_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "item_assigns_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payments" (
    "id" UUID NOT NULL,
    "bill_id" UUID NOT NULL,
    "from_user_id" UUID NOT NULL,
    "to_user_id" UUID NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "status" VARCHAR(50) NOT NULL,
    "slip_url" TEXT,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "payments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "bills_invite_code_key" ON "bills"("invite_code");

-- CreateIndex
CREATE INDEX "bills_created_by_idx" ON "bills"("created_by");

-- CreateIndex
CREATE INDEX "bill_items_bill_id_idx" ON "bill_items"("bill_id");

-- CreateIndex
CREATE INDEX "bill_members_bill_id_idx" ON "bill_members"("bill_id");

-- CreateIndex
CREATE INDEX "bill_members_user_id_idx" ON "bill_members"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "bill_members_bill_id_user_id_key" ON "bill_members"("bill_id", "user_id");

-- CreateIndex
CREATE INDEX "item_assigns_bill_item_id_idx" ON "item_assigns"("bill_item_id");

-- CreateIndex
CREATE INDEX "item_assigns_user_id_idx" ON "item_assigns"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "item_assigns_bill_item_id_user_id_key" ON "item_assigns"("bill_item_id", "user_id");

-- CreateIndex
CREATE INDEX "payments_bill_id_idx" ON "payments"("bill_id");

-- CreateIndex
CREATE INDEX "payments_from_user_id_idx" ON "payments"("from_user_id");

-- CreateIndex
CREATE INDEX "payments_to_user_id_idx" ON "payments"("to_user_id");

-- AddForeignKey
ALTER TABLE "bills" ADD CONSTRAINT "bills_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bill_items" ADD CONSTRAINT "bill_items_bill_id_fkey" FOREIGN KEY ("bill_id") REFERENCES "bills"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bill_members" ADD CONSTRAINT "bill_members_bill_id_fkey" FOREIGN KEY ("bill_id") REFERENCES "bills"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bill_members" ADD CONSTRAINT "bill_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "item_assigns" ADD CONSTRAINT "item_assigns_bill_item_id_fkey" FOREIGN KEY ("bill_item_id") REFERENCES "bill_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "item_assigns" ADD CONSTRAINT "item_assigns_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_bill_id_fkey" FOREIGN KEY ("bill_id") REFERENCES "bills"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_from_user_id_fkey" FOREIGN KEY ("from_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_to_user_id_fkey" FOREIGN KEY ("to_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
