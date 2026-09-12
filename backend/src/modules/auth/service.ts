import { OAuth2Client } from "google-auth-library";
import { prisma } from "../../db";

const GOOGLE_PROVIDER = "google";
const GOOGLE_ISSUERS = new Set(["https://accounts.google.com", "accounts.google.com"]);
const googleClient = new OAuth2Client();

function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

export class GoogleAuthError extends Error {
  constructor(
    message: string,
    public readonly status: 401 | 503 = 401,
  ) {
    super(message);
  }
}

async function verifyGoogleToken(idToken: string) {
  const clientId = process.env.GOOGLE_CLIENT_ID;
  if (!clientId) {
    throw new GoogleAuthError("Google Sign-In is not configured", 503);
  }

  try {
    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: clientId,
    });
    const payload = ticket.getPayload();

    if (
      !payload ||
      !payload.sub ||
      !payload.email ||
      payload.email_verified !== true ||
      !payload.iss ||
      !GOOGLE_ISSUERS.has(payload.iss)
    ) {
      throw new Error("Invalid Google claims");
    }

    return payload;
  } catch (error) {
    if (error instanceof GoogleAuthError) throw error;
    throw new GoogleAuthError("Invalid Google credential");
  }
}

export class AuthService {
  static async registerUser(data: {
    email: string;
    password: string;
    display_name?: string | null;
    avatar_url?: string | null;
    promptpay_number?: string | null;
  }) {
    try {
      const email = normalizeEmail(data.email);

      // Auto-set display_name from email if not provided
      const rawName = data.display_name;
      const displayName = (rawName !== null && rawName !== undefined && rawName !== "")
        ? rawName
        : email.split("@")[0];

      const user = await prisma.$transaction(async (tx) => {
        const createdUser = await tx.users.create({
          data: {
            email,
            display_name: displayName,
            avatar_url: data.avatar_url,
            promptpay_number: data.promptpay_number,
            password_hash: await Bun.password.hash(data.password),
          },
        });

        await tx.userStats.create({
          data: { user_id: createdUser.id },
        });

        return createdUser;
      });

      const { password_hash: _passwordHash, ...safeUser } = user;
      return safeUser;
    } catch (error: any) {
      if (error.code === "P2002") {
        throw new Error("Email already registered");
      }
      throw error;
    }
  }

  static async loginUser(data: {email: string, password: string}) {
    const user = await prisma.users.findUnique({
      where: { email: normalizeEmail(data.email) },
    });
    if (!user?.password_hash) return null;
    const valid = await Bun.password.verify(data.password, user.password_hash);
    if (!valid) return null;
    const { password_hash, ...safeUser } = user;
    return safeUser;
  }

  static async loginWithGoogle(idToken: string) {
    const payload = await verifyGoogleToken(idToken);
    const email = normalizeEmail(payload.email!);
    const providerAccountId = payload.sub!;

    const linkAccount = async () => prisma.$transaction(async (tx) => {
      const linkedAccount = await tx.authAccounts.findUnique({
        where: {
          provider_provider_account_id: {
            provider: GOOGLE_PROVIDER,
            provider_account_id: providerAccountId,
          },
        },
        include: { user: true },
      });
      if (linkedAccount) return linkedAccount.user;

      const existingUser = await tx.users.findUnique({ where: { email } });
      const localUser = existingUser ?? await tx.users.create({
        data: {
          email,
          password_hash: null,
          display_name: payload.name?.trim() || email.split("@")[0],
          avatar_url: payload.picture ?? null,
        },
      });

      await tx.authAccounts.create({
        data: {
          user_id: localUser.id,
          provider: GOOGLE_PROVIDER,
          provider_account_id: providerAccountId,
        },
      });
      await tx.userStats.upsert({
        where: { user_id: localUser.id },
        update: { updated_at: new Date() },
        create: { user_id: localUser.id },
      });

      return localUser;
    });

    let user;
    try {
      user = await linkAccount();
    } catch (error: any) {
      // Two Google callbacks can arrive at almost the same time. If the
      // other transaction won the unique insert, reuse the account it made.
      if (error?.code !== "P2002") throw error;
      const linkedAccount = await prisma.authAccounts.findUnique({
        where: {
          provider_provider_account_id: {
            provider: GOOGLE_PROVIDER,
            provider_account_id: providerAccountId,
          },
        },
        include: { user: true },
      });
      if (!linkedAccount) throw error;
      user = linkedAccount.user;
    }

    const { password_hash: _passwordHash, ...safeUser } = user;
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

  static async getMe(userId: string) {
    const user = await prisma.users.findUnique({
      where: {id: userId},
    });
    if (!user) return "not found";
    const { password_hash , ...safeUser } = user;
    return safeUser;;
  }
}
