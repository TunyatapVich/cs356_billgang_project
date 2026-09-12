ALTER TABLE "bills"
ADD COLUMN "receipt_total" DECIMAL(12, 2),
ADD COLUMN "charges_included" BOOLEAN NOT NULL DEFAULT false;
