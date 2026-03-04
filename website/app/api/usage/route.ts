export const dynamic = "force-dynamic";

import { NextRequest, NextResponse } from "next/server";
import { getToken } from "next-auth/jwt";
import { getActiveSubscription } from "@/lib/db/subscription-repo";
import { getUsage } from "@/lib/db/token-usage";
import { getTierTokenLimit } from "@/lib/tiers";

export async function GET(request: NextRequest) {
  try {
    const token = await getToken({ req: request });
    if (!token?.sub) {
      return NextResponse.json(
        { error: "Authentication required" },
        { status: 401 }
      );
    }

    const userId = token.sub;

    const subscription = await getActiveSubscription(userId);
    if (!subscription) {
      return NextResponse.json(
        { error: "No active subscription", code: "NO_SUBSCRIPTION" },
        { status: 403 }
      );
    }

    const usage = await getUsage(userId);
    const tokenLimit = getTierTokenLimit(subscription.tier);
    const tokensRemaining = Math.max(0, tokenLimit - usage.totalTokens);

    return NextResponse.json({
      tier: subscription.tier,
      period: usage.period,
      tokens_used: usage.totalTokens,
      tokens_limit: tokenLimit,
      tokens_remaining: tokensRemaining,
      request_count: usage.requestCount,
    });
  } catch (error) {
    console.error("Usage query error:", error);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}
