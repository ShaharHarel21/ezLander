import { NextRequest, NextResponse } from "next/server";
import bcrypt from "bcryptjs";
import { db } from "@/lib/db";
import { authUsers } from "@/lib/db/schema";
import { eq } from "drizzle-orm";
import { SignJWT } from "jose";

const JWT_SECRET = new TextEncoder().encode(
  process.env.AUTH_SECRET || process.env.NEXTAUTH_SECRET || "fallback-secret"
);

function isAdminEmail(email: string): boolean {
  const normalized = email.toLowerCase();
  const adminEmails = [
    process.env.ADMIN_EMAIL?.toLowerCase(),
    "shahar.harel200@gmail.com",
  ].filter(Boolean);

  return adminEmails.includes(normalized);
}

async function issueJWT(payload: { sub: string; email: string; name?: string | null }) {
  return new SignJWT({
    sub: payload.sub,
    email: payload.email,
    name: payload.name ?? null,
  })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(JWT_SECRET);
}

export async function POST(request: NextRequest) {
  try {
    const { email, password } = await request.json();
    const normalizedEmail = email?.toLowerCase().trim();

    if (!normalizedEmail || !password) {
      return NextResponse.json(
        { error: "Email and password are required" },
        { status: 400 }
      );
    }

    if (isAdminEmail(normalizedEmail)) {
      const hash = process.env.ADMIN_PASSWORD_HASH;
      if (!hash) {
        return NextResponse.json(
          { error: "Admin account is not configured" },
          { status: 500 }
        );
      }

      const valid = await bcrypt.compare(password, hash);
      if (!valid) {
        return NextResponse.json(
          { error: "Invalid credentials" },
          { status: 401 }
        );
      }

      const jwt = await issueJWT({
        sub: `admin:${normalizedEmail}`,
        email: normalizedEmail,
        name: "Admin",
      });

      return NextResponse.json({
        token: jwt,
        user: {
          id: `admin:${normalizedEmail}`,
          email: normalizedEmail,
          name: "Admin",
        },
      });
    }

    const user = await db.query.authUsers.findFirst({
      where: eq(authUsers.email, normalizedEmail),
    });

    if (!user || !user.passwordHash) {
      return NextResponse.json(
        { error: "Invalid credentials" },
        { status: 401 }
      );
    }

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) {
      return NextResponse.json(
        { error: "Invalid credentials" },
        { status: 401 }
      );
    }

    const jwt = await issueJWT({
      sub: user.id,
      email: user.email,
      name: user.name,
    });

    return NextResponse.json({
      token: jwt,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
      },
    });
  } catch (error) {
    console.error("Token issuance error:", error);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}
