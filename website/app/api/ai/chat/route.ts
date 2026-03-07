import { NextRequest, NextResponse } from "next/server";
import { getActiveSubscription } from "@/lib/db/subscription-repo";
import { getUsage, recordUsage } from "@/lib/db/token-usage";
import { getTierTokenLimit } from "@/lib/tiers";
import { resolveRequestUser } from "@/lib/request-auth";

const OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";
const MANAGED_OPENAI_MODEL = process.env.OPENAI_MODEL || "gpt-4o-mini";

function isAdminUser(email: string | null | undefined): boolean {
  if (!email) return false;
  const lower = email.toLowerCase();
  const adminEmails = [
    process.env.ADMIN_EMAIL?.toLowerCase(),
    "shahar.harel200@gmail.com",
  ].filter(Boolean);
  return adminEmails.includes(lower);
}

export async function POST(request: NextRequest) {
  try {
    // 1. Auth: verify JWT
    const authUser = await resolveRequestUser(request);
    if (!authUser?.userId) {
      return NextResponse.json(
        { error: "Authentication required" },
        { status: 401 }
      );
    }

    const userId = authUser.userId;
    const userEmail = authUser.email;
    const isAdmin = isAdminUser(userEmail);

    // 2. Subscription check (skip for admin)
    let tokenLimit = Infinity;
    let tierName = "admin";

    if (!isAdmin) {
      const subscription = await getActiveSubscription(userId);
      if (!subscription) {
        return NextResponse.json(
          { error: "Active subscription required", code: "NO_SUBSCRIPTION" },
          { status: 403 }
        );
      }
      tokenLimit = getTierTokenLimit(subscription.tier);
      tierName = subscription.tier;
    }

    // 3. Quota check (skip for admin)
    let currentUsage = { totalTokens: 0, period: "" };
    if (!isAdmin) {
      currentUsage = await getUsage(userId);
      if (currentUsage.totalTokens >= tokenLimit) {
        return NextResponse.json(
          {
            error: "Monthly token quota exceeded",
            code: "QUOTA_EXCEEDED",
            tokens_used: currentUsage.totalTokens,
            tokens_limit: tokenLimit,
          },
          { status: 429 }
        );
      }
    }

    // 4. Parse and validate request
    const body = await request.json();
    const { messages, stream } = body;

    if (!messages || !Array.isArray(messages)) {
      return NextResponse.json(
        { error: "messages are required" },
        { status: 400 }
      );
    }

    // 5. Forward to OpenAI
    const isStreaming = stream ?? false;

    const openaiBody = {
      model: MANAGED_OPENAI_MODEL,
      messages,
      temperature: body.temperature ?? 0.5,
      max_tokens: body.max_tokens ?? 2048,
      stream: isStreaming,
      ...(isStreaming ? { stream_options: { include_usage: true } } : {}),
    };

    const openaiResponse = await fetch(OPENAI_API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
      },
      body: JSON.stringify(openaiBody),
    });

    if (!openaiResponse.ok) {
      const errorText = await openaiResponse.text();
      console.error("OpenAI API error:", openaiResponse.status, errorText);
      return NextResponse.json(
        { error: "AI service error", details: errorText },
        { status: openaiResponse.status }
      );
    }

    // 6. Handle streaming response
    if (stream && openaiResponse.body) {
      const encoder = new TextEncoder();
      const decoder = new TextDecoder();

      let promptTokens = 0;
      let completionTokens = 0;

      const transformStream = new TransformStream({
        async transform(chunk, controller) {
          const text = decoder.decode(chunk);
          controller.enqueue(chunk);

          // Parse SSE lines to capture usage from the final chunk
          const lines = text.split("\n");
          for (const line of lines) {
            if (!line.startsWith("data: ")) continue;
            const jsonStr = line.slice(6).trim();
            if (jsonStr === "[DONE]") continue;
            try {
              const parsed = JSON.parse(jsonStr);
              if (parsed.usage) {
                promptTokens = parsed.usage.prompt_tokens ?? 0;
                completionTokens = parsed.usage.completion_tokens ?? 0;
              }
            } catch {
              // Not valid JSON, skip
            }
          }
        },
        async flush() {
          // Record usage after stream completes
          if (promptTokens > 0 || completionTokens > 0) {
            await recordUsage(userId, promptTokens, completionTokens).catch(
              (err) => console.error("Failed to record usage:", err)
            );
          }
        },
      });

      const stream2 = openaiResponse.body.pipeThrough(transformStream);

      const tokensRemaining = isAdmin
        ? -1
        : Math.max(0, tokenLimit - currentUsage.totalTokens);

      return new Response(stream2, {
        headers: {
          "Content-Type": "text/event-stream",
          "Cache-Control": "no-cache",
          Connection: "keep-alive",
          "X-Tokens-Used": String(currentUsage.totalTokens),
          "X-Tokens-Limit": String(tokenLimit === Infinity ? -1 : tokenLimit),
          "X-Tokens-Remaining": String(tokensRemaining),
          "X-Tier": tierName,
        },
      });
    }

    // 7. Handle non-streaming response
    const responseData = await openaiResponse.json();

    // Record usage from response
    const usage = responseData.usage;
    if (usage) {
      await recordUsage(
        userId,
        usage.prompt_tokens ?? 0,
        usage.completion_tokens ?? 0
      ).catch((err) => console.error("Failed to record usage:", err));
    }

    // Get updated usage for headers
    const updatedUsage = isAdmin
      ? { totalTokens: 0 }
      : await getUsage(userId);

    const tokensRemaining = isAdmin
      ? -1
      : Math.max(0, tokenLimit - updatedUsage.totalTokens);

    return NextResponse.json(responseData, {
      headers: {
        "X-Tokens-Used": String(updatedUsage.totalTokens),
        "X-Tokens-Limit": String(tokenLimit === Infinity ? -1 : tokenLimit),
        "X-Tokens-Remaining": String(tokensRemaining),
        "X-Tier": tierName,
      },
    });
  } catch (error) {
    console.error("AI proxy error:", error);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}
