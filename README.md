# LinkMate 🏠

**Find rooms. Meet owners. Move in.**

A full-stack room-rental platform built with Next.js 14 (App Router), Supabase, Tailwind CSS, and Framer Motion.

---

## Quick Start

### 1. Clone & Install
```bash
git clone <your-repo>
cd linkmate
npm install
```

### 2. Environment Variables
Copy the example file and fill in your Supabase credentials:
```bash
cp .env.example .env.local
```

Then edit `.env.local`:
```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

### 3. Set Up Database
1. Go to your [Supabase dashboard](https://supabase.com/dashboard)
2. Open **SQL Editor**
3. Paste the contents of `database.sql` and click **Run**

### 4. Run Development Server
```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

---

## Roles

| Role      | Can do                                             |
|-----------|----------------------------------------------------|
| `citizen` | Browse rooms, save favourites, contact owners      |
| `owner`   | List rooms, upload photos, manage availability     |
| `admin`   | Full platform moderation — manage users & listings |

**To make yourself admin** (after signing up), run this in Supabase SQL Editor:
```sql
UPDATE public.users SET role = 'admin' WHERE email = 'your@email.com';
```

---

## Deploy to Vercel

1. Push to GitHub
2. Import repo in [Vercel](https://vercel.com)
3. Add the same environment variables from `.env.local`
4. Click **Deploy**

---

## Tech Stack

- **Framework**: Next.js 14 (App Router)
- **Database**: Supabase (PostgreSQL + RLS)
- **Storage**: Supabase Storage
- **Auth**: Supabase Auth
- **UI**: Tailwind CSS + shadcn/ui primitives
- **Animations**: Framer Motion
- **Icons**: Lucide React
- **Fonts**: Syne + Plus Jakarta Sans
