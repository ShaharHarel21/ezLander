import { db } from "@/lib/db";
import { tokenUsage } from "@/lib/db/schema";
import { eq, and, sql } from "drizzle-orm";

export function getCurrentPeriod(): string {
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, "0");
  return `${year}-${month}`;
}

export async function getUsage(userId: string) {
  const period = getCurrentPeriod();

  const existing = await db.query.tokenUsage.findFirst({
    where: and(
      eq(tokenUsage.userId, userId),
      eq(tokenUsage.periodStart, period)
    ),
  });

  if (!existing) {
    return {
      promptTokens: 0,
      completionTokens: 0,
      totalTokens: 0,
      requestCount: 0,
      period,
    };
  }

  return {
    promptTokens: existing.promptTokens,
    completionTokens: existing.completionTokens,
    totalTokens: existing.totalTokens,
    requestCount: existing.requestCount,
    period,
  };
}

export async function recordUsage(
  userId: string,
  promptTokens: number,
  completionTokens: number
) {
  const period = getCurrentPeriod();
  const total = promptTokens + completionTokens;
  const now = new Date().toISOString();

  // Atomic upsert: INSERT ... ON CONFLICT ... DO UPDATE
  await db
    .insert(tokenUsage)
    .values({
      userId,
      periodStart: period,
      promptTokens,
      completionTokens,
      totalTokens: total,
      requestCount: 1,
      createdAt: now,
      updatedAt: now,
    })
    .onConflictDoUpdate({
      target: [tokenUsage.userId, tokenUsage.periodStart],
      set: {
        promptTokens: sql`${tokenUsage.promptTokens} + ${promptTokens}`,
        completionTokens: sql`${tokenUsage.completionTokens} + ${completionTokens}`,
        totalTokens: sql`${tokenUsage.totalTokens} + ${total}`,
        requestCount: sql`${tokenUsage.requestCount} + 1`,
        updatedAt: now,
      },
    });
}
