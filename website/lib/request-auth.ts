import { getToken } from "next-auth/jwt";
import { jwtVerify } from "jose";
import type { NextRequest } from "next/server";

const JWT_SECRET = new TextEncoder().encode(
  process.env.AUTH_SECRET || process.env.NEXTAUTH_SECRET || "fallback-secret"
);

export interface RequestUser {
  userId: string;
  email?: string;
  name?: string;
}

function coerceRequestUser(payload: {
  sub?: string | null;
  email?: string | null;
  name?: string | null;
}): RequestUser | null {
  if (!payload.sub) {
    return null;
  }

  return {
    userId: payload.sub,
    ...(payload.email ? { email: payload.email } : {}),
    ...(payload.name ? { name: payload.name } : {}),
  };
}

export async function resolveRequestUser(
  request: NextRequest
): Promise<RequestUser | null> {
  const sessionToken = await getToken({ req: request }).catch(() => null);
  const sessionUser = coerceRequestUser({
    sub: typeof sessionToken?.sub === "string" ? sessionToken.sub : null,
    email: typeof sessionToken?.email === "string" ? sessionToken.email : null,
    name: typeof sessionToken?.name === "string" ? sessionToken.name : null,
  });

  if (sessionUser) {
    return sessionUser;
  }

  const authHeader = request.headers.get("authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return null;
  }

  const bearerToken = authHeader.slice("Bearer ".length).trim();
  if (!bearerToken) {
    return null;
  }

  try {
    const { payload } = await jwtVerify(bearerToken, JWT_SECRET);
    return coerceRequestUser({
      sub: typeof payload.sub === "string" ? payload.sub : null,
      email: typeof payload.email === "string" ? payload.email : null,
      name: typeof payload.name === "string" ? payload.name : null,
    });
  } catch {
    return null;
  }
}
