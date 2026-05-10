const tlv = (id: string, value: string) =>
  id + value.length.toString().padStart(2, "0") + value;

const sanitizeTarget = (raw: string) => raw.replace(/\D/g, "");

const formatTarget = (raw: string): { tag: string; value: string } => {
  const digits = sanitizeTarget(raw);

  if (digits.length === 13) {
    return { tag: "02", value: digits };
  }

  let mobile = digits;
  if (mobile.startsWith("0")) {
    mobile = "66" + mobile.slice(1);
  } else if (!mobile.startsWith("66")) {
    mobile = "66" + mobile;
  }
  return { tag: "01", value: "0000" + mobile };
};

const crc16ccittFalse = (data: string): string => {
  let crc = 0xffff;
  for (let i = 0; i < data.length; i++) {
    crc ^= data.charCodeAt(i) << 8;
    for (let j = 0; j < 8; j++) {
      crc = (crc & 0x8000) !== 0 ? ((crc << 1) ^ 0x1021) & 0xffff : (crc << 1) & 0xffff;
    }
  }
  return crc.toString(16).toUpperCase().padStart(4, "0");
};

export const generatePromptPayPayload = (
  promptpayTarget: string,
  amount: number,
): string => {
  const { tag, value } = formatTarget(promptpayTarget);

  const merchantAccountInfo =
    tlv("00", "A000000677010111") + tlv(tag, value);

  const payloadWithoutCrc =
    tlv("00", "01") +
    tlv("01", "12") +
    tlv("29", merchantAccountInfo) +
    tlv("53", "764") +
    tlv("54", amount.toFixed(2)) +
    tlv("58", "TH") +
    "6304";

  return payloadWithoutCrc + crc16ccittFalse(payloadWithoutCrc);
};
