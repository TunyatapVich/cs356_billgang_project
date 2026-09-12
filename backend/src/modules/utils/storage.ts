import { S3Client } from "bun";
import sharp from "sharp";

const s3 = new S3Client({
  endpoint: `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  bucket: process.env.R2_BUCKET_NAME ?? "billgang",
  accessKeyId: process.env.R2_ACCESS_KEY_ID ?? "",
  secretAccessKey: process.env.R2_SECRET_ACCESS_KEY ?? "",
  region: "auto",
});

export const uploadImage = async (
  data: ArrayBuffer,
  mimeType: string,
  folder: string = "slips"
): Promise<string> => {
  let uploadData: Uint8Array | Buffer | ArrayBuffer = data;
  let finalMime = mimeType;
  let ext = mimeType.includes("png") ? "png" : "jpg";

  // Compress and optimize image before saving to storage (R2)
  try {
    const inputBuffer = Buffer.from(data);
    const isPng = mimeType.includes("png");
    const maxDim = folder === "avatars" ? 512 : 1600;

    let pipeline = sharp(inputBuffer).rotate(); // auto-orient based on camera EXIF

    if (folder === "avatars") {
      pipeline = pipeline.resize(maxDim, maxDim, { fit: "cover" });
    } else {
      pipeline = pipeline.resize(maxDim, maxDim, { fit: "inside", withoutEnlargement: true });
    }

    if (isPng && folder !== "avatars") {
      uploadData = await pipeline.png({ quality: 80, compressionLevel: 9 }).toBuffer();
      finalMime = "image/png";
      ext = "png";
    } else {
      uploadData = await pipeline.jpeg({ quality: 82, mozjpeg: true }).toBuffer();
      finalMime = "image/jpeg";
      ext = "jpg";
    }
  } catch (err) {
    console.warn("[storage] Image compression failed, falling back to original:", err);
  }

  const key = `${folder}/${Date.now()}_${Math.random().toString(36).slice(2)}.${ext}`;
  await s3.file(key).write(uploadData, { type: finalMime });
  return `${process.env.R2_PUBLIC_URL}/${key}`;
};

