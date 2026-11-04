# Submitting 1.1

Everything App Store Connect needs for version 1.1, in the order you'll meet it. Only what changes from 1.0 is
spelled out here; every other field stays as it is (`listing.md` has them all, ready to paste).

## 1. The build

1. Pull `main` and open `TheBetrayal.xcodeproj` in Xcode 27.1. The target's **General** tab should say **Version 1.1,
   Build 5**.
2. **Product → Archive**, then **Distribute App → App Store Connect → Upload**.
3. App Store Connect → **The Betrayal** → the **+** beside **iOS App** → version **1.1**.
4. Once the upload has processed (it emails you), pick **1.1 (5)** under **Build**. There's no encryption question:
   the app answers it itself.

## 2. What's New in This Version

```
A new look, room to spread out, and a few things hosts asked for.

LIQUID GLASS
The bar at the top of the game floats over the screen as you scroll, and Your role is always in it: the same button on every phone, so a glance gives nothing away. The host's moves float at the foot of the screen.

A SIDEBAR ON iPAD AND iPHONE DUO
On a wide screen, the start screen's menu sits beside whatever it opens. In a game, the Table sits beside your screen, with everything the top bar holds on a phone: the Purse, Your role, who's still in, what you hold, and the host's Pause, Tools and moves.

iPHONE DUO, CLOSED
The game fits the cover screen, the pause included.

FOR THE HOST
• See whose phone has gone quiet, and take them out so nobody waits on them.
• A phone that lost its place in the lobby can carry on under its own name.
• Share the Table's code from any phone in the lobby.

ALSO
• Rate the game in one tap at the end.
• Report a problem from the lobby, the results or the host's Tools, with what your phone saw.
• The Reckoning's talk is four minutes at most.
```

## 3. Screenshots

Replace all four sets with the new ones (six each, in their file order, 01 to 06):

| App Store Connect slot | size | files |
|---|---|---|
| iPhone 6.9" Display | 1320 × 2868 | `screenshots/iphone-6.9/` |
| iPhone 6.3" Display | 1206 × 2622 | `screenshots/iphone-6.3/` |
| iPhone Duo | 2007 × 2853 | `screenshots/iphone-duo/` |
| iPad 13" Display | 2752 × 2064 | `screenshots/ipad-13/` |

## 4. Promotional text (optional; it changes without a review)

160 of 170 characters:

```
Now in Liquid Glass, with a sidebar on iPad and iPhone Duo. Everyone swore an oath tonight. Not everyone meant it. Find the Forsworn before they take the Purse.
```

## 5. Description (optional)

The 1.0 description is still accurate. To mention the new layouts, add this paragraph after **A SHOW ON YOUR TV**:

```
ON iPAD AND iPHONE DUO
A sidebar keeps the Table beside your screen: the Purse, Your role, who's still in, and the host's controls.
```

Keywords, support and marketing URLs: unchanged.

## 6. App Review Information → Notes

Replace the notes with these (the first four paragraphs are 1.0's; the fifth is new):

```
The Betrayal is a party game for 8 to 24 people in one room, each playing on their own phone. To play on your own, tap Practice against bots on the start screen, type a name and start: bots fill the Table and play every other part. You're the host, so your phone moves the game on: tap the button on each screen (Begin, Start the Trial, Continue). (Before a phone's first game, five short screens explain the game; Skip passes them.) The first time you enter a free or practice game, Google's consent form (where the law requires it) and then Apple's tracking question appear; the game is the same whatever you answer.

In-app purchases: tap Host a game, type a name and tap Start a free game; in the lobby, under Trials, tap Make it ad-free with a pass to buy a Night Pass (consumable) or the Host Pass (yearly subscription). At once the list of locked Trials goes and the game is ad-free for everyone at the Table (a real game needs 8 players' phones to start). The same passes are under Your passes on the start screen, with Restore purchases and Manage subscription. A practice game can't use a pass: it's for trying the game alone.

Guests join with the six-character Table code shown on the host's phone, or by scanning its QR code (on the host's phone, or the TV). An iPad can be the TV: tap Set up a TV on the start screen, type the code and tap Use this screen as the TV.

Everyone at a Table is in the same room and joins with a code the host gives them: there's no matchmaking, public profile or chat with strangers. The Forsworn's chat is only between the players on that side in that one game, and is deleted with the Table; the host can take anyone out of the game from Tools.

New in 1.1: the controls are in Liquid Glass, and on a wide screen (an iPad, or iPhone Duo open) the start screen's menu and the game's Table are in a sidebar. Report a problem (in the lobby, on the results, and in the host's Tools) sends us what the player writes, an email address only if they choose to add one, and the phone's recent log for that game.

No account or sign-in is needed.
```

## 7. App Privacy (check before you submit)

1.1 adds **Report a problem**, which sends what the player writes and, if they choose, their email address so we can
reply. If App Privacy doesn't already list these, add them (App Privacy → Edit):

| Data type | Purposes | Linked to the person | Tracking |
|---|---|---|---|
| Contact Info › Email Address | App Functionality | yes | no |
| User Content › Customer Support | App Functionality | yes | no |

Also check that **User Content › Other User Content** mentions the Forsworn's messages (from 1.0's chat). Diagnostics
are already declared. The privacy notice at thebetrayal.co.uk/app-privacy, and its copy in the app, say all of this.

## 8. Unchanged

- **Age rating**: as 1.0. If the questionnaire asks again, user-generated content and messaging: yes (names, last
  words, the Forsworn's chat); keep 16+ or 18+.
- **In-app purchases**: the Night Pass and the Host Pass are already approved; nothing to attach to this version.
- **Pricing and availability**: as 1.0.

## 9. Submit

Choose **Manually release this version** (or automatically) under **Version Release**, then **Add for Review →
Submit to App Review**.
