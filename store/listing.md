# The App Store listing

Everything App Store Connect asks for, ready to paste. Character counts are checked against Apple's limits, and the words
follow the server repo's `media/copy/glossary.md` (no TV-programme words, the Confessor never named). Screenshots:
`screenshots/` (made by `compose.py`).

## The app (App Information)

| field | value |
|---|---|
| Name | The Betrayal |
| Subtitle (28/30) | A party game of secret oaths |
| Primary category | Games: Board |
| Secondary category | Games: Trivia |
| Content rights | Contains no third-party content (all art, music and questions are our own; fonts under the SIL Open Font License) |
| Age rating | Apple's ratings are now 4+, 9+, 13+, 16+ and 18+. Answer the questionnaire honestly: alcohol references *infrequent/mild* (drinks at the party), cartoon or fantasy violence *infrequent/mild* (make-believe poisoning), no gambling or unrestricted web access; it also asks about **advertising** (yes: free games) and **user-generated content** (yes: players type their names, the prize and last words, which the table and the TV see,
and the Forsworn type messages to each other in their chat); if it asks about **messaging or chat**, yes too. The game is made for adults, so choose 16+ or 18+ even if the questionnaire comes out lower. |
| Privacy Policy URL | https://thebetrayal.co.uk/app-privacy |
| Copyright | 2026 The Betrayal |

## The version page

**Promotional text** (150/170, can change without a new version)

Everyone swore an oath tonight. Not everyone meant it. Gather your friends, play on your own phones, and find the Forsworn before they take the Purse.

**Description** (2344/4000)

```
Everyone swore an oath tonight. Not everyone meant it.

The Betrayal is a party game of secret roles, played in one room by friends on their own phones. A few of you are secretly Forsworn; everyone else is Loyal. By night the Forsworn choose a victim. By day the table argues, accuses and votes someone out. Find every Forsworn before the end, or watch them walk away with the Purse.

EVERY PHONE KNOWS ITS PART
Your phone tells you what to do, and when. There's nothing to learn before the night and no account to make. The host starts a Table; everyone else joins in the app with its code, or scans the code on the TV.

PARTY GAMES BETWEEN THE ROUNDS
Quizzes, guessing games, word games, charades and more, played on the phones, for a shared Purse and for Sanctuary, which keeps its holder safe for a night. In the quiz-style Trials, every wrong answer from a Forsworn costs the Purse: the table hears how many there were, never whose.

NIGHT, DAWN AND THE RECKONING
Heads down while the Forsworn choose. At dawn the victim learns first, in secret, then gets their last words. Then the Reckoning: open debate on a timer and a secret vote. The exile's role is shown as they leave.

A SHOW ON YOUR TV
Make an iPad or a spare phone the TV, or AirPlay the host's phone to one, and the game becomes a show: the Table, the votes, the reveals and the music. The TV shows the game, never anyone's role.

TWISTS
A few twists, which the game explains when they happen.

PRACTISE ON YOUR OWN
Practice against bots: they fill the Table and play every part, so you can learn the game before the party.

FREE, OR AD-FREE
Free games show a short ad as each day starts and at the end, never during a Trial or a vote, and use eight of the fifteen Trials. A Night Pass makes tonight ad-free for everyone at your Table, with every Trial and the full question banks. The Host Pass does that every time you host.

You'll need 8 to 24 players in one room, and a phone each. The game is made for adults.

The Host Pass is a yearly subscription. Payment is taken from your Apple Account. It renews automatically unless cancelled at least 24 hours before the end of the year; manage or cancel it in your Apple Account's subscriptions.

Terms of use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy: https://thebetrayal.co.uk/app-privacy
```

**Keywords** (99/100; words in the name and subtitle are already searched, so they're not repeated)

```
social deduction,hidden roles,mystery,bluff,deception,liar,group,friends,quiz,trivia,werewolf,mafia
```

| field | value |
|---|---|
| Support URL | https://thebetrayal.co.uk/contact |
| Marketing URL | https://thebetrayal.co.uk (AdMob finds `app-ads.txt` through the developer website) |

## App Review Information

Sign-in required: **no**. Notes:

```
The Betrayal is a party game for 8 to 24 people in one room, each playing on their own phone. To play on your own, tap Practice against bots on the start screen, type a name and start: bots fill the Table and play every other part. You're the host, so your phone moves the game on: tap the button on each screen (Begin, Start the Trial, Continue). (Before a phone's first game, five short screens explain the game; Skip passes them.) The first time you enter a free or practice game, Google's consent form (where the law requires it) and then Apple's tracking question appear; the game is the same whatever you answer.

In-app purchases: tap Host a game, type a name and tap Start a free game; in the lobby, under Trials, tap Make it ad-free with a pass to buy a Night Pass (consumable) or the Host Pass (yearly subscription). At once the list of locked Trials goes and the game is ad-free for everyone at the Table (a real game needs 8 players' phones to start). The same passes are under Your passes on the start screen, with Restore purchases and Manage subscription. A practice game can't use a pass: it's for trying the game alone.

Guests join with the six-character Table code shown on the host's phone, or by scanning its QR code (on the host's phone, or the TV). An iPad can be the TV: tap Set up a TV on the start screen, type the code and tap Use this screen as the TV.

Everyone at a Table is in the same room and joins with a code the host gives them: there's no matchmaking, public profile or chat with strangers. The Forsworn's chat is only between the players on that side in that one game, and is deleted with the Table; the host can take anyone out of the game from Tools.

No account or sign-in is needed.
```

## App Privacy (App Store Connect → App Privacy)

Data collection: **yes**. Tracking: **yes** (Google AdMob uses the advertising identifier in free games, when the player
allows it at Apple's question). Declare these; for AdMob's rows, check them against Google's current "data disclosure"
page for AdMob on iOS, which Google keeps up to date (I couldn't reach it from here):

| Data type | Who collects it | Purposes | Linked to the person | Tracking |
|---|---|---|---|---|
| Identifiers › Device ID | Google AdMob | Third-party advertising | no | **yes** |
| Usage Data › Advertising Data | Google AdMob | Third-party advertising, Analytics | no | yes |
| Usage Data › Product Interaction | AdMob; and the app's own daily counts and each device's log at a Table (screens, actions, ads, offers) | Analytics, App Functionality, Third-party advertising | no | AdMob: yes; ours: no |
| Location › Coarse Location | Google AdMob (from the IP address) | Third-party advertising | no | yes |
| Diagnostics › Crash Data, Performance Data, Other Diagnostic Data | Google AdMob; the server's record of each game; each device's log at a Table (errors, connection trouble, crashes from iOS's MetricKit) | App Functionality, Analytics | no | no |
| Purchases › Purchase History | the server (Apple's record of each purchase) | App Functionality | no | no |
| User Content › Other User Content | the server (names, the prize, last words, the Forsworn's messages to each other) | App Functionality | no | no |

The app's own privacy manifest (`TheBetrayal/PrivacyInfo.xcprivacy`) declares what it collects itself and its use of UserDefaults;
Google's SDK ships its own.

## In-app purchases

| | Night Pass | Host Pass |
|---|---|---|
| Type | Consumable (In-App Purchases) | Auto-renewable subscription (Subscriptions), group "Host Pass", group display name "The Betrayal" |
| Product ID | `uk.co.thebetrayal.app.night` | `uk.co.thebetrayal.app.host` |
| Reference name | Night Pass | Host Pass |
| Price | £4.99 | £19.99, 1 year |
| Display name | Night Pass | Host Pass |
| Description | Tonight ad-free, with every Trial unlocked | Every game you host ad-free, every Trial |

Review notes, Night Pass:

```
A pass for one night of ad-free games with every Trial. Its 24 hours start when it's first used: start a game with it, or use it on a free game from the lobby (Make it ad-free with a pass). Single use: it's consumed when its 24 hours start, can be bought again, and isn't restored to other devices, like any consumable.
```

Review notes, Host Pass:

```
A yearly subscription for hosts. While it's active, every game the subscriber hosts is free of ads for everyone at the Table, and includes every Trial and the full question banks. Players who join never pay. To see it: buy it under Your passes on the start screen, then tap Host a game, type a name, tap Start a game and choose Use my Host Pass, or use it from a free game's lobby with Make it ad-free with a pass. Restore purchases brings it to another device, and Manage subscription opens Apple's subscription settings.
```

Each needs a review screenshot: `review/passes-6.9.png` (the **Your passes** screen, 1320 × 2868, an accepted iPhone size).

## Screenshots

| set | size | files |
|---|---|---|
| iPhone 6.9" | 1320 × 2868 | `screenshots/iphone-6.9/` |
| iPhone 6.3" | 1206 × 2622 | `screenshots/iphone-6.3/` (App Store Connect's 6.1"/6.3" Dynamic Island slot) |
| iPhone Duo | 2007 × 2853 | `screenshots/iphone-duo/` (the phone's column, as the Duo shows it open) |
| iPad 13" | 2752 × 2064 | `screenshots/ipad-13/` (the TV, as an iPad shows it with **Use this screen as the TV**) |

To make them again after the screens change: the CI keeps the raw screens (`-render-store`) in `refs/screens/ios-native`,
then `git fetch origin refs/screens/ios-native && mkdir -p /tmp/raw && git archive FETCH_HEAD store | tar -x -C /tmp/raw`
and `python3 store/compose.py /tmp/raw/store` (Pillow).
