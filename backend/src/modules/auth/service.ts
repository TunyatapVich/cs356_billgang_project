import { prisma } from "../../db";

export class AuthService {
  static async registerUser(data: {
    email: string;
    password: string;
    display_name?: string | null;
    avatar_url?: string | null;
    promptpay_number?: string | null;
  }) {
    try {
      const { password_hash, ...user } = await prisma.users.create({
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

  static async loginUser(email: string, password: string) {
    const user = await prisma.users.findUnique({ where: { email } });
    if (!user) return null;
    const valid = await Bun.password.verify(password, user.password_hash);
    if (!valid) return null;
    const { password_hash, ...safeUser } = user;
    return safeUser;
  }

  static async updateProfile(
    userId: string,
    data: {
      display_name?: string | null;
      avatar_url?: string | null;
      promptpay_number?: string | null;
    },
  ) {
    const { password_hash, ...user } = await prisma.users.update({
      where: { id: userId },
      data,
    });
    return user;
  }
}
