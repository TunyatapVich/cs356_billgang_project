export type ParsedItem = {
  name: string;
  quantity: number;
  unit_price: number;
};

const PROMPT = (rawText: string) => `You are a Thai receipt parser.
Extract every food/drink line item from the receipt below and return ONLY valid JSON in this shape:
{"items":[{"name": string, "quantity": number, "unit_price": number}, ...]}

Rules:
- name: the menu/item name as printed (Thai or English).
- quantity: integer count of that item (default 1 if missing).
- unit_price: price per single unit, NOT line total. If only line total is shown, divide by quantity.
- Skip subtotals, service charge, VAT, totals, change, cash, payment lines.
- If you can't parse anything, return {"items":[]}.

Receipt:
"""
${rawText}
"""`;

const callOpenAI = async (rawText: string): Promise<ParsedItem[]> => {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) throw new Error("OPENAI_API_KEY not set");

  const model = process.env.OPENAI_MODEL ?? "gpt-4o-mini";

  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      response_format: { type: "json_object" },
      messages: [{ role: "user", content: PROMPT(rawText) }],
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`OpenAI responded ${res.status}: ${err}`);
  }

  const body = (await res.json()) as {
    choices?: Array<{ message?: { content?: string } }>;
  };
  const content = body.choices?.[0]?.message?.content;
  if (!content) throw new Error("OpenAI empty response");

  const parsed = JSON.parse(content) as { items?: ParsedItem[] };
  if (!Array.isArray(parsed.items))
    throw new Error("LLM returned no items array");
  return parsed.items
    .map(normalizeItem)
    .filter((i) => i.name && i.unit_price > 0);
};

const regexFallback = (rawText: string): ParsedItem[] => {
  const items: ParsedItem[] = [];
  const lines = rawText.split(/\r?\n/);
  const lineRegex = /^(.+?)\s+(?:x|X|×)?\s*(\d+)?\s+(\d+(?:[.,]\d{1,2})?)\s*$/;

  for (const raw of lines) {
    const line = raw.trim();
    if (!line) continue;
    if (
      /(total|subtotal|vat|tax|service|cash|change|รวม|ภาษี|เงินสด|ทอน)/i.test(
        line,
      )
    )
      continue;
    const m = line.match(lineRegex);
    if (!m) continue;
    const name = m[1].trim();
    const quantity = m[2] ? parseInt(m[2], 10) : 1;
    const total = parseFloat(m[3].replace(",", "."));
    if (!name || !isFinite(total) || total <= 0) continue;
    items.push({
      name,
      quantity,
      unit_price: quantity > 0 ? total / quantity : total,
    });
  }
  return items;
};

const normalizeItem = (item: ParsedItem): ParsedItem => ({
  name: String(item.name ?? "").trim(),
  quantity: Math.max(1, Math.floor(Number(item.quantity) || 1)),
  unit_price: Math.max(0, Number(item.unit_price) || 0),
});

export const parseReceiptText = async (
  rawText: string,
): Promise<ParsedItem[]> => {
  try {
    return await callOpenAI(rawText);
  } catch (err) {
    console.warn(
      "[ocr] LLM failed, using regex fallback:",
      (err as Error).message,
    );
    return regexFallback(rawText);
  }
};
