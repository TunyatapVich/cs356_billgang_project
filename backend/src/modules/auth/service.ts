import { prisma } from "../../db"; // Your Prisma client instance

export async function registerUser(data: {
  email: string;
  password: string;
  display_name?: string | null;
  avatar_url?: string | null;
  promptpay_number?: string | null;
}) {
  try {
    const user = await prisma.users.create({
      data: {
        email: data.email,
        display_name: data.display_name,
        avatar_url: data.avatar_url,
        promptpay_number: data.promptpay_number,
        password_hash: await Bun.password.hash(data.password),
      },
    });
    return user;
  } catch (error: any) {
    if (error.code === "P2002") {
      throw new Error("Email already registered");
    }
    throw error;
  }
}
