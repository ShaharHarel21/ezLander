export const dynamic = "force-dynamic";

import { NextRequest, NextResponse } from "next/server";
import { getActiveSubscription } from "@/lib/db/subscription-repo";
import { getUsage } from "@/lib/db/token-usage";
import { getTierTokenLimit } from "@/lib/tiers";
import { resolveRequestUser } from "@/lib/request-auth";
import { isAdminEmail } from "@/lib/auth-utils";

export async function GET(request: NextRequest) {
  try {
    const authUser = await resolveRequestUser(request);
    if (!authUser?.userId) {
      return NextResponse.json(
        { error: "Authentication required" },
        { status: 401 }
      );
    }

    if (isAdminEmail(authUser.email)) {
      return NextResponse.json({
        tier: "admin",
        period: "unlimited",
        tokens_used: 0,
        tokens_limit: -1,
        tokens_remaining: -1,
        request_count: 0,
      });
    }

    const subscription = await getActiveSubscription(authUser.userId);
    if (!subscription) {
      return NextResponse.json(
        { error: "No active subscription", code: "NO_SUBSCRIPTION" },
        { status: 403 }
      );
    }

    const usage = await getUsage(authUser.userId);
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
