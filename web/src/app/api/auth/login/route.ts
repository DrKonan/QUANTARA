import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import crypto from "crypto";

const ADMIN_EMAIL = "dr_konan@yahoo.com";
const ADMIN_PASSWORD_HASH = crypto
  .createHash("sha256")
  .update("ASAcodeur277")
  .digest("hex");

const SESSION_COOKIE = "quantara_admin_session";
const SESSION_MAX_AGE = 60 * 60 * 24 * 7; // 7 jours

function hashPassword(password: string): string {
  return crypto.createHash("sha256").update(password).digest("hex");
}

function generateToken(): string {
  return crypto.randomBytes(32).toString("hex");
}

export async function POST(request: Request) {
  try {
    const { email, password } = await request.json();

    if (!email || !password) {
      return NextResponse.json({ error: "Email et mot de passe requis" }, { status: 400 });
    }

    if (email !== ADMIN_EMAIL || hashPassword(password) !== ADMIN_PASSWORD_HASH) {
      return NextResponse.json({ error: "Identifiants incorrects" }, { status: 401 });
    }

    const token = generateToken();
    const cookieStore = await cookies();
    cookieStore.set(SESSION_COOKIE, token, {
      httpOnly: true,
      secure: true,
      sameSite: "lax",
      path: "/",
      maxAge: SESSION_MAX_AGE,
    });

    return NextResponse.json({ success: true });
  } catch {
    return NextResponse.json({ error: "Erreur serveur" }, { status: 500 });
  }
}
