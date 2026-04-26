import { prisma } from "../../db"; // Your Prisma client instance

export class AuthService {
  static async registerUser(data: {
    email: string;
    password: string;
    display_name?: string | null;
  }) {
    try {
      const user = await prisma.users.create({
        data: {
          email: data.email,
          display_name: data.display_name,
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
}
