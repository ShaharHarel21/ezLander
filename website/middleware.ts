import { NextRequest, NextResponse } from "next/server";
import { rateLimit } from "@/lib/rate-limit";

const RATE_LIMITS: Record<string, { limit: number; windowMs: number }> = {
  "/api/auth": { limit: 5, windowMs: 60_000 },
  "/api/ai": { limit: 30, windowMs: 60_000 },
  "/api/stripe": { limit: 10, windowMs: 60_000 },
  "/api/referral": { limit: 10, windowMs: 60_000 },
};

const DEFAULT_LIMIT = { limit: 60, windowMs: 60_000 };

function getClientIp(request: NextRequest): string {
  // On Vercel, use the platform-verified IP header first
  const vercelIp = request.headers.get("x-vercel-forwarded-for");
  if (vercelIp) return vercelIp.split(",")[0]?.trim() || "anonymous";

  // Fallback: use the last IP in x-forwarded-for (added by outermost trusted proxy)
  const xff = request.headers.get("x-forwarded-for");
  if (xff) {
    const ips = xff.split(",").map((s) => s.trim()).filter(Boolean);
    return ips[ips.length - 1] || "anonymous";
  }

  return request.headers.get("x-real-ip") || "anonymous";
}

function getRateConfig(pathname: string) {
  for (const [prefix, config] of Object.entries(RATE_LIMITS)) {
    if (pathname.startsWith(prefix)) return config;
  }
  return DEFAULT_LIMIT;
}

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Only rate-limit API routes
  if (!pathname.startsWith("/api")) {
    return NextResponse.next();
  }

  // Skip webhook (Stripe verifies via signature)
  if (pathname === "/api/stripe/webhook") {
    return NextResponse.next();
  }

  const ip = getClientIp(request);
  const config = getRateConfig(pathname);
  const identifier = `${ip}:${pathname.split("/").slice(0, 3).join("/")}`;

  try {
    const result = await rateLimit(identifier, config.limit, config.windowMs);

    if (!result.success) {
      return NextResponse.json(
        { error: "Too many requests. Please try again later." },
        {
          status: 429,
          headers: {
            "Retry-After": String(Math.ceil(config.windowMs / 1000)),
            "X-RateLimit-Limit": String(config.limit),
            "X-RateLimit-Remaining": "0",
          },
        }
      );
    }

    const response = NextResponse.next();
    response.headers.set("X-RateLimit-Limit", String(config.limit));
    response.headers.set("X-RateLimit-Remaining", String(result.remaining));
    return response;
  } catch (error) {
    // Fail open — allow the request if rate limiter errors
    console.error("Rate limiter error:", error);
    return NextResponse.next();
  }
}

export const config = {
  matcher: "/api/:path*",
};
