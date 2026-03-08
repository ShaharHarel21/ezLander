import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db";
import { users, referrals } from "@/lib/db/schema";
import { eq } from "drizzle-orm";
import { verifyAuthToken } from "@/lib/auth-utils";

export const dynamic = "force-dynamic";

export async function GET(req: NextRequest) {
  try {
    // Require authentication
    const auth = await verifyAuthToken(req);
    if (!auth) {
      return NextResponse.json({ error: "Authentication required" }, { status: 401 });
    }

    const { searchParams } = new URL(req.url);
    const email = searchParams.get("email");

    if (!email) {
      return NextResponse.json({ error: "Email is required" }, { status: 400 });
    }

    // Verify authenticated user matches requested email
    if (email.toLowerCase() !== auth.email.toLowerCase()) {
      return NextResponse.json({ error: "Forbidden" }, { status: 403 });
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
