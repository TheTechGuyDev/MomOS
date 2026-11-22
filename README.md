# MomOS

An all-in-one daily companion for mum, built with Flutter (installable web app) and Supabase.

**Live:** https://thetechguydev.github.io/MomOS/

## Modules
Tabs: **Home · Planner · Kitchen · Family · AI**, plus a private **Me** space (avatar on Home).

- **Planner**: day/week agenda, goals with check-ins, important dates, routines
- **Home manager**: household jobs, bills (pay + history), utilities, inventory, appliances
- **Kitchen**: meal timetable, grocery list from the plan, pantry with expiry, AI cook ideas, food budget and preferences
- **Family**: announcements, kids, school (homework, exams, supplies, timetable), calendar, chores, shopping with prices and history
- **Me**: MyPocket (expenses, budgets, savings), MyCloset (items, outfits, AI outfit ideas), MySpace journal (private photos), Me time
- **AI assistant**: voice or text; drafts reminders, events, shopping, bills, meals and more, saved only when she taps Add
- **Offline**: cached reads and a write queue that syncs when back online
- **Privacy**: personal money, journal and goals are private unless she shares them
- **Home**: XP, levels, streaks, daily check-in, quests with proof (note or photo), badges, Coming up, family hub
- **Kids**: feeds/meals, sleep timer, diapers (under 3), growth charts, health log, Nigeria vaccine schedule, school tasks
- **Memory**: reminders (repeat, shared), where-I-kept-it (with photos), brain dump and voice notes
- **Wellness**: mood check-ins, water, her sleep, guided breathing, gratitude journal
- **Family hub**: shared calendar, chores with assignees, live shopping list
- **Learn**: 5 Data Analysis tracks (23 lessons + quizzes), SQL Lab, Sheet Lab, AI tutor, certificates, portfolio
- **Notifications**: Gentle / Important / Alarm levels, Done & Snooze buttons, alarms re-ring until stopped, quiet hours, morning summary, "next up" lines (pg_cron → Edge Function)
- **What's next for you**: suggestions on Home based on the week's activity
- **Meal timetable**: weekly Nigerian breakfast/lunch/dinner plan with photos (Wikipedia), recipes, swap, add ingredients to shopping list
- **Symptom checker**: for mum, baby or child; urgency decided by fixed safety rules, AI adds explanations (no doses)

## Backend
- SQL migrations: `supabase/migrations/` (Row Level Security on every table)
- Edge Functions: `ai-tutor`, `send-notifications`, `notify-action`, `symptom-check`, `assistant` (in `supabase/functions/`)
- Function secrets: `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT`, `CRON_SECRET`, and `ANTHROPIC_API_KEY` or `GEMINI_API_KEY` for the tutor

## Deploy
Every push to `main` builds and deploys to GitHub Pages (`.github/workflows/deploy.yml`).
