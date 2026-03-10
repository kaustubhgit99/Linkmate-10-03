import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

// Routes that require authentication
const PROTECTED_PREFIXES = ['/owner', '/admin', '/browse/favorites']

// Routes only for non-authenticated users
const AUTH_PREFIXES = ['/auth/login', '/auth/signup']

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  // Supabase v2 uses cookie name: sb-<project-ref>-auth-token
  // Note: our custom `storageKey: 'linkmate-auth'` only affects localStorage,
  // not HTTP cookies — the cookie name is always the sb-* pattern.
  const projectRef = 'ndfqysbzwckegfrmrgan'
  const authCookie = request.cookies.get(`sb-${projectRef}-auth-token`)
  const isLoggedIn = !!authCookie?.value

  // Redirect logged-in users away from auth pages
  if (isLoggedIn && AUTH_PREFIXES.some((prefix) => pathname.startsWith(prefix))) {
    return NextResponse.redirect(new URL('/browse', request.url))
  }

  // Redirect unauthenticated users away from protected pages
  if (!isLoggedIn && PROTECTED_PREFIXES.some((prefix) => pathname.startsWith(prefix))) {
    const loginUrl = new URL('/auth/login', request.url)
    loginUrl.searchParams.set('next', pathname)
    return NextResponse.redirect(loginUrl)
  }

  return NextResponse.next()
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon\\.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
