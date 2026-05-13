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
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) throw new Error("OPENAI_API_KEY not set");

  const model = process.env.OPENAI_MODEL ?? "gpt-4o-mini";
  const base64 = Buffer.from(imageBuffer).toString("base64");
  const dataUrl = `data:${mimeType};base64,${base64}`;

  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "user",
          content: [
            { type: "image_url", image_url: { url: dataUrl } },
            { type: "text", text: PROMPT },
          ],
        },
      ],
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
  if (!Array.isArray(parsed.items)) throw new Error("LLM returned no items array");
  return parsed.items.map(normalizeItem).filter((i) => i.name && i.unit_price > 0);
};
