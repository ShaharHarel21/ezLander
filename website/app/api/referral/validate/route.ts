import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import { users } from "@/lib/db/schema";
import { eq } from "drizzle-orm";
import { REFERRAL_CAP } from "@/lib/referral";

export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  try {
    const { searchParams } = new URL(req.url);
    const code = searchParams.get("code");

    if (!code) {
      return NextResponse.json(
        { valid: false, error: "Code is required" },
        { status: 400 }
      );
    }

    const user = await db.query.users.findFirst({
      where: eq(users.referralCode, code),
    });

    if (!user) {
      return NextResponse.json({ valid: false });
    }

    if (user.referralsCount >= REFERRAL_CAP) {
      return NextResponse.json({
        valid: false,
        reason: "Referrer has reached the maximum number of referrals",
      });
    }

    const maskedEmail = user.email.replace(/^(.).+(@.+)$/, "$1***$2");

    return NextResponse.json({
      valid: true,
      referrer_email_masked: maskedEmail,
    });
  } catch (error) {
    console.error("Error in referral validate endpoint:", error);
    return NextResponse.json(
      { valid: false, error: "Internal server error" },
      { status: 500 }
    );
  }
}
