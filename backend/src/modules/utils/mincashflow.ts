export type Transfer = { from: string; to: string; amount: number };

const EPSILON = 0.01;
const round2 = (n: number) => Math.round(n * 100) / 100;

export const minCashFlow = (balances: Record<string, number>): Transfer[] => {
  const entries = Object.entries(balances)
    .map(([id, amt]) => ({ id, amt: round2(amt) }))
    .filter((e) => Math.abs(e.amt) > EPSILON);

  const transfers: Transfer[] = [];

  while (true) {
    let maxCreditor = -1;
    let maxDebtor = -1;

    for (let i = 0; i < entries.length; i++) {
      if (maxCreditor === -1 || entries[i].amt > entries[maxCreditor].amt) maxCreditor = i;
      if (maxDebtor === -1 || entries[i].amt < entries[maxDebtor].amt) maxDebtor = i;
    }

    if (maxCreditor === -1 || maxDebtor === -1) break;
    if (entries[maxCreditor].amt < EPSILON || entries[maxDebtor].amt > -EPSILON) break;

    const settle = Math.min(entries[maxCreditor].amt, -entries[maxDebtor].amt);
    transfers.push({
      from: entries[maxDebtor].id,
      to: entries[maxCreditor].id,
      amount: round2(settle),
    });

    entries[maxCreditor].amt = round2(entries[maxCreditor].amt - settle);
    entries[maxDebtor].amt = round2(entries[maxDebtor].amt + settle);
  }

  return transfers;
};
