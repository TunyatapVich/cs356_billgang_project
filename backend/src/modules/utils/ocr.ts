import { config } from "dotenv";

config({ path: ".env", quiet: true });
config({ path: "backend/.env", quiet: true });

export type ParsedItem = {
  name: string;
  quantity: number;
  unit_price: number;
};

export type ParsedReceipt = {
  items: ParsedItem[];
  store_name: string | null;
  date: string | null;
  vat_pct: number | null;
  service_charge_pct: number | null;
  subtotal: number | null;
  total: number | null;
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
  lineTotal?: number | string;
  price?: number | string;
  amount?: number | string;
  total?: number | string;
  line_total?: number | string;
};

type ParsedItemsResponse = {
  items?: RawParsedItem[];
  line_items?: RawParsedItem[];
  receipt_items?: RawParsedItem[];
  store_name?: unknown;
  store?: unknown;
  merchant_name?: unknown;
  date?: unknown;
  vat_pct?: unknown;
  vat?: unknown;
  service_charge_pct?: unknown;
  service_charge?: unknown;
  subtotal?: unknown;
  total?: unknown;
};

type NestedParsedItemsResponse = ParsedItemsResponse & {
  data?: ParsedItemsResponse;
  receipt?: ParsedItemsResponse;
};

type ChatCompletionResponse = {
  choices?: Array<{ message?: { content?: string } }>;
};

type OllamaChatResponse = {
  message?: { content?: string };
};

const OCR_PROVIDER_TIMEOUT_MS = 45_000;

async function providerFetch(input: string, init: RequestInit) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), OCR_PROVIDER_TIMEOUT_MS);
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } catch (error) {
    if (controller.signal.aborted) {
      throw new Error("OCR provider timed out");
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

// ── Prompts ───────────────────────────────────────────────────────────────────
const VISION_PROMPT = (
  rawText: string,
) => `You are an OCR tool specialized in Thai receipts.
The first image is the full receipt. If a second image is present, it is an enlarged crop of the item table.
Use the enlarged crop to read item names, and use the full receipt to confirm row order and amounts.
Use the receipt layout to confirm row order and match each amount to the item on the same row.
Return ONLY valid JSON in this exact format:
{
  "store_name": "",
  "date": "",
  "items": [
    {"name": "", "quantity": 1, "line_total": 0}
  ],
  "subtotal": 0,
  "vat_pct": null,
  "service_charge_pct": null,
  "total": 0
}

CRITICAL RULES:
- Read the ACTUAL glyphs printed in the image. DO NOT guess, translate, autocorrect, or invent names.
- "name" must be a literal transcription of the EXACT Thai text from the ITEM column.
- If any item name cannot be read confidently, return "[อ่านไม่ชัด]" for that name. Never replace it with a plausible menu name.
- Zoom in on each item row before transcribing it. Preserve unusual spellings, spaces, punctuation,
  Latin characters, and digits exactly as printed. Never substitute a plausible or well-known menu name.
- This receipt has one numeric amount printed at the far right of each item row. Use that amount as "line_total" for the item on the SAME horizontal row.
- Never shift an amount to the item above or below it, and do not omit the first item row even if its amount is close to the header.
- If both unit price and line total are printed, use the line total/AMOUNT column.
- If quantity is greater than 1, preserve the quantity and keep line_total as the total for the whole row.
- "quantity" is the number from the QTY column. Preserve quantities greater than 1.
- Include every food/drink row before the summary section.
- Verify that the sum of all line_total values equals the printed subtotal or total.
- Only include food/drink line items. Skip SUBTOTAL, VAT, SERVICE CHARGE, TOTAL rows.
${rawText.trim() ? `- An auxiliary OCR transcript is provided below. Use it only as a cross-check; the image is authoritative.
OCR transcript:
"""
${rawText}
"""` : ""}`;

const PROMPT = `You are a Thai restaurant receipt parser.
Extract receipt data from this text.
Return only JSON:
{
  "store_name": "",
  "date": "",
  "items": [
    {"name": "", "quantity": 1, "line_total": 0}
  ],
  "subtotal": 0,
  "vat_pct": null,
  "service_charge_pct": null,
  "total": 0
}

Rules:
- name: copy the item name exactly from the OCR text. Never translate, autocorrect, normalize, guess, or invent a name.
- Preserve unusual Thai spellings, spaces, punctuation, Latin characters, and digits exactly as provided.
- date: use YYYY-MM-DD when present, otherwise null.
- vat_pct and service_charge_pct: percentages printed on the receipt, otherwise null.
- Pair each amount with the item on the same row; never shift amounts between rows.
- If only one amount is shown for an item row, return it as line_total.
- If both unit price and line total are shown, return the line total/AMOUNT value as line_total.
- Verify that the sum of line_total values equals the printed subtotal or total.`;

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
  const reportedUnitPrice = toNumber(
    item.unit_price ??
      item.unitPrice ??
      item.price ??
      item["ราคา"] ??
      item["ราคาต่อหน่วย"],
  );
  const lineTotal = toNumber(
    item.line_total ??
      item.lineTotal ??
      item.amount ??
      item.total ??
      item["ยอดรวม"],
  );
  const unitPrice = reportedUnitPrice || (lineTotal > 0 ? lineTotal / quantity : 0);

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
    unit_price: Math.max(0, unitPrice),
  };
};

const asRecord = (value: unknown): Record<string, unknown> =>
  value !== null && typeof value === "object" ? value as Record<string, unknown> : {};

const firstDefined = (sources: Record<string, unknown>[], keys: string[]) => {
  for (const source of sources) {
    for (const key of keys) {
      if (source[key] !== undefined && source[key] !== null) return source[key];
    }
  }
  return undefined;
};

const optionalNumber = (value: unknown): number | null => {
  if (value === undefined || value === null || String(value).trim() === "") return null;
  const number = toNumber(value);
  return Number.isFinite(number) ? number : null;
};

const optionalPercentage = (value: unknown): number | null => {
  const number = optionalNumber(value);
  return number !== null && number >= 0 && number <= 100 ? number : null;
};

const normalizeReceiptDate = (value: unknown): string | null => {
  if (value === undefined || value === null) return null;
  const text = String(value).trim();
  if (!text) return null;

  const localDate = text.match(/^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$/);
  if (localDate) {
    const [, day, month, rawYear] = localDate;
    const year = Number(rawYear) > 2400 ? Number(rawYear) - 543 : Number(rawYear);
    const date = new Date(Date.UTC(year, Number(month) - 1, Number(day)));
    if (
      date.getUTCFullYear() === year &&
      date.getUTCMonth() === Number(month) - 1 &&
      date.getUTCDate() === Number(day)
    ) {
      return date.toISOString().slice(0, 10);
    }
  }

  const date = new Date(text);
  return Number.isNaN(date.getTime()) ? null : date.toISOString().slice(0, 10);
};

const emptyReceipt = (items: ParsedItem[]): ParsedReceipt => ({
  items,
  store_name: null,
  date: null,
  vat_pct: null,
  service_charge_pct: null,
  subtotal: null,
  total: null,
});

const parseItems = (content: string): ParsedReceipt => {
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
  const response = Array.isArray(parsed) ? null : parsed;
  const items = Array.isArray(parsed)
    ? parsed
    : response?.items ??
      response?.line_items ??
      response?.receipt_items ??
      response?.data?.items ??
      response?.receipt?.items;
  if (!Array.isArray(items))
    throw new Error("LLM returned no items array");

  const sources = response
    ? [response, asRecord(response.data), asRecord(response.receipt)]
    : [];
  const normalizedItems = items
    .map(normalizeItem)
    .filter((i) => i.name && i.unit_price > 0);
  const vatPct = optionalPercentage(firstDefined(sources, ["vat_pct", "vat_percentage", "vat"]));
  const serviceChargePct = optionalPercentage(
    firstDefined(sources, ["service_charge_pct", "service_charge_percentage", "service_charge", "service"]),
  );

  return {
    ...emptyReceipt(normalizedItems),
    store_name: String(
      firstDefined(sources, ["store_name", "merchant_name", "store", "merchant"]) ?? "",
    ).trim() || null,
    date: normalizeReceiptDate(firstDefined(sources, ["date", "receipt_date", "transaction_date"])),
    vat_pct: vatPct,
    service_charge_pct: serviceChargePct,
    subtotal: optionalNumber(firstDefined(sources, ["subtotal", "sub_total"])),
    total: optionalNumber(firstDefined(sources, ["total", "grand_total"])),
  };
};

// ── Vision providers ─────────────────────────────────────────────────────────
const tryGroqVisionWithModel = async (
  model: string,
  rawText: string,
  imageBase64: string,
  imageMimeType: string,
): Promise<ParsedReceipt> => {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) throw new Error("GROQ_API_KEY not set");

  const res = await providerFetch("https://api.groq.com/openai/v1/chat/completions", {
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
): Promise<ParsedReceipt> => {
  const primaryModel = process.env.GROQ_VISION_MODEL ?? "meta-llama/llama-4-scout-17b-16e-instruct";
  const fallbackModel = "llama-3.2-11b-vision-preview";

  try {
    return await tryGroqVisionWithModel(primaryModel, rawText, imageBase64, imageMimeType);
  } catch (err) {
    console.warn(`[ocr] Vision primary (${primaryModel}) failed, trying fallback:`, (err as Error).message);
    return await tryGroqVisionWithModel(fallbackModel, rawText, imageBase64, imageMimeType);
  }
};

const callOllama = async (
  rawText: string,
  imageBase64?: string,
): Promise<ParsedReceipt> => {
  const apiKey = process.env.OLLAMA_API_KEY;
  if (!apiKey) throw new Error("OLLAMA_API_KEY not set");

  const model = process.env.OLLAMA_OCR_MODEL ?? "gemma4:31b-cloud";
  const baseUrl = (process.env.OLLAMA_BASE_URL ?? "https://ollama.com").replace(/\/$/, "");
  const content = imageBase64
    ? VISION_PROMPT(rawText)
    : `${PROMPT}\n\nOCR text from receipt:\n"""\n${rawText}\n"""`;
  const message: Record<string, unknown> = {
    role: "user",
    content,
  };
  if (imageBase64) message.images = [imageBase64];

  const res = await providerFetch(`${baseUrl}/api/chat`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      messages: [message],
      stream: false,
      options: { temperature: 0, num_predict: 1024 },
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Ollama (${model}) responded ${res.status}: ${err}`);
  }

  const body = (await res.json()) as OllamaChatResponse;
  const responseContent = body.message?.content;
  if (!responseContent) throw new Error(`Ollama (${model}) empty response`);
  return parseItems(responseContent);
};

const callVision = async (
  rawText: string,
  imageBase64: string,
  imageMimeType: string,
): Promise<ParsedReceipt> => {
  const provider = process.env.OCR_PROVIDER ?? (process.env.OLLAMA_API_KEY ? "ollama" : "groq");
  return provider === "ollama"
    ? callOllama(rawText, imageBase64)
    : callGroqVision(
        rawText,
        imageBase64,
        imageMimeType,
      );
};


// ── Groq text — llama-3.3-70b-versatile ──────────────────────────────────────
const callGroqText = async (rawText: string): Promise<ParsedReceipt> => {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) throw new Error("GROQ_API_KEY not set");
  const model = process.env.GROQ_MODEL ?? "llama-3.3-70b-versatile";

  const res = await providerFetch("https://api.groq.com/openai/v1/chat/completions", {
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

const callText = async (rawText: string): Promise<ParsedReceipt> => {
  const provider = process.env.OCR_PROVIDER ?? (process.env.OLLAMA_API_KEY ? "ollama" : "groq");
  return provider === "ollama" ? callOllama(rawText) : callGroqText(rawText);
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
): Promise<ParsedReceipt> => {
  const regexItems = regexFallback(rawText);
  const looseRegexItems = regexFallback(rawText, { allowUnnamedRows: true });
  const expectedItemCount = Math.max(regexItems.length, looseRegexItems.length);

  // 1) Configured vision provider — best for Thai image directly
  if (imageBase64) {
    try {
      const parsed = await callVision(rawText, imageBase64, imageMimeType);
      if (isCompleteEnough(parsed.items, expectedItemCount)) return parsed;
      console.warn(`[ocr] Groq Vision returned ${parsed.items.length}/${expectedItemCount} items.`);
    } catch (err) {
      console.warn("[ocr] Groq Vision failed, trying Groq Text:", (err as Error).message);
    }
  }

  // 2) Configured text provider — always try if rawText has content
  if (rawText.trim()) {
    try {
      const parsed = await callText(rawText);
      if (isCompleteEnough(parsed.items, expectedItemCount)) return parsed;
      console.warn(`[ocr] Groq Text returned ${parsed.items.length}/${expectedItemCount} items, trying regex`);
    } catch (err) {
      console.warn("[ocr] Groq Text failed, using regex fallback:", (err as Error).message);
    }
  }

  // 3) Regex fallback
  if (regexItems.length > 0) return emptyReceipt(regexItems);
  if (looseRegexItems.length > 0) return emptyReceipt(looseRegexItems);

  console.warn("[ocr] No receipt items detected.");
  return emptyReceipt([]);
};
