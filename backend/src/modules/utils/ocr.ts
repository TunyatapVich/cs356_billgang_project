export type ParsedItem = {
  name: string;
  quantity: number;
  unit_price: number;
};

const PROMPT = `You are a Thai receipt parser. Look at this receipt image carefully.
Extract every food/drink/product line item and return ONLY valid JSON in this shape:
{"items":[{"name": string, "quantity": number, "unit_price": number}, ...]}

Rules:
- name: the menu/item name as printed (Thai or English).
- quantity: integer count of that item (default 1 if missing).
- unit_price: price per single unit, NOT line total. If only line total is shown, divide by quantity.
- Skip subtotals, service charge, VAT, totals, change, cash, payment lines.
- If you can't parse anything, return {"items":[]}.`;

const normalizeItem = (item: ParsedItem): ParsedItem => ({
  name: String(item.name ?? "").trim(),
  quantity: Math.max(1, Math.floor(Number(item.quantity) || 1)),
  unit_price: Math.max(0, Number(item.unit_price) || 0),
});

export const parseReceiptImage = async (
  imageBuffer: ArrayBuffer,
  mimeType: string,
): Promise<ParsedItem[]> => {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new Error("GEMINI_API_KEY not set");

  const model = process.env.GEMINI_MODEL ?? "gemini-2.0-flash";
  const base64 = Buffer.from(imageBuffer).toString("base64");

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { inlineData: { mimeType, data: base64 } },
              { text: PROMPT },
            ],
          },
        ],
        generationConfig: { responseMimeType: "application/json" },
      }),
    },
  );

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Gemini responded ${res.status}: ${err}`);
  }

  const body = (await res.json()) as {
    candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
  };
  const content = body.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!content) throw new Error("Gemini empty response");

  const parsed = JSON.parse(content) as { items?: ParsedItem[] };
  if (!Array.isArray(parsed.items)) throw new Error("LLM returned no items array");
  return parsed.items.map(normalizeItem).filter((i) => i.name && i.unit_price > 0);
};
