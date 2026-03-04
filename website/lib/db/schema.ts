import {
  sqliteTable,
  text,
  integer,
  primaryKey,
  uniqueIndex,
} from "drizzle-orm/sqlite-core";
import { sql } from "drizzle-orm";
import type { AdapterAccountType } from "next-auth/adapters";

// ── Existing referral tables (unchanged) ──────────────────────────────

export const users = sqliteTable("users", {
  email: text("email").primaryKey(),
  referralCode: text("referral_code").unique().notNull(),
  referralCreditsDays: integer("referral_credits_days").default(0).notNull(),
  referralsCount: integer("referrals_count").default(0).notNull(),
  creditsActivatedAt: text("credits_activated_at"),
  createdAt: text("created_at")
    .default(sql`(current_timestamp)`)
    .notNull(),
});

export const referrals = sqliteTable("referrals", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  referrerEmail: text("referrer_email")
    .references(() => users.email)
    .notNull(),
  referredEmail: text("referred_email").notNull(),
  status: text("status", { enum: ["pending", "completed"] })
    .default("pending")
    .notNull(),
  createdAt: text("created_at")
    .default(sql`(current_timestamp)`)
    .notNull(),
  completedAt: text("completed_at"),
});

// ── Auth.js tables ────────────────────────────────────────────────────

export const authUsers = sqliteTable("auth_user", {
  id: text("id")
    .primaryKey()
    .$defaultFn(() => crypto.randomUUID()),
  name: text("name"),
  email: text("email").unique().notNull(),
  emailVerified: integer("emailVerified", { mode: "timestamp_ms" }),
  image: text("image"),
  passwordHash: text("password_hash"),
});

export const accounts = sqliteTable(
  "account",
  {
    userId: text("userId")
      .notNull()
      .references(() => authUsers.id, { onDelete: "cascade" }),
    type: text("type").$type<AdapterAccountType>().notNull(),
    provider: text("provider").notNull(),
    providerAccountId: text("providerAccountId").notNull(),
    refresh_token: text("refresh_token"),
    access_token: text("access_token"),
    expires_at: integer("expires_at"),
    token_type: text("token_type"),
    scope: text("scope"),
    id_token: text("id_token"),
    session_state: text("session_state"),
  },
  (account) => ({
    compoundKey: primaryKey({
      columns: [account.provider, account.providerAccountId],
    }),
  })
);

export const verificationTokens = sqliteTable(
  "verification_token",
  {
    identifier: text("identifier").notNull(),
    token: text("token").notNull(),
    expires: integer("expires", { mode: "timestamp_ms" }).notNull(),
  },
  (vt) => ({
    compoundKey: primaryKey({
      columns: [vt.identifier, vt.token],
    }),
  })
);

// ── Subscription & token usage tables ────────────────────────────────

export const subscriptions = sqliteTable(
  "subscriptions",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    userId: text("user_id")
      .references(() => authUsers.id)
      .notNull(),
    stripeCustomerId: text("stripe_customer_id"),
    stripeSubscriptionId: text("stripe_subscription_id"),
    tier: text("tier", { enum: ["pro", "max"] }).notNull(),
    status: text("status", {
      enum: ["active", "trialing", "canceled", "past_due", "expired"],
    })
      .default("active")
      .notNull(),
    currentPeriodEnd: text("current_period_end"),
    createdAt: text("created_at")
      .default(sql`(current_timestamp)`)
      .notNull(),
    updatedAt: text("updated_at")
      .default(sql`(current_timestamp)`)
      .notNull(),
  },
  (table) => ({
    userIdIdx: uniqueIndex("subscriptions_user_id_idx").on(table.userId),
  })
);

export const tokenUsage = sqliteTable(
  "token_usage",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    userId: text("user_id")
      .references(() => authUsers.id)
      .notNull(),
    periodStart: text("period_start").notNull(), // "YYYY-MM" format
    promptTokens: integer("prompt_tokens").default(0).notNull(),
    completionTokens: integer("completion_tokens").default(0).notNull(),
    totalTokens: integer("total_tokens").default(0).notNull(),
    requestCount: integer("request_count").default(0).notNull(),
    createdAt: text("created_at")
      .default(sql`(current_timestamp)`)
      .notNull(),
    updatedAt: text("updated_at")
      .default(sql`(current_timestamp)`)
      .notNull(),
  },
  (table) => ({
    userPeriodIdx: uniqueIndex("token_usage_user_period_idx").on(
      table.userId,
      table.periodStart
    ),
  })
);
