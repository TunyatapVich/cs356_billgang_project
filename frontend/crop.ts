import { Jimp } from "jimp";

async function crop() {
  console.log("Loading image...");
  const image = await Jimp.read("../lib/image/logo.png");
  console.log("Original size:", image.bitmap.width, image.bitmap.height);
  
  image.autocrop();
  console.log("Cropped size:", image.bitmap.width, image.bitmap.height);
  
  await image.write("../lib/image/logo_cropped.png");
  console.log("Saved cropped image");
}

crop().catch(console.error);
