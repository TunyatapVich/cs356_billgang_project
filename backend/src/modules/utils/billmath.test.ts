import { describe, expect, test } from "bun:test";
import {
  billLineTotals,
  computeOwedAndBalances,
  computePersonSubtotals,
  taxMultiplier,
} from "./billmath";
import { minCashFlow } from "./mincashflow";

describe("bill math", () => {
  test("applies service then VAT", () => {
    expect(taxMultiplier(7, 10)).toBeCloseTo(1.177, 6);
    expect(billLineTotals(1000, 7, 10)).toEqual({
      subtotal: 1000,
      service: 100,
      vat: 77,
      total: 1177,
    });
  });

  test("does not add VAT when receipt prices already include charges", () => {
    expect(billLineTotals(685, 7, 0, { receiptTotal: 685, chargesIncluded: true })).toEqual({
      subtotal: 685,
      service: 0,
      vat: 44.81,
      total: 685,
    });
  });

  test("uses the printed receipt total when it differs from the formula", () => {
    expect(billLineTotals(100, 7, 10, { receiptTotal: 115 })).toEqual({
      subtotal: 100,
      service: 8.47,
      vat: 6.53,
      total: 115,
    });
  });

  test("splits shared items equally and ignores unassigned items", () => {
    const subtotal = computePersonSubtotals(["a", "b", "c"], [
      { unit_price: 100, quantity: 1, assignees: ["a"] },
      { unit_price: 200, quantity: 1, assignees: ["b"] },
      { unit_price: 80, quantity: 2, assignees: ["a", "b"] },
      { unit_price: 90, quantity: 1, assignees: ["a", "b", "c"] },
      { unit_price: 50, quantity: 1, assignees: [] },
    ]);
    expect(subtotal).toEqual({ a: 210, b: 310, c: 30 });
  });

  test("calculates explicit unit assignments", () => {
    const subtotal = computePersonSubtotals(["a", "b", "c"], [
      {
        unit_price: 100,
        quantity: 5,
        assignees: [
          { user_id: "a", assigned_quantity: 3 },
          { user_id: "b", assigned_quantity: 1 },
          { user_id: "c", assigned_quantity: 1 },
        ],
      },
    ]);
    expect(subtotal).toEqual({ a: 300, b: 100, c: 100 });
  });

  test("splits shared consumption proportionally when people overlap", () => {
    const subtotal = computePersonSubtotals(["a", "b"], [
      {
        unit_price: 40,
        quantity: 2,
        assignees: [
          { user_id: "a", assigned_quantity: 2 },
          { user_id: "b", assigned_quantity: 2 },
        ],
      },
    ]);
    expect(subtotal).toEqual({ a: 40, b: 40 });
  });

  test("computes person-by-person debts and min cash flow", () => {
    const subtotal = { a: 210, b: 310, c: 30 };
    const { owed, balances } = computeOwedAndBalances(subtotal, 7, 10, "a");
    expect(owed.a).toBeCloseTo(247.17, 2);
    expect(owed.b).toBeCloseTo(364.87, 2);
    expect(owed.c).toBeCloseTo(35.31, 2);

    const transfers = minCashFlow(balances);
    expect(transfers).toHaveLength(2);
    expect(transfers.find((t) => t.from === "b" && t.to === "a")?.amount).toBeCloseTo(364.87, 2);
    expect(transfers.find((t) => t.from === "c" && t.to === "a")?.amount).toBeCloseTo(35.31, 2);
  });

  test("allocates an inclusive receipt total proportionally", () => {
    const { totalOwed } = computeOwedAndBalances({ a: 300, b: 385 }, 7, 0, "a", {
      itemSubtotal: 685,
      receiptTotal: 685,
      chargesIncluded: true,
    });
    expect(totalOwed).toBe(685);
  });
});
