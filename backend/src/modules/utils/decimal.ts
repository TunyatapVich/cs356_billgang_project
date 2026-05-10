type DecimalLike =
  | number
  | string
  | null
  | undefined
  | {
      toNumber?: () => number;
      toString: () => string;
    };

export const decimalToNumber = (value: DecimalLike): number | null => {
  if (value === null || value === undefined) return null;
  if (typeof value === "number") return value;
  if (typeof value === "string") return Number(value);
  if (value.toNumber) return value.toNumber();
  return Number(value.toString());
};
