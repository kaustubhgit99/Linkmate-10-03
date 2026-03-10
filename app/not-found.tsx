import Link from 'next/link'

export default function NotFound() {
  return (
    <div className="min-h-screen hero-bg flex items-center justify-center px-4">
      <div className="text-center text-white">
        <div className="text-8xl font-display font-bold gradient-text mb-4">404</div>
        <h1 className="text-3xl font-display font-bold mb-3">Page not found</h1>
        <p className="text-white/60 mb-8">
          The page you're looking for doesn't exist or has been moved.
        </p>
        <Link
          href="/"
          className="inline-flex items-center gap-2 px-6 py-3 rounded-xl bg-gradient-to-r from-violet-600 to-indigo-600 text-white font-semibold hover:from-violet-700 hover:to-indigo-700 transition-all shadow-lg shadow-violet-500/30"
        >
          Go Home
        </Link>
      </div>
    </div>
  )
}
