import { config } from "dotenv";

config({ path: ".env", quiet: true });
config({ path: "backend/.env", quiet: true });

export type ParsedItem = {
  name: string;
  quantity: number;
  unit_price: number;
};

type RawParsedItem = Partial<ParsedItem> & {
  [key: string]: unknown;
  item?: string;
  item_name?: string;
  menu?: string;
  description?: string;
  qty?: number | string;
  count?: number | string;
  unitPrice?: number | string;
  price?: number | string;
  amount?: number | string;
  total?: number | string;
  line_total?: number | string;
};

type ParsedItemsResponse = {
  items?: RawParsedItem[];
  line_items?: RawParsedItem[];
  receipt_items?: RawParsedItem[];
};

type NestedParsedItemsResponse = ParsedItemsResponse & {
  data?: ParsedItemsResponse;
  receipt?: ParsedItemsResponse;
};

type ChatCompletionResponse = {
  choices?: Array<{ message?: { content?: string } }>;
};

// ── Prompts ───────────────────────────────────────────────────────────────────
const VISION_PROMPT = (
  _rawText: string,
) => `You are an OCR tool specialized in Thai receipts.
Read this receipt image carefully.
Return ONLY valid JSON in this exact format:
{
  "store_name": "",
  "date": "",
  "items": [
    {"name": "", "quantity": 1, "price": 0}
  ],
  "subtotal": 0,
  "vat": 0,
  "total": 0
}

CRITICAL RULES:
- Read the ACTUAL text printed in the image. DO NOT guess or invent names.
- "name" must be the EXACT Thai text from the ITEM column in the receipt table.
- "price" is the unit price from the PRICE column (not AMOUNT/total).
- "quantity" is the number from the QTY column.
- Only include food/drink line items. Skip SUBTOTAL, VAT, SERVICE CHARGE, TOTAL rows.`;

const PROMPT = `You are a Thai restaurant receipt parser.
Extract receipt data from this text.
Return only JSON:
{
  "store_name": "",
  "date": "",
  "items": [
    {"name": "", "quantity": 1, "price": 0}
  ],
  "subtotal": 0,
  "vat": 0,
  "total": 0
}

Rules:
- name: the menu/item name. The OCR text below is from a Latin script reader, so Thai text is missing or garbled.
- You MUST reconstruct or guess the Thai food name based on the price and garbled letters.
- If you absolutely cannot guess the food name, DO NOT return an empty string. You MUST return "รายการที่ " + index (e.g., "รายการที่ 1").
- price is the price per single unit.`;

// ── Helpers ───────────────────────────────────────────────────────────────────
const toNumber = (value: unknown): number =>
  Number(String(value ?? "").replace(",", ""));

const normalizeWhitespace = (value: string) => value.replace(/\s+/g, " ").trim();

const hasReadableName = (value: string) => /\p{L}/u.test(value);

const isReceiptNoise = (line: string) => {
  if (
    /(total|subtotal|vat|tax|service|cash|change|รวม|ภาษี|เงินสด|ทอน|ยอดรวม|ยอดสุทธิ|ค่าบริการ)/i.test(
      line,
    )
  ) {
    return true;
  }
  if (/^(table|cashier|date|time)\b/i.test(line)) return true;
  if (/^(qty|item|price|amount)(\s+(qty|item|price|amount))*$/i.test(line)) {
    return true;
  }
  return false;
};

const parseMoney = (value: string) => parseFloat(value.replace(",", "."));
const isMoneyOnly = (line: string) => /^\d+[.,]\d{1,2}$/.test(line);
const isQuantityOnly = (line: string) => /^\d+$/.test(line);

const normalizeItem = (item: RawParsedItem): ParsedItem => {
  const quantity = Math.max(
    1,
    Math.floor(
      toNumber(item.quantity ?? item.qty ?? item.count ?? item["จำนวน"]) || 1,
    ),
  );
  const unitPrice = toNumber(
    item.unit_price ??
      item.unitPrice ??
      item.price ??
      item["ราคา"] ??
      item["ราคาต่อหน่วย"],
  );
  const amount = toNumber(
    item.amount ?? item.total ?? item.line_total ?? item["ยอดรวม"],
  );

  return {
    name: String(
      item.name ??
        item.item ??
        item.item_name ??
        item.menu ??
        item.description ??
        item["ชื่อ"] ??
        item["ชื่อสินค้า"] ??
        item["รายการ"] ??
        item["เมนู"] ??
        "",
    ).trim(),
    quantity,
    unit_price: Math.max(0, unitPrice || amount / quantity || 0),
  };
};

const parseItems = (content: string): ParsedItem[] => {
  const cleaned = content
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "");
  const start = cleaned.indexOf("{");
  const end = cleaned.lastIndexOf("}");
  const arrayStart = cleaned.indexOf("[");
  const arrayEnd = cleaned.lastIndexOf("]");
  const json =
    arrayStart >= 0 &&
    (start < 0 || arrayStart < start) &&
    arrayEnd >= arrayStart
      ? cleaned.slice(arrayStart, arrayEnd + 1)
      : start >= 0 && end >= start
        ? cleaned.slice(start, end + 1)
        : cleaned;
  const parsed = JSON.parse(json) as
    | NestedParsedItemsResponse
    | RawParsedItem[];
  const items = Array.isArray(parsed)
    ? parsed
    : parsed.items ??
      parsed.line_items ??
      parsed.receipt_items ??
      parsed.data?.items ??
      parsed.receipt?.items;
  if (!Array.isArray(items))
    throw new Error("LLM returned no items array");
  return items
    .map(normalizeItem)
    .filter((i) => i.name && i.unit_price > 0);
};

// ── Groq Vision ──────────────────────────────────────────────────────────────
const tryGroqVisionWithModel = async (
  model: string,
  rawText: string,
  imageBase64: string,
  imageMimeType: string,
): Promise<ParsedItem[]> => {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) throw new Error("GROQ_API_KEY not set");

  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      temperature: 0,
      max_tokens: 1024,
      // NOTE: response_format NOT supported on vision models
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: VISION_PROMPT(rawText) },
            {
              type: "image_url",
              image_url: { url: `data:${imageMimeType};base64,${imageBase64}` },
            },
          ],
        },
      ],
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Groq Vision (${model}) responded ${res.status}: ${err}`);
  }

  const body = (await res.json()) as ChatCompletionResponse;
  const content = body.choices?.[0]?.message?.content;
  if (!content) throw new Error(`Groq Vision (${model}) empty response`);
  return parseItems(content);
};

const callGroqVision = async (
  rawText: string,
  imageBase64: string,
  imageMimeType: string,
): Promise<ParsedItem[]> => {
  const primaryModel = process.env.GROQ_VISION_MODEL ?? "meta-llama/llama-4-scout-17b-16e-instruct";
  const fallbackModel = "llama-3.2-11b-vision-preview";

  try {
    return await tryGroqVisionWithModel(primaryModel, rawText, imageBase64, imageMimeType);
  } catch (err) {
    console.warn(`[ocr] Vision primary (${primaryModel}) failed, trying fallback:`, (err as Error).message);
    return await tryGroqVisionWithModel(fallbackModel, rawText, imageBase64, imageMimeType);
  }
};


// ── Groq text — llama-3.3-70b-versatile ──────────────────────────────────────
const callGroqText = async (rawText: string): Promise<ParsedItem[]> => {
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
      temperature: 0,
      max_tokens: 1024,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "user",
          content: `${PROMPT}\n\nOCR text from receipt:\n"""\n${rawText}\n"""`,
        },
      ],
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Groq Text responded ${res.status}: ${err}`);
  }

  const body = (await res.json()) as ChatCompletionResponse;
  const content = body.choices?.[0]?.message?.content;
  if (!content) throw new Error("Groq Text empty response");
  return parseItems(content);
};

// ── Regex fallback ────────────────────────────────────────────────────────────
const regexFallback = (
  rawText: string,
  options: { allowUnnamedRows?: boolean } = {},
): ParsedItem[] => {
  const items: ParsedItem[] = [];
  const lines = rawText.split(/\r?\n/);
  const hasTableHeader = /(qty|item|price|amount)/i.test(rawText);
  const tableLineRegex =
    /^(\d+)\s+(.+?)\s+(\d+(?:[.,]\d{1,2})?)\s+(\d+(?:[.,]\d{1,2})?)$/;
  const compactTableLineRegex =
    /^(\d+)([^\d\s].*?)\s+(\d+(?:[.,]\d{1,2})?)\s+(\d+(?:[.,]\d{1,2})?)$/u;
  const numericTableLineRegex =
    /^(\d+)\s+(\d+(?:[.,]\d{1,2})?)\s+(\d+(?:[.,]\d{1,2})?)$/;
  const qtyNamePriceRegex =
    /^(\d+)\s+(.+?)\s+(\d+(?:[.,]\d{1,2})?)$/;
  const lineRegex =
    /^(.+?)\s+(?:x|X|×)?\s*(\d+)?\s+(\d+(?:[.,]\d{1,2})?)\s*$/;

  const addItem = (name: string, quantity: number, unitPrice: number) => {
    const cleanName = normalizeWhitespace(name);
    if (!cleanName || isReceiptNoise(cleanName)) return;
    if (!options.allowUnnamedRows && !hasReadableName(cleanName)) return;
    if (!isFinite(unitPrice) || unitPrice <= 0) return;
    items.push({
      name: cleanName,
      quantity: Math.max(1, Math.floor(quantity) || 1),
      unit_price: unitPrice,
    });
  };

  for (const raw of lines) {
    const line = normalizeWhitespace(raw);
    if (!line) continue;
    if (isReceiptNoise(line)) continue;

    const tableMatch =
      line.match(tableLineRegex) ?? line.match(compactTableLineRegex);
    if (tableMatch) {
      addItem(tableMatch[2], parseInt(tableMatch[1], 10), parseMoney(tableMatch[3]));
      continue;
    }

    const numericTableMatch = line.match(numericTableLineRegex);
    if (numericTableMatch) {
      if (options.allowUnnamedRows && hasTableHeader) {
        addItem(
          `Receipt item ${items.length + 1}`,
          parseInt(numericTableMatch[1], 10),
          parseMoney(numericTableMatch[2]),
        );
      }
      continue;
    }

    const qtyNamePriceMatch = line.match(qtyNamePriceRegex);
    if (qtyNamePriceMatch) {
      addItem(
        qtyNamePriceMatch[2],
        parseInt(qtyNamePriceMatch[1], 10),
        parseMoney(qtyNamePriceMatch[3]),
      );
      continue;
    }

    const m = line.match(lineRegex);
    if (!m) continue;
    const name = m[1].trim();
    const quantity = m[2] ? parseInt(m[2], 10) : 1;
    const total = parseMoney(m[3]);
    addItem(name, quantity, quantity > 0 ? total / quantity : total);
  }
  if (items.length > 0) return items;

  const splitItems = parseSplitTableLines(rawText, options);
  if (splitItems.length > 0) return splitItems;

  return parseSeparatedReceiptColumns(rawText, options);
};

const getTableCandidateLines = (rawText: string): string[] => {
  const lines: string[] = [];
  let sawTableHeader = false;
  let sawItemLikeLine = false;

  for (const raw of rawText.split(/\r?\n/)) {
    const line = normalizeWhitespace(raw);
    if (!line) continue;

    if (/(qty|item|price|amount)/i.test(line)) {
      sawTableHeader = true;
      continue;
    }

    if (
      /(total|subtotal|vat|tax|service|change|ยอดรวม|ยอดสุทธิ|ภาษี|ค่าบริการ)/i.test(line)
    ) {
      if (sawTableHeader || sawItemLikeLine) break;
      continue;
    }

    if (isReceiptNoise(line)) continue;

    lines.push(line);
    if (sawTableHeader || hasReadableName(line) || isMoneyOnly(line)) {
      sawItemLikeLine = true;
    }
  }

  return lines;
};

const parseSplitTableLines = (
  rawText: string,
  options: { allowUnnamedRows?: boolean },
): ParsedItem[] => {
  const lines = getTableCandidateLines(rawText);
  const leadingQuantities = lines.findIndex((line) => !isQuantityOnly(line));
  if (leadingQuantities >= 2) {
    const columnItems = parseColumnSplitRows(lines, options);
    if (columnItems.length > 0) return columnItems;
  }

  const sequentialItems = parseSequentialSplitRows(lines, options);
  if (sequentialItems.length > 0) return sequentialItems;

  return parseColumnSplitRows(lines, options);
};

const makeParsedItem = (
  name: string,
  quantity: number,
  unitPrice: number,
  options: { allowUnnamedRows?: boolean },
): ParsedItem | null => {
  const cleanName = normalizeWhitespace(name);
  if (!cleanName && !options.allowUnnamedRows) return null;
  if (cleanName && isReceiptNoise(cleanName)) return null;
  if (!options.allowUnnamedRows && !hasReadableName(cleanName)) return null;
  if (!isFinite(unitPrice) || unitPrice <= 0) return null;

  return {
    name: cleanName,
    quantity: Math.max(1, Math.floor(quantity) || 1),
    unit_price: unitPrice,
  };
};

const parseSequentialSplitRows = (
  lines: string[],
  options: { allowUnnamedRows?: boolean },
): ParsedItem[] => {
  const items: ParsedItem[] = [];

  for (let i = 0; i < lines.length; ) {
    if (!isQuantityOnly(lines[i])) {
      i += 1;
      continue;
    }

    const quantity = parseInt(lines[i], 10);
    i += 1;

    const nameParts: string[] = [];
    while (
      i < lines.length &&
      !isMoneyOnly(lines[i]) &&
      !isQuantityOnly(lines[i])
    ) {
      nameParts.push(lines[i]);
      i += 1;
    }

    if (i >= lines.length || !isMoneyOnly(lines[i])) continue;

    const name =
      nameParts.length > 0 ? nameParts.join(" ") : `Receipt item ${items.length + 1}`;
    const unitPrice = parseMoney(lines[i]);
    i += 1;

    if (i < lines.length && isMoneyOnly(lines[i])) {
      i += 1;
    }

    const item = makeParsedItem(name, quantity, unitPrice, options);
    if (item) items.push(item);
  }

  return items;
};

const parseColumnSplitRows = (
  lines: string[],
  options: { allowUnnamedRows?: boolean },
): ParsedItem[] => {
  const quantities = lines.filter(isQuantityOnly).map((line) => parseInt(line, 10));
  const names = lines.filter(
    (line) => !isQuantityOnly(line) && !isMoneyOnly(line) && hasReadableName(line),
  );
  const prices = lines.filter(isMoneyOnly).map(parseMoney);
  const itemCount = Math.min(names.length, prices.length);

  if (itemCount === 0) return [];

  const items: ParsedItem[] = [];
  for (let i = 0; i < itemCount; i++) {
    const item = makeParsedItem(names[i], quantities[i] ?? 1, prices[i], options);
    if (item) items.push(item);
  }

  return items;
};

const isLikelyMenuName = (line: string): boolean => {
  if (!line || isReceiptNoise(line)) return false;
  const hasThai = /\p{Script=Thai}/u.test(line);
  if (
    /(inv|invoice|date|tel|phone|tax|vat|payment|promptpay|cashier|table|address|good day cafe|cafe|thank you)/i.test(
      line,
    )
  ) {
    return false;
  }
  if (/^[A-Z0-9\s:./-]+$/.test(line)) return false;
  if (/[A-Za-z]/.test(line) && /\d/.test(line) && !hasThai) return false;
  if (/^\d/.test(line) && !hasThai) return false;
  if (isMoneyOnly(line) || isQuantityOnly(line)) return false;

  return hasReadableName(line);
};

const parseSeparatedReceiptColumns = (
  rawText: string,
  options: { allowUnnamedRows?: boolean },
): ParsedItem[] => {
  const lines = rawText.split(/\r?\n/).map(normalizeWhitespace).filter(Boolean);
  const qtyHeaderIndex = lines.findIndex((line) => /qty\s+item/i.test(line));
  const priceHeaderIndex = lines.findIndex((line) =>
    /price\s+amount/i.test(line),
  );

  if (qtyHeaderIndex < 0 || priceHeaderIndex < 0) return [];

  const itemLines = lines.slice(qtyHeaderIndex + 1, priceHeaderIndex);
  const quantities: number[] = [];
  const names: string[] = [];
  let currentNameParts: string[] = [];

  const flushName = () => {
    const name = currentNameParts.filter(isLikelyMenuName).join(" ");
    names.push(name);
    currentNameParts = [];
  };

  for (const line of itemLines) {
    if (/(subtotal|total|service|payment|promptpay|thank you|price\s+amount)/i.test(line)) {
      if (quantities.length > 0) break;
      continue;
    }

    if (/(vat|tax)/i.test(line)) {
      continue;
    }

    const inlineQuantityItem = line.match(/^(\d+)\s+(.+)$/);
    if (inlineQuantityItem && parseInt(inlineQuantityItem[1], 10) <= 20) {
      if (quantities.length > names.length) flushName();
      quantities.push(parseInt(inlineQuantityItem[1], 10));
      currentNameParts.push(inlineQuantityItem[2]);
      continue;
    }

    if (isQuantityOnly(line)) {
      if (quantities.length > names.length) flushName();
      quantities.push(parseInt(line, 10));
      continue;
    }

    if (quantities.length > names.length) {
      currentNameParts.push(line);
    }
  }
  if (quantities.length > names.length) flushName();

  const prices: number[] = [];
  for (const line of lines.slice(priceHeaderIndex + 1)) {
    if (/(payment|promptpay|cash|thank you)/i.test(line)) {
      if (prices.length > 0) break;
      continue;
    }

    if (/(subtotal|total|vat|tax|service|change|ยอดรวม|ภาษี|ค่าบริการ)/i.test(line)) {
      continue;
    }

    const numbers = line.match(/\d+(?:[.,]\d{1,2})?/g) ?? [];
    if (numbers.length === 0) continue;
    prices.push(parseMoney(numbers[0]!));
  }

  const itemCount = Math.min(
    prices.length,
    Math.max(quantities.length, names.length),
  );
  if (itemCount === 0) return [];

  if (!options.allowUnnamedRows && names.filter(Boolean).length < itemCount) {
    return [];
  }

  const items: ParsedItem[] = [];
  for (let i = 0; i < itemCount; i++) {
    const item = makeParsedItem(names[i] ?? "", quantities[i] ?? 1, prices[i], {
      ...options,
      allowUnnamedRows: true,
    });
    if (item) items.push(item);
  }

  return items;
};

// ── Main export ───────────────────────────────────────────────────────────────
const isCompleteEnough = (items: ParsedItem[], expectedCount: number) =>
  items.length > 0 && (expectedCount === 0 || items.length >= expectedCount);

export const parseReceiptText = async (
  rawText: string,
  imageBase64?: string,
  imageMimeType: string = "image/jpeg",
): Promise<ParsedItem[]> => {
  const regexItems = regexFallback(rawText);
  const looseRegexItems = regexFallback(rawText, { allowUnnamedRows: true });
  const expectedItemCount = Math.max(regexItems.length, looseRegexItems.length);

  // 1) Groq Vision (llama-3.2-90b-vision) — best for Thai image directly
  if (imageBase64) {
    try {
      const items = await callGroqVision(rawText, imageBase64, imageMimeType);
      if (isCompleteEnough(items, expectedItemCount)) return items;
      console.warn(`[ocr] Groq Vision returned ${items.length}/${expectedItemCount} items.`);
    } catch (err) {
      console.warn("[ocr] Groq Vision failed, trying Groq Text:", (err as Error).message);
    }
  }

  // 2) Groq Text (llama-3.3-70b) — always try if rawText has content
  if (rawText.trim()) {
    try {
      const items = await callGroqText(rawText);
      if (isCompleteEnough(items, expectedItemCount)) return items;
      console.warn(`[ocr] Groq Text returned ${items.length}/${expectedItemCount} items, trying regex`);
    } catch (err) {
      console.warn("[ocr] Groq Text failed, using regex fallback:", (err as Error).message);
    }
  }

  // 3) Regex fallback
  if (regexItems.length > 0) return regexItems;
  if (looseRegexItems.length > 0) return looseRegexItems;

  console.warn("[ocr] No receipt items detected.");
  return [];
};
