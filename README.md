# MomOS

An all-in-one daily companion for mum, built with Flutter (installable web app) and Supabase.

**Live:** https://thetechguydev.github.io/MomOS/

## Modules
- **Home**: XP, levels, streaks, daily check-in, quests with proof (note or photo), badges, Coming up, family hub
- **Kids**: feeds/meals, sleep timer, diapers (under 3), growth charts, health log, Nigeria vaccine schedule, school tasks
- **Memory**: reminders (repeat, shared), where-I-kept-it (with photos), brain dump and voice notes
- **Wellness**: mood check-ins, water, her sleep, guided breathing, gratitude journal
- **Family hub**: shared calendar, chores with assignees, live shopping list
- **Learn**: 5 Data Analysis tracks (23 lessons + quizzes), SQL Lab, Sheet Lab, AI tutor, certificates, portfolio
- **Notifications**: web push for due reminders and family events (pg_cron → Edge Function)

## Backend
- SQL migrations: `supabase/migrations/` (Row Level Security on every table)
- Edge Functions: `supabase/functions/ai-tutor`, `supabase/functions/send-notifications`
- Function secrets: `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT`, `CRON_SECRET`, and `ANTHROPIC_API_KEY` or `GEMINI_API_KEY` for the tutor

## Deploy
Every push to `main` builds and deploys to GitHub Pages (`.github/workflows/deploy.yml`).
