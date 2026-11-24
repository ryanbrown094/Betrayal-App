# Apple Ads

Ads in App Store search: someone types "party games" and The Betrayal shows first, marked Ad. This is the plan for
the first campaigns. Starting bids and budgets are guesses to learn from, not data.

## What you set up (only you can)

1. **The account**: [ads.apple.com](https://ads.apple.com), signed in with an Apple Account that can see the app in App
   Store Connect. Choose **Apple Ads Advanced** (Advanced lets you pick keywords and bids), country **United Kingdom**,
   and add a card for billing.
2. **Access for Claude** (so the campaigns can be checked and adjusted daily, as the website's Google Ads are): Apple
   Ads → Account Settings → User Management → invite an API user with the **API Account Manager** role. Then, under
   that user's API settings, generate a client ID with a key pair: the private key goes into this repository's
   secrets, never a file (name it `APPLE_ADS_PRIVATE_KEY`, with `APPLE_ADS_CLIENT_ID`, `APPLE_ADS_TEAM_ID`,
   `APPLE_ADS_KEY_ID` and `APPLE_ADS_ORG_ID`). Apple's help, under Campaign Management API, walks through it.

## The first campaigns (United Kingdom, iPhone and iPad)

| campaign | keywords (exact match) | product page | daily budget | max cost per tap |
|---|---|---|---|---|
| Brand | the betrayal, the betrayal game | default | £2 | £0.30 |
| Party games | party games, party game, games for groups, group games, adult party games | default | £6 | £0.80 |
| Christmas (to 31 December) | christmas party games, christmas games, christmas quiz, christmas party | default (the event shows on it) | £5 | £0.80 |
| Murder mystery | murder mystery game, murder mystery party, murder mystery | Murder mystery night | £3 | £0.80 |
| Werewolf and Mafia | werewolf game, werewolf, mafia game, mafia party game, social deduction, hidden role game | Werewolf and Mafia fans | £3 | £0.80 |
| Discovery | search match on, broad match on the words above | default | £2 | £0.50 |

About £21 a day across all six, less once the Christmas campaign ends. Add each campaign's keywords to the others as
**negative** keywords so they don't bid against each other, and the Discovery campaign's best search terms to the
right campaign each week.

**Don't bid on "traitors"** or other games' names: they're someone else's trade marks, and Apple can refuse the ads.

## Judging it

- After two weeks: cost per install (CPA) by campaign. Keep the ones under about £1.50, cut the bids of the rest.
- Tap-through rate under 5% means the product page or keywords don't match: try the custom page, or drop the keyword.
- Conversion rate (installs from taps) under 40% means the page isn't persuading: that's the screenshots' job.
- Weekly: `ci/asc.py analytics` shows downloads by source, so search ads can be told apart from everything else.
