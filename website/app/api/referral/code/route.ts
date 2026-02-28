import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import { users } from "@/lib/db/schema";
import { eq } from "drizzle-orm";
import { generateReferralCode } from "@/lib/referral";

export async function POST(req: Request) {
  try {
    const { email } = await req.json();

    if (!email) {
      return NextResponse.json({ error: "Email is required" }, { status: 400 });
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
