import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db";
import { users } from "@/lib/db/schema";
import { eq } from "drizzle-orm";
import { generateReferralCode } from "@/lib/referral";
import { verifyAuthToken, isValidEmail } from "@/lib/auth-utils";

export async function POST(req: NextRequest) {
  try {
    // Require authentication
    const auth = await verifyAuthToken(req);
    if (!auth) {
      return NextResponse.json({ error: "Authentication required" }, { status: 401 });
    }

    const { email } = await req.json();

    if (!email || !isValidEmail(email)) {
      return NextResponse.json({ error: "Valid email is required" }, { status: 400 });
    }

    // Verify authenticated user matches requested email
    if (email.toLowerCase() !== auth.email.toLowerCase()) {
      return NextResponse.json({ error: "Forbidden" }, { status: 403 });
    }

    const existing = await db.query.users.findFirst({
      where: eq(users.email, email),
    });

    if (existing) {
      return NextResponse.json({
        referral_code: existing.referralCode,
        referral_credits_days: existing.referralCreditsDays,
        referrals_count: existing.referralsCount,
      });
    }

    let code = generateReferralCode();
    // Ensure uniqueness
    let attempts = 0;
    while (attempts < 10) {
      const conflict = await db.query.users.findFirst({
        where: eq(users.referralCode, code),
      });
      if (!conflict) break;
      code = generateReferralCode();
      attempts++;
    }

    await db.insert(users).values({
      email,
      referralCode: code,
    });

    return NextResponse.json({
      referral_code: code,
      referral_credits_days: 0,
      referrals_count: 0,
    });
  } catch (error) {
    console.error("Error in referral code endpoint:", error);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}
