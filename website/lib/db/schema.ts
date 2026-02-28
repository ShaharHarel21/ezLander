import { sqliteTable, text, integer } from "drizzle-orm/sqlite-core";
import { sql } from "drizzle-orm";

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
