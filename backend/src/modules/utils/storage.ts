import { S3Client } from "bun";

const s3 = new S3Client({
  endpoint: `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  bucket: process.env.R2_BUCKET_NAME ?? "billgang",
  accessKeyId: process.env.R2_ACCESS_KEY_ID ?? "",
  secretAccessKey: process.env.R2_SECRET_ACCESS_KEY ?? "",
  region: "auto",
});

export const uploadSlip = async (
  data: ArrayBuffer,
  mimeType: string,
): Promise<string> => {
  const ext = mimeType.includes("png") ? "png" : "jpg";
  const key = `slips/${Date.now()}_${Math.random().toString(36).slice(2)}.${ext}`;
  await s3.file(key).write(data, { type: mimeType });
  return `${process.env.R2_PUBLIC_URL}/${key}`;
};
