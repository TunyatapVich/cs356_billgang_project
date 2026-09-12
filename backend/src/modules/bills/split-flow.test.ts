import { describe, expect, test } from "bun:test";

process.env.DATABASE_URL ??= "postgresql://billgang:billgang@127.0.0.1:5432/billgang";
process.env.JWT_SECRET ??= "test-secret";

const stamp = `${Date.now()}`;

describe("split bill end-to-end", () => {
  test("add items, assign person by person, and settle debts", async () => {
    const { AuthService } = await import("../auth/service");
    const { BillService } = await import("./service");

    const alice = await AuthService.registerUser({
      email: `alice.${stamp}@billgang.test`,
      password: "password123",
      display_name: "Alice",
      promptpay_number: "0812345678",
    });
    const bob = await AuthService.registerUser({
      email: `bob.${stamp}@billgang.test`,
      password: "password123",
      display_name: "Bob",
    });
    const cara = await AuthService.registerUser({
      email: `cara.${stamp}@billgang.test`,
      password: "password123",
      display_name: "Cara",
    });

    const bill = await BillService.createBill(alice.id, {
      name: "Dinner at Joe's",
      date: new Date().toISOString(),
      vat_pct: 7,
      service_charge_pct: 10,
    });
    expect(bill.invite_code).toMatch(/^[A-Z]{3}\d{5}$/);

    await BillService.joinByCode(bob.id, bill.invite_code!);
    await BillService.joinByCode(cara.id, bill.invite_code!);

    await BillService.addItems(alice.id, bill.id, {
      items: [
        { name: "Pad Thai", quantity: 1, unit_price: 100 },
        { name: "Tom Yum", quantity: 1, unit_price: 200 },
        { name: "Beer", quantity: 2, unit_price: 80 },
        { name: "Salad", quantity: 1, unit_price: 90 },
      ],
    });

    const details = await BillService.getBill(alice.id, bill.id);
    expect(details.members).toHaveLength(3);
    expect(details.items.map((item) => item.name)).toEqual(["Pad Thai", "Tom Yum", "Beer", "Salad"]);
    const byName = Object.fromEntries(details.items.map((item) => [item.name, item]));

    await BillService.assignItem(alice.id, bill.id, byName["Pad Thai"].id, alice.id);
    await BillService.assignItem(bob.id, bill.id, byName["Tom Yum"].id, bob.id);
    await BillService.assignItem(alice.id, bill.id, byName["Beer"].id, alice.id);
    await BillService.assignItem(alice.id, bill.id, byName["Beer"].id, bob.id);
    await BillService.assignItem(cara.id, bill.id, byName["Salad"].id, alice.id);
    await BillService.assignItem(cara.id, bill.id, byName["Salad"].id, bob.id);
    await BillService.assignItem(cara.id, bill.id, byName["Salad"].id, cara.id);

    await expect(
      BillService.assignItem(alice.id, bill.id, byName["Pad Thai"].id, "00000000-0000-4000-8000-000000000000"),
    ).rejects.toThrow("FORBIDDEN");

    await BillService.unassignItem(alice.id, bill.id, byName["Pad Thai"].id, alice.id);
    const afterUnassign = await BillService.getBill(alice.id, bill.id);
    const padThai = afterUnassign.items.find((item) => item.name === "Pad Thai");
    expect(padThai?.item_assigns ?? []).toHaveLength(0);
    await BillService.assignItem(alice.id, bill.id, byName["Pad Thai"].id, alice.id);

    await BillService.setPayer(alice.id, bill.id, alice.id);
    const debts = await BillService.getDebts(alice.id, bill.id);
    const owed = Object.fromEntries(debts.per_person.map((p) => [p.user.display_name, p.owed]));
    expect(owed.Alice).toBeCloseTo(247.17, 2);
    expect(owed.Bob).toBeCloseTo(364.87, 2);
    expect(owed.Cara).toBeCloseTo(35.31, 2);

    expect(debts.transfers).toHaveLength(2);
    const bobPays = debts.transfers.find((t) => t.from_user_id === bob.id && t.to_user_id === alice.id);
    const caraPays = debts.transfers.find((t) => t.from_user_id === cara.id && t.to_user_id === alice.id);
    expect(bobPays?.amount).toBeCloseTo(364.87, 2);
    expect(caraPays?.amount).toBeCloseTo(35.31, 2);
  });
});
