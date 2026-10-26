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
| Age rating | Answer Apple's questionnaire: alcohol references *infrequent/mild* (drinks at the party), cartoon or fantasy violence *infrequent/mild* (make-believe poisoning), no gambling, contests, or unrestricted web access. The game is made for adults, so 17+ is a fair choice even if the questionnaire comes out lower. |
| Privacy Policy URL | https://thebetrayal.co.uk/app-privacy |
| Copyright | 2026 The Betrayal |

## The version page

**Promotional text** (150/170, can change without a new version)

Everyone swore an oath tonight. Not everyone meant it. Gather your friends, play on your own phones, and find the Forsworn before they take the Purse.

**Description** (2308/4000)

```
Everyone swore an oath tonight. Not everyone meant it.

The Betrayal is a party game of secret roles, played in one room by friends on their own phones. A few of you are secretly Forsworn; everyone else is Loyal. By night the Forsworn choose a victim. By day the table argues, accuses and votes someone out. Find every Forsworn before the end, or watch them walk away with the Purse.

EVERY PHONE KNOWS ITS PART
Your phone tells you what to do, and when. There's nothing to learn before the night and no account to make. The host starts a Table; everyone else joins in the app with its code, or scans the code on the TV.

PARTY GAMES BETWEEN THE ROUNDS
Quizzes, guessing games, word games, charades and more, played on the phones, for a shared Purse and for Sanctuary, which keeps its holder safe for a night. Every wrong answer from a Forsworn costs the Purse: the table hears how many there were, never whose.

NIGHT, DAWN AND THE RECKONING
Heads down while the Forsworn choose. At dawn the victim learns first, in secret, then gets their last words. Then the Reckoning: open debate on a timer and a secret vote. The exile's role is shown as they leave.

A SHOW ON YOUR TV
AirPlay the host's phone to a TV, or use an iPad, and the game becomes a show: the Table, the votes, the reveals and the music. The TV shows the game, never anyone's role.

TWISTS
The Casting Vote, the Temptation, the Crown, and a last betrayal in the final, if the Forsworn get that far.

PRACTISE ON YOUR OWN
Practice against bots: they fill the Table and play every part, so you can learn the game before the party.

FREE, OR AD-FREE
Free games show an ad between rounds, never while you play, and use eight of the fifteen Trials. A Night Pass makes tonight ad-free for everyone at your Table, with every Trial and the full question banks. The Host Pass does that every time you host.

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
The Betrayal is a party game for 8 to 24 people in one room, each playing on their own phone. To play on your own, tap Practice against bots on the start screen, type a name and start: bots fill the Table and play every part.

In-app purchases: tap Start a free game, and in the lobby tap Make it ad-free with a pass to buy a Night Pass (consumable) or the Host Pass (yearly subscription). The game becomes ad-free and its locked Trials unlock at once. The same passes are under Make it ad-free on the start screen, with Restore purchases and Manage subscription.

Guests join with the six-character Table code shown on the host's phone, or by scanning the QR code on the TV screen. An iPad can be the TV: type the code and choose Use this screen as the TV.

No account or sign-in is needed.
```

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
A pass for one night of ad-free games with every Trial. Its 24 hours start when it's first used: start a game with it, or use it on a free game from the lobby (Make it ad-free with a pass).
```

Review notes, Host Pass:

```
A yearly subscription for hosts. While it's active, every game the subscriber hosts is free of ads for everyone at the Table, and includes every Trial and the full question banks. Players who join never pay. To see it: buy it under Make it ad-free on the start screen, then tap Start a free game and choose Use my Host Pass, or use it from a free game's lobby with Make it ad-free with a pass. Restore purchases brings it to another device, and Manage subscription opens Apple's subscription settings.
```

Each needs a review screenshot: the start screen's **Make it ad-free** card, or the lobby's pass sheet.

## Screenshots

| set | size | files |
|---|---|---|
| iPhone 6.9" | 1320 × 2868 | `screenshots/iphone-6.9/` (the 6.9" set covers every smaller iPhone) |
| iPad 13" | 2752 × 2064 | `screenshots/ipad-13/` (the TV, as an iPad shows it with **Use this screen as the TV**) |

To make them again after the screens change: the CI keeps the raw screens (`-render-store`) in `refs/screens/ios-native`,
then `git fetch origin refs/screens/ios-native && mkdir -p /tmp/raw && git archive FETCH_HEAD store | tar -x -C /tmp/raw`
and `python3 store/compose.py /tmp/raw/store` (Pillow).
