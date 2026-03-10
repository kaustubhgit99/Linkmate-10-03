/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'ndfqysbzwckegfrmrgan.supabase.co',
        pathname: '/storage/v1/object/public/**',
      },
      // Add additional hostnames if you switch Supabase projects
    ],
  },
  // Ensure trailing slashes are consistent
  trailingSlash: false,
}

module.exports = nextConfig
