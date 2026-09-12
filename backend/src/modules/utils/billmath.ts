export const round2 = (n: number) => Math.round(n * 100) / 100;

/** Thai-style bill math: service on items, then VAT on (items + service). */
export type BillMathOptions = {
  receiptTotal?: number;
  itemSubtotal?: number;
  chargesIncluded?: boolean;
};

export function taxMultiplier(vatPct: number, servicePct: number, chargesIncluded = false) {
  if (chargesIncluded) return 1;
  return (1 + servicePct / 100) * (1 + vatPct / 100);
}

export function billLineTotals(
  subtotal: number,
  vatPct: number,
  servicePct: number,
  options: BillMathOptions = {},
) {
  if (options.chargesIncluded) {
    const vat = vatPct > 0 ? subtotal - subtotal / (1 + vatPct / 100) : 0;
    return {
      subtotal: round2(subtotal),
      service: 0,
      vat: round2(vat),
      total: round2(options.receiptTotal ?? subtotal),
    };
  }

  const expectedService = subtotal * (servicePct / 100);
  const expectedVat = (subtotal + expectedService) * (vatPct / 100);
  const expectedCharges = expectedService + expectedVat;
  const receiptTotal = options.receiptTotal;
  if (receiptTotal !== undefined && Math.abs(receiptTotal - (subtotal + expectedCharges)) > 0.005) {
    const actualCharges = Math.max(0, receiptTotal - subtotal);
    const serviceShare = expectedCharges > 0 ? expectedService / expectedCharges : 0;
    const service = actualCharges * serviceShare;
    const vat = actualCharges - service;
    return {
      subtotal: round2(subtotal),
      service: round2(service),
      vat: round2(vat),
      total: round2(receiptTotal),
    };
  }

  return {
    subtotal: round2(subtotal),
    service: round2(expectedService),
    vat: round2(expectedVat),
    total: round2(receiptTotal ?? subtotal + expectedService + expectedVat),
  };
}

export type SplitItem = {
  unit_price: number;
  quantity: number;
  assignees: (string | { user_id: string; assigned_quantity?: number | null })[];
};

export function computeExplicitItemShares(item: SplitItem) {
  const quantities: Record<string, number> = {};
  for (const assignee of item.assignees) {
    if (typeof assignee === "string") continue;
    quantities[assignee.user_id] = assignee.assigned_quantity ?? 0;
  }

  const totalAssigned = Object.values(quantities).reduce((sum, quantity) => sum + quantity, 0);
  const scale = totalAssigned > item.quantity ? item.quantity / totalAssigned : 1;
  return Object.fromEntries(
    Object.entries(quantities).map(([userId, quantity]) => [
      userId,
      item.unit_price * quantity * scale,
    ]),
  );
}

export function computePersonSubtotals(memberIds: string[], items: SplitItem[]) {
  const subtotal: Record<string, number> = {};
  for (const id of memberIds) subtotal[id] = 0;

  for (const item of items) {
    if (item.assignees.length === 0) continue;
    const hasExplicitQuantities = item.assignees.some(
      (assignee) => typeof assignee !== "string" && assignee.assigned_quantity !== null && assignee.assigned_quantity !== undefined,
    );
    if (hasExplicitQuantities) {
      for (const [userId, share] of Object.entries(computeExplicitItemShares(item))) {
        subtotal[userId] = (subtotal[userId] ?? 0) + share;
      }
      continue;
    }
    const share = (item.unit_price * item.quantity) / item.assignees.length;
    for (const assignee of item.assignees) {
      const userId = typeof assignee === "string" ? assignee : assignee.user_id;
      subtotal[userId] = (subtotal[userId] ?? 0) + share;
    }
  }

  return subtotal;
}

export function computeOwedAndBalances(
  subtotal: Record<string, number>,
  vatPct: number,
  servicePct: number,
  payerId: string,
  options: BillMathOptions = {},
) {
  const receiptMultiplier =
    options.receiptTotal !== undefined &&
    options.itemSubtotal !== undefined &&
    options.itemSubtotal > 0
      ? options.receiptTotal / options.itemSubtotal
      : undefined;
  const multiplier =
    receiptMultiplier ?? taxMultiplier(vatPct, servicePct, options.chargesIncluded);
  const owed: Record<string, number> = {};
  let totalOwed = 0;

  for (const [userId, amt] of Object.entries(subtotal)) {
    const final = amt * multiplier;
    owed[userId] = final;
    totalOwed += final;
  }

  const balances: Record<string, number> = {};
  for (const userId of Object.keys(owed)) {
    balances[userId] = -owed[userId];
  }
  balances[payerId] = (balances[payerId] ?? 0) + totalOwed;

  return { owed, balances, totalOwed };
}
