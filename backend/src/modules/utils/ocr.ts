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
- Preserve Thai item names exactly. Do not transliterate Thai into Latin text.
- quantity: integer count of that item (default 1 if missing).
- unit_price: price per single unit, NOT line total. If only line total is shown, divide by quantity.
- For table receipts with columns like QTY, ITEM, PRICE, AMOUNT, each table row is one item.
- Skip subtotals, service charge, VAT, totals, change, cash, payment lines.
- If you can't parse anything, return {"items":[]}.

Receipt:
"""
${rawText}
"""`;

const VISION_PROMPT = (
  rawText: string,
) => `You are a Thai receipt OCR and parser.
Read the receipt image directly. Also use the OCR text below only as a hint because it may contain broken Thai.
Return ONLY valid JSON in this shape:
{"items":[{"name": string, "quantity": number, "unit_price": number}, ...]}

Rules:
- Extract every food/drink line item from the receipt.
- Preserve Thai item names exactly as shown in the image. Do not transliterate Thai into Latin text.
- For table receipts with columns like QTY, ITEM, PRICE, AMOUNT, each table row is one item.
- quantity is the QTY column, default 1 if missing.
- unit_price is the PRICE column. If only AMOUNT is clear, use AMOUNT / quantity.
- Skip SUBTOTAL, VAT, SERVICE CHARGE, TOTAL, payment, cashier, table, date, and header lines.
- If a Thai item name is partially unclear, infer the closest normal Thai menu name from the visible letters and price.
- If you can't parse anything, return {"items":[]}.

OCR hint:
"""
${rawText}
"""`;

const parseItems = (content: string): ParsedItem[] => {
  const parsed = JSON.parse(content) as { items?: ParsedItem[] };
  if (!Array.isArray(parsed.items))
    throw new Error("LLM returned no items array");
  return parsed.items
    .map(normalizeItem)
    .filter((i) => i.name && i.unit_price > 0);
};

const callLlamaVision = async (
  rawText: string,
  imageBase64: string,
  imageMimeType: string,
): Promise<ParsedItem[]> => {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) throw new Error("GROQ_API_KEY not set");

  const model =
    process.env.GROQ_VISION_MODEL ??
    "meta-llama/llama-4-scout-17b-16e-instruct";

  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      response_format: { type: "json_object" },
      temperature: 0,
      max_completion_tokens: 1024,
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: VISION_PROMPT(rawText) },
            {
              type: "image_url",
              image_url: {
                url: `data:${imageMimeType};base64,${imageBase64}`,
              },
            },
          ],
        },
      ],
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Groq Vision responded ${res.status}: ${err}`);
  }

  const body = (await res.json()) as {
    choices?: Array<{ message?: { content?: string } }>;
  };
  const content = body.choices?.[0]?.message?.content;
  if (!content) throw new Error("Groq Vision empty response");

  return parseItems(content);
};

const callLlama = async (rawText: string): Promise<ParsedItem[]> => {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) throw new Error("GROQ_API_KEY not set");

  const model = process.env.GROQ_MODEL ?? "llama-3.3-70b-versatile";

  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      response_format: { type: "json_object" },
      temperature: 0,
      messages: [{ role: "user", content: PROMPT(rawText) }],
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Groq responded ${res.status}: ${err}`);
  }

  const body = (await res.json()) as {
    choices?: Array<{ message?: { content?: string } }>;
  };
  const content = body.choices?.[0]?.message?.content;
  if (!content) throw new Error("Groq empty response");

  return parseItems(content);
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
  imageBase64?: string,
  imageMimeType: string = "image/jpeg",
): Promise<ParsedItem[]> => {
  if (imageBase64) {
    try {
      return await callLlamaVision(rawText, imageBase64, imageMimeType);
    } catch (err) {
      console.warn(
        "[ocr] Vision LLM failed, using text LLM fallback:",
        (err as Error).message,
      );
    }
  }

  try {
    return await callLlama(rawText);
  } catch (err) {
    console.warn(
      "[ocr] LLM failed, using regex fallback:",
      (err as Error).message,
    );
    return regexFallback(rawText);
  }
};
