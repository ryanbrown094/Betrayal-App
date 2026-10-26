# The Betrayal for iPhone (native)

A native iPhone and iPad app for **Modern**: everyone plays on their own phone, against the same game server and API as
the website. Nothing in it is a web view.

**The server is another repo:** [ryanbrown094/Betrayal-Website](https://github.com/ryanbrown094/Betrayal-Website), the Cloudflare Worker
that runs thebetrayal.co.uk (its `HANDOVER.md` explains it, §4.8 and §6.2a for the app). Paths below such as
`worker/src/modern.js` or `src/modern-ui.js` are in that repo. The tools here expect a clone of it beside this one
(`../Betrayal-Website`), or its path in `SERVER`.

Every screen of the server repo's `src/modern-ui.js` is redrawn in SwiftUI, with the palette and type of
`src/modern.css`, the art of `src/art.js` and the music of `src/audio.js`. It stands on its own: booking, joining, the TV, How to play, the terms and the privacy notice
are all in the app, so it needs the game server (the Worker's API) but none of the website's pages. Classic isn't in it.

## Run it

You need a Mac with Xcode 16 or later.

1. Clone this repo (Xcode → Integrate → Clone, `https://github.com/ryanbrown094/Betrayal-App.git`) and open
   `TheBetrayal.xcodeproj`.
2. Pick an iPhone simulator at the top of the window and press **Run** (⌘R).

**On your own iPhone:** plug it in (or pair it over Wi-Fi), choose it at the top of the window, then in the target's
**Signing & Capabilities** tab choose your **Team**. Your Apple ID works as a free personal team: the app runs on your
phone for 7 days at a time. TestFlight and the App Store need the Apple Developer Program. The bundle identifier is
`uk.co.thebetrayal.app` (the old web-view app, since removed from the server repo, used the same one, so this replaces
it on a phone).

**To test on your own:** **Practice against bots** on the start screen: one person and the bots, who play every part,
Trials included. It's also how Apple's reviewer plays a whole game.

**Buying, from Xcode:** the shared scheme runs the app with `Store.storekit` (Xcode's StoreKit testing: test prices,
Apple's test purchase sheet, no money). The real server refuses those purchases ("only work on a development server")
and the app says so. To get a code from one, run the Worker locally (in the server repo) with
`npx wrangler dev --var APPSTORE_LOCAL:1` and
launch the app with `-server http://<your Mac's address>:8787` (Edit Scheme → Run → Arguments). To try real sandbox
purchases (TestFlight, or a sandbox tester), set the scheme's StoreKit Configuration to None; that needs the products set
up in App Store Connect (the server repo's HANDOVER §6.2a).

## What it does

- **The start screen** (`UI/HomeView.swift`): two choices, **Join a game** and **Host a game**, then Practice against
  bots, Your passes, How to play (the premise in five screens, which a phone also sees before its first game) and FAQs.
  Join a Table with its code, by scanning the TV's QR code (`UI/Scanner.swift`)
  or from a `thebetrayal://join/CODE` link; use the device as a Table's TV; start your own Table, free or with a pass. It
  makes the website's calls (`POST /api/games`, then `GET /api/g/CODE/m`), offers "carry on or start a new game" to a
  pass whose game is still open and the test choice to the master passcode, and refuses a Table already set up for Classic.
- **Free games and passes** (the server repo's `worker/src/tiers.js`, HANDOVER §4.8): with no code the app starts a
  free game, with ads between rounds and the base Trials; a **Night Pass** (consumable) makes every game started in its
  24 hours ad-free with every Trial, and the **Host Pass** (yearly subscription) every game while it's paid. The app's
  codes are a pool of their own (every call to `/api/games` says `app: true`): website codes don't open Tables here.
  Pass codes stay out of sight: **Your passes** lists each by name and state and the app uses it itself. There's no way
  to type a code in: only purchases in the app unlock anything (App Review 3.1.1; promotions use Apple's offer codes).
  **Practice against
  bots** opens a practice game (`practice: true`): the bots play every part and the Trials that need people in the
  room are left out.
  Every response from an app-made Table carries its tier (`room.tier`), which `Model/Session.swift` keeps as `tier`.
- **Ads in free games** (`Media/Ads.swift`), with Google's AdMob SDK (`GoogleMobileAds` through Swift Package Manager,
  13.11 or later in 13.x; Google's consent library comes with it). The SDK starts only at a free game, after Google's
  consent form and Apple's tracking question. A banner sits at the foot of a free game's lobby; an interstitial may show
  on a player's phone at the Reckoning's debate from the second round (minutes when nobody needs their phone), and on
  the results, on the host's phone too but never the TV, once a break, with no gap or cap beyond that (the
  server sends these limits, and
  `ADS_ENABLED=0` on the server turns ads off). An ad that hasn't loaded by its moment is skipped. After a round, a
  player's phone says "The host can remove ads for everyone tonight." **Ad choices** on the start screen reopens
  Google's form where the law asks for it.
  - **AdMob's IDs** are in `Info.plist`: the app ID (`GADApplicationIdentifier`) and the units (`BTAdBanner`,
    `BTAdInterstitial`). Only Release builds
    (TestFlight, the App Store) use the real units: a Debug build always shows Google's test ads, as AdMob's rules
    require while developing. Before release: publish a GDPR message (and an IDFA explainer if wanted) in AdMob's
    Privacy & messaging, and add Google's full list of SKAdNetwork identifiers to `SKAdNetworkItems` (only Google's
    own is there now).
- **Offers to the host** (`UI/Offers.swift`, all their limits in one place): in a free game's lobby once three have
  joined (instead of the host's banner, until waved away); a strip at the Reckoning's debate in rounds 2 and 4 on the host's phone,
  with a matching corner card on the TV that has nothing to tap; and the Host Pass on the host's results. Players are
  never offered anything. Each ad and offer seen or tapped, and each purchase started, is counted by the server
  (`/api/app/event`; the server repo's HANDOVER §4.8 has the figures and the weekly host conversion).
- **Buying passes** (`Model/Shop.swift`, `UI/ShopView.swift`): Apple's in-app purchase, at the App Store's price. Each
  purchase goes to `POST /api/appstore/claim`, which checks it with Apple and returns its code (the server repo's
  HANDOVER §6.2a); only then does the app finish the purchase, so a code is never lost to a dropped connection
  (unfinished purchases are claimed again at the next launch). Passes bought, or used, are kept on the phone under
  **Your passes**, with what each can do now (`POST /api/app/codes`: ready, ad-free until a time, used, lapsed).
  **Restore purchases** brings a Host Pass to a new phone; **Manage subscription** is Apple's own sheet.
- **How to play, the terms and the privacy notice** (`UI/Pages.swift`): the website's pages rewritten for the app (Apple
  takes the payments, codes are kept on the phone, the camera reads QR codes). Change them with the website's
  (`site/pages/rules.html`, `terms.html`, `privacy.html` in the server repo).
- **The game** (`UI/PhoneView.swift`, `PhonePhases.swift`, `PhoneTrial.swift`, `Tools.swift`): every phase, every
  Trial, the host's tools (with the three checks before **Show me the roles**), pause, rejoin requests and last words,
  in the page's words. `Model/Session.swift` does what the page's `poll`, `send`, `doJoin` and `doCreate` do: it polls
  `GET /api/g/CODE/m` about once a second (faster during Snap, slower in the background), sends taps to `m/act`, and
  keeps the phone's token under the page's own storage name (`bt-m-CODE`).
- **The TV** (`UI/TVView.swift`): the TV page's every screen, sized to the screen as the page sizes it in `vh` and `vw`.
  Its QR code is `thebetrayal://join/CODE`: an iPhone's Camera opens the app at that Table. Guests need the app (there's
  no Android version); the app's scanner also reads the website TV's codes.
  - **On a TV:** AirPlay the phone to a TV (or use a cable). The app gives the second display a scene of its own
    (`ExternalDisplay` in `App/TheBetrayalApp.swift`) showing the TV of the Table the phone is at, with the music. It
    never mirrors the phone, so a player's role can't reach the TV.
  - **On an iPad or a spare phone:** under **Join a game**, type the Table code and choose **Use this screen as the TV**.
    The narrator and sound buttons are in its bottom-left corner, as on the website.
- **What the website can't do on an iPhone, the app does:** it taps the phone when something needs its player, and
  hard ten seconds before a clock closes on an unanswered question (the page's `navigator.vibrate`, which iPhones
  ignore); it keeps the screen awake at a Table.
- **The model** (`Model/`) reads the server's views leniently: a field that's missing, or of another type, reads as
  nothing rather than failing the screen, so the server can add fields without breaking the app.

## Where the look comes from

| | made from | by |
|---|---|---|
| fonts (`Resources/Fonts`) | `worker/public/fonts`, latin and latin-ext joined; Grenze Gotisch fixed at 400 and 600 | `tools/fonts.py` |
| icons, seals, crest | the SVG in `src/art.js`, kept as text and drawn natively | `UI/Art.swift` reads the path data |
| music and sounds (`Resources/Sound`) | the synthesiser in `src/audio.js`, rendered in headless Chromium: each scene a seamless 16-bar loop, each sound effect the Modern page plays | `node tools/sounds.mjs` |
| colours, sizes, spacing | `src/modern.css` | by hand, in `UI/Theme.swift` and `UI/Components.swift` |
| app icon | the seal, as the server repo's `tools/brand/make_seal.py` renders the web icons | |

After changing `src/art.js`'s drawings, copy them into `UI/Art.swift`. After changing `src/audio.js`, run the server
repo's `./build.sh` and then, here, `node tools/sounds.mjs`.

## When the game changes

The app shows what the server sends, so most rule changes need no app change. A new screen, a new kind of Trial item
or new words on the page do: change `src/modern-ui.js`, then the matching view here, and run
`node tools/fixtures.mjs > TheBetrayal/Debug/Fixtures.json` here so the checks below see the new moment. The checks
warn when the server's rules engine no longer plays the recorded game.

## Checks

`.github/workflows/ios.yml` runs on one of GitHub's Macs on every push that changes more than Markdown (or by hand,
with options to play the whole game and to choose the server repo's branch):

1. `ci/main.swift` builds the model with `swiftc` and reads every moment of `Debug/Fixtures.json` (a whole game
   recorded from the real rules engine by `tools/fixtures.mjs`), and every drawing.
2. It builds the app (Debug and Release) and runs it in the iPhone simulator: the start screen, the art (`-art`), the
   start screen's join, host and passes screens with made-up prices and saved codes (`-shop -screen passes`), the sheet
   after a purchase (`-bought`), the premise's five screens (`-intro 0`), the four pages (`-page rules`), two dozen recorded moments as the phone shows them (`-demo NAME`), and every moment as
   phone and TV drawn offscreen (`-render-all`, which can't draw text fields). `ci/main.swift` also checks which
   Table a scanned code or link opens.
3. It checks out the server repo, starts its Worker (`wrangler dev`, with a test master passcode), and `ci/drive.py`
   plays a game against
   bots as the host while the app shows the host's phone (`-server URL -play ROOM TOKEN`), photographing each new screen.
   Pushes play the first round; a run by hand can play the whole game.

**The server repo is private,** so step 3 (and the fixtures check) needs a token, made once:

1. GitHub → your picture → **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate
   new token**. Repository access: **Only select repositories → ryanbrown094/Betrayal-Website**. Permissions: **Contents:
   Read-only**. Pick an expiry, generate it and copy it.
2. This repo → **Settings → Secrets and variables → Actions → New repository secret**: name `SERVER_REPO_TOKEN`, the
   token as its value.

Without it, the run builds and photographs the app but skips the game against bots.

The pictures are the run's `ios-native-screens` artifact and, as one commit, the ref `refs/screens/ios-native` (not a
branch, so nothing deploys it): `git fetch origin refs/screens/ios-native && git show FETCH_HEAD --stat`. Mac minutes
count ten times against the account's Actions allowance; a run takes about ten minutes.

The Debug build's launch arguments (`Debug/Demo.swift`) are compiled out of Release, and `Fixtures.json` is left out of
the Release bundle.

## Not checked yet

- A real iPhone, a real AirPlay TV, and the sound through a speaker: the simulator can't show a second display from the
  CI, and nobody has heard the rendered music on a device. Try both before a party.
- Buying: the StoreKit code has only been built, never run against the App Store. The server's half is tested with
  Apple stubbed (`node qa/appstore.mjs`) and with an Xcode-style purchase on `wrangler dev`. Before release: a sandbox
  purchase of each product through TestFlight, a restore on a second device, and a sandbox refund.
- The QR scanner and the `thebetrayal://` link need a real iPhone (the simulator has no camera).
- App Store review: passes are sold only in the app, and the website's codes don't open Tables in it, so the app never
  depends on anything bought elsewhere.
