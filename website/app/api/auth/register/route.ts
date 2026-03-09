import { NextRequest, NextResponse } from "next/server";
import bcrypt from "bcryptjs";
import { eq } from "drizzle-orm";
import { db } from "@/lib/db";
import { authUsers } from "@/lib/db/schema";

export async function POST(request: NextRequest) {
  try {
    const { name, email, password } = await request.json();
    const normalizedEmail = email?.toLowerCase().trim();

    if (!normalizedEmail || !password) {
      return NextResponse.json(
        { error: "Email and password are required" },
        { status: 400 }
      );
    }

    if (password.length < 8) {
      return NextResponse.json(
        { error: "Password must be at least 8 characters" },
        { status: 400 }
      );
    }

    const existing = await db.query.authUsers.findFirst({
      where: eq(authUsers.email, normalizedEmail),
    });

    if (existing) {
      if (existing.passwordHash) {
        return NextResponse.json(
          { error: "An account with this email already exists" },
          { status: 409 }
        );
      }

      return NextResponse.json(
        {
          error:
            "An account with this email was created via a third-party provider. Please sign in using your original sign-in method.",
        },
        { status: 409 }
      );
    }

    const passwordHash = await bcrypt.hash(password, 12);

    await db.insert(authUsers).values({
      name: name || null,
      email: normalizedEmail,
      passwordHash,
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error("Registration error:", error);
    return NextResponse.json(
      { error: "Failed to create account" },
      { status: 500 }
    );
  }
}
