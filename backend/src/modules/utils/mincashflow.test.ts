import { describe, expect, test } from "bun:test";
import { minCashFlow } from "./mincashflow";

describe("minCashFlow", () => {
  test("settles two people in one transfer", () => {
    expect(minCashFlow({ a: 50, b: -50 })).toEqual([{ from: "b", to: "a", amount: 50 }]);
  });

  test("ignores near-zero balances", () => {
    expect(minCashFlow({ a: 0.004, b: -0.004 })).toEqual([]);
  });

  test("reduces a three-person split to two payments", () => {
    const transfers = minCashFlow({ a: 100, b: -60, c: -40 });
    expect(transfers).toHaveLength(2);
    expect(transfers.reduce((sum, t) => sum + t.amount, 0)).toBeCloseTo(100, 2);
  });
});
