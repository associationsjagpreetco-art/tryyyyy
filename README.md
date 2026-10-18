# ClinicRemind — Vercel deployment edition

A premium, mobile-first multi-clinic appointment and reminder demo built with Next.js App Router, TypeScript, Tailwind CSS, Prisma, PostgreSQL, Framer Motion and lucide-react.

> **Privacy note:** this is still a demo starter, not a production-ready medical-record system. Do not store real patient data until authentication, clinic-scoped authorization, audit logging, rate limiting, backups and privacy/legal requirements have been implemented and reviewed.

## Deploy on Vercel

### 1. Create a managed PostgreSQL database

Create a database with Neon or Supabase. Keep both connection strings private:

- `DATABASE_URL`: pooled/runtime URL (Neon pooler URL is recommended).
- `DIRECT_URL`: direct, non-pooled URL used by Prisma migrations.

For both URLs, follow your provider's required SSL query parameters. Never commit `.env` or expose either URL in client-side code.

### 2. Import the repository into Vercel

Push this folder to a Git repository, import it into Vercel, and set the project root to `clinicremind` if the repository has a parent folder. Framework preset: **Next.js**. The build script runs `prisma generate`, `prisma migrate deploy`, and `next build`; migrations are therefore applied during a deployment build and require `DATABASE_URL` and `DIRECT_URL` to be configured first.

Set these Vercel environment variables for each environment you deploy:

- `DATABASE_URL` — pooled PostgreSQL connection string.
- `DIRECT_URL` — direct PostgreSQL connection string.
- `NEXT_PUBLIC_APP_URL` — exact deployed origin, e.g. `https://your-project.vercel.app`.
- `CRON_SECRET` — a long random secret; use a different value per environment.
- `WHATSAPP_PROVIDER=mock` — keep mock mode enabled unless a real provider is fully implemented and verified.

Redeploy after setting variables. Vercel will build and apply the checked-in migration. Do not use `prisma db push` against production; use migrations.

### 3. Seed demo data once

The seed command deletes and recreates all ClinicRemind demo records, so **never run it against a database containing real records**. For a one-time demo seed, use a trusted local machine with the production environment variables loaded, then run:

```bash
npm install
npx prisma migrate deploy
npm run db:seed
```

Alternatively seed a separate preview/demo database. Do not expose the seed/reset command as a public HTTP endpoint. The dashboard reset dialog explains the safe local reset workflow.

### 4. Reminder scheduler

`GET /api/cron/reminders` is a scheduler-compatible endpoint protected by `Authorization: Bearer $CRON_SECRET`. It checks appointment windows for 24-hour and 1-hour reminders and avoids duplicate logs for each appointment/type. Configure a scheduler that supports the cadence your clinic needs to call this URL with the authorization header. Vercel Cron availability/cadence depends on your plan; verify current plan limits before configuring it. The endpoint uses `MockProvider` by default and logs `SIMULATED`, not delivery. A cloud-provider setting still throws an explicit integration-stub error rather than pretending to send.

### 5. Local development

```bash
cp .env.example .env
# Fill DATABASE_URL and DIRECT_URL with a development PostgreSQL database.
npm install
npm run db:deploy
npm run db:seed
npm run dev
```

Open `/dashboard`, or `/book/icare-opticals` and `/book/care-clinic`.

## Included

- PostgreSQL Prisma schema and initial migration.
- Database trigger that serializes appointment checks per clinic and rejects overlapping active appointments.
- Two fictional demo clinics, patient records, appointments, follow-ups, optical orders and bilingual templates.
- Clinic switcher, dashboard, patients/follow-ups/orders/reminders/settings screens, patient booking route and simulated reminder log.
- Protected cron-compatible reminder endpoint for appointment reminders.
- `.env.example` with separate pooled and direct connection strings.

## Still not production complete

- Authentication and authorization are not implemented. The staff UI/API routes must not be exposed with real patient records until clinic-scoped access control is added.
- Real WhatsApp Cloud API transport, approved templates, webhook signature verification, delivery receipts, retry/rate-limit handling and reply handling are not implemented.
- QR generation and A5 poster export, full patient profile CRUD, complete `YES`/`RESCHEDULE` reply simulation, scheduled follow-up/glasses-ready jobs and automated end-to-end tests still need work.
- Build and runtime tests must be run in an environment with npm registry access and a real PostgreSQL database. They could not be executed in the original generation environment, so do not treat this package as verified until Vercel's build succeeds.
- No-show chart values are illustrative (25% to 8%), not computed evidence.

## 60-second demo script

- **0–8s:** Dashboard KPIs, timeline and demo-data banner.
- **8–16s:** Switch between I Care Opticals and Care General Clinic; point out the theme/module changes.
- **16–26s:** Book a fictional patient at `/book/icare-opticals`; show the confirmation and calendar link.
- **26–36s:** Mark an appointment arrived/completed and search the patient list.
- **36–45s:** Open Follow-ups, then move an optical order to Ready.
- **45–53s:** Show Reminders and the `SIMULATED · NOT SENT` status; open Settings.
- **53–60s:** Explain that the app uses PostgreSQL on deployment and that real WhatsApp delivery and staff authentication still require implementation before real patient use.
