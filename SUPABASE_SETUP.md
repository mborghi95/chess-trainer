# Supabase Setup — Chess Trainer

Four steps to wire up your own Supabase project.

---

## Step 1 — Create a Supabase project

1. Go to [https://app.supabase.com](https://app.supabase.com) and sign in (free tier is fine).
2. Click **New project**, pick a name (e.g. `chess-trainer`), set a database password, choose a region.
3. Wait ~1 minute for provisioning.

---

## Step 2 — Get your URL and anon key

1. In your project dashboard, go to **Settings → API**.
2. Copy the **Project URL** (looks like `https://xyzabc.supabase.co`).
3. Copy the **anon / public** key (starts with `eyJ…`).

---

## Step 3 — Run the schema SQL

1. In your project dashboard, go to **SQL Editor → New query**.
2. Paste the contents of `supabase-schema.sql` from this repo.
3. Click **Run**. This creates the `opening_plays` and `mistakes` tables with Row Level Security enabled.

---

## Step 4 — Fill in the config in index.html

Near the top of the `<script>` block in `index.html`, find these two lines:

```js
const SUPABASE_URL      = 'YOUR_SUPABASE_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

Replace the placeholder strings with your actual values from Step 2:

```js
const SUPABASE_URL      = 'https://xyzabc.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

Save and deploy. The **Sign In** button in the top-right will now work.

---

## What you get

| Feature | Signed out | Signed in |
|---|---|---|
| Opening trainer | ✅ Full functionality | ✅ Full functionality |
| Stats tracking | ✅ localStorage only | ✅ Synced to Supabase |
| My Stats panel | ✅ Local data | ✅ Cloud data |
| Data on another device | ❌ | ✅ |
| Migrate existing local data | — | ✅ Prompted on first sign-in |

## Auth notes

- Email + password sign up requires email confirmation by default.  
  To disable this during development: Supabase Dashboard → **Authentication → Providers → Email** → turn off "Confirm email".
- Passwords must be at least 6 characters (Supabase default).
