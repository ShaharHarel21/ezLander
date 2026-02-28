import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import { users, referrals } from "@/lib/db/schema";
import { eq } from "drizzle-orm";

export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  try {
    const { searchParams } = new URL(req.url);
    const email = searchParams.get("email");

    if (!email) {
      return NextResponse.json({ error: "Email is required" }, { status: 400 });
    }

    const user = await db.query.users.findFirst({
      where: eq(users.email, email),
    });

    if (!user) {
      return NextResponse.json({ error: "User not found" }, { status: 404 });
    }

    const referralHistory = await db.query.referrals.findMany({
      where: eq(referrals.referrerEmail, email),
    });

    return NextResponse.json({
      referral_code: user.referralCode,
      referral_credits_days: user.referralCreditsDays,
      referrals_count: user.referralsCount,
      referrals: referralHistory.map((r) => ({
        referred_email: r.referredEmail.replace(
          /^(.).+(@.+)$/,
          "$1***$2"
        ),
        status: r.status,
        created_at: r.createdAt,
        completed_at: r.completedAt,
      })),
    });
  } catch (error) {
    console.error("Error in referral stats endpoint:", error);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}
