import { db } from "@/lib/db";
import { subscriptions } from "@/lib/db/schema";
import { eq, and, inArray } from "drizzle-orm";
import type { SubscriptionTier } from "@/lib/tiers";

export type SubscriptionStatus = "active" | "trialing" | "canceled" | "past_due" | "expired";
const ACTIVE_STATUSES: SubscriptionStatus[] = ["active", "trialing"];

export interface ActiveSubscription {
  tier: SubscriptionTier;
  status: string;
  stripeCustomerId: string | null;
  stripeSubscriptionId: string | null;
  currentPeriodEnd: string | null;
}

export async function getActiveSubscription(
  userId: string
): Promise<ActiveSubscription | null> {
  const sub = await db.query.subscriptions.findFirst({
    where: and(
      eq(subscriptions.userId, userId),
      inArray(subscriptions.status, ACTIVE_STATUSES)
    ),
  });

  if (!sub) return null;

  return {
    tier: sub.tier as SubscriptionTier,
    status: sub.status,
    stripeCustomerId: sub.stripeCustomerId,
    stripeSubscriptionId: sub.stripeSubscriptionId,
    currentPeriodEnd: sub.currentPeriodEnd,
  };
}

export async function upsertSubscription(
  userId: string,
  data: {
    stripeCustomerId: string;
    stripeSubscriptionId: string;
    tier: SubscriptionTier;
    status: SubscriptionStatus;
    currentPeriodEnd: string;
  }
) {
  const now = new Date().toISOString();

  const existing = await db.query.subscriptions.findFirst({
    where: eq(subscriptions.userId, userId),
  });

  if (existing) {
    await db
      .update(subscriptions)
      .set({
        stripeCustomerId: data.stripeCustomerId,
        stripeSubscriptionId: data.stripeSubscriptionId,
        tier: data.tier,
        status: data.status,
        currentPeriodEnd: data.currentPeriodEnd,
        updatedAt: now,
      })
      .where(eq(subscriptions.userId, userId));
  } else {
    await db.insert(subscriptions).values({
      userId,
      stripeCustomerId: data.stripeCustomerId,
      stripeSubscriptionId: data.stripeSubscriptionId,
      tier: data.tier,
      status: data.status,
      currentPeriodEnd: data.currentPeriodEnd,
      createdAt: now,
      updatedAt: now,
    });
  }
}

export async function updateSubscriptionStatus(
  stripeSubscriptionId: string,
  status: SubscriptionStatus,
  updates?: { tier?: SubscriptionTier; currentPeriodEnd?: string }
) {
  const now = new Date().toISOString();

  await db
    .update(subscriptions)
    .set({
      status,
      ...(updates?.tier ? { tier: updates.tier } : {}),
      ...(updates?.currentPeriodEnd
        ? { currentPeriodEnd: updates.currentPeriodEnd }
        : {}),
      updatedAt: now,
    })
    .where(eq(subscriptions.stripeSubscriptionId, stripeSubscriptionId));
}
