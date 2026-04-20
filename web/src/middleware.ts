import { NextRequest, NextResponse } from "next/server";

const SESSION_COOKIE = "quantara_admin_session";

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Protéger uniquement /dashboard et ses sous-pages
  if (pathname.startsWith("/dashboard")) {
    const session = request.cookies.get(SESSION_COOKIE);
    if (!session?.value) {
      const loginUrl = request.nextUrl.clone();
      loginUrl.pathname = "/login";
      return NextResponse.redirect(loginUrl);
    }
  }

  // Rediriger /login vers /dashboard si déjà connecté
  if (pathname === "/login") {
    const session = request.cookies.get(SESSION_COOKIE);
    if (session?.value) {
      const dashUrl = request.nextUrl.clone();
      dashUrl.pathname = "/dashboard";
      return NextResponse.redirect(dashUrl);
    }
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/dashboard/:path*", "/login"],
};
