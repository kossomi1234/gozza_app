# Gozza app (Flutter + Supabase) - Android and iPhone

NOT TESTED YET: this code was written without a Flutter install to run it. Expect to fix small errors on the first run.

## What is included
- `lib/main.dart`: sign-in by phone code, create account (client or driver), client home with 7 services and booking, driver screen (online switch, live requests, accept). Arabic, English, French.
- `supabase/schema.sql`: tables, owner-only security rules (RLS), automatic fare calculation, private document storage, starting vehicles.

## Set up (once)
1. Create a free project at supabase.com. Pick a region close to Chad.
2. SQL Editor > paste all of `supabase/schema.sql` > Run.
3. Authentication > Providers > Phone: turn on and connect an SMS provider (for example Twilio). For testing without SMS, add "test phone numbers" with a fixed code in the same settings.
4. Authentication > turn on 2-step verification for your own Supabase account too.
5. Install Flutter (flutter.dev), then in this folder:
   ```
   flutter create --org com.gozza --project-name gozza_app .
   flutter pub get
   flutter run --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
   ```
   If `flutter create` replaces `lib/main.dart`, copy it back from the zip.
6. In VS Code you can also press F5: open `.vscode/launch.json` and put your two values there first.
7. Use only the **anon** key in the app. Never use the **service_role** key in the app or on a web page.

## Make yourself the owner
Sign up in the app once with your phone (as a client). Then in the SQL Editor run:
```
update public.profiles set role = 'owner', status = 'active' where phone = '+235XXXXXXXX';
```
Approve drivers later with: `select public.owner_set_profile('USER-ID', 'active');`

## Build the apps
- Android: `flutter build apk` (or `flutter build appbundle` for the Play Store, $25 one-time).
- iPhone: needs a Mac with Xcode and an Apple developer account ($99/year): `flutter build ipa`.

## Not built yet
Document upload screens, maps and live location, driver matching by distance, payments (mobile money), push notifications, in-app owner screens (the owner dashboard still needs to be connected to this database), staff logins, trip completion and ratings.

## Security checklist before real users
- RLS stays ON for every new table. Test with a logged-out request: it must be refused.
- Keep daily backups on. Keep documents in the private `documents` bucket.
- Have a security professional review the setup before launch.
