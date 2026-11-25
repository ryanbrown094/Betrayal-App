import SwiftUI

// How to play, the questions, the terms and the privacy notice, in the app itself, so it needs no website. How to play
// follows site/pages/rules.html (Modern only, joining in the app), and the questions the home page's (for the app); the
// terms and the notice follow site/pages/terms.html and privacy.html, for what the app does: Apple takes the payments,
// the app keeps codes on the phone, the camera reads QR codes.
enum Page: String, Identifiable {
    case rules, faq, terms, privacy
    var id: String { rawValue }

    var title: String {
        switch self {
        case .rules: return "The full rules"
        case .faq: return "FAQs"
        case .terms: return "Terms of sale and use"
        case .privacy: return "Privacy notice"
        }
    }
    var updated: String? { self == .rules || self == .faq ? nil : self == .privacy ? "Last updated: 4 November 2026" : "Last updated: 26 October 2026" }

    // each section: a heading and its paragraphs. **bold**; a paragraph starting "• " is a list item.
    var sections: [(String, [String])] {
        switch self {
        case .rules: return Page.rulesText
        case .faq: return Page.faqText
        case .terms: return Page.termsText
        case .privacy: return Page.privacyText
        }
    }

    static let contact = "info@thebetrayal.co.uk"
    static let eula = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let reportAd = URL(string: "mailto:info@thebetrayal.co.uk?subject=Reporting%20an%20ad&body=What%20the%20ad%20showed%2C%20and%20roughly%20when%3A%20")!

    private static let rulesText: [(String, [String])] = [
        ("", ["This page explains everything that happens in a game of The Betrayal, from the first oath to the last betrayal. You don’t need to learn any of it before you play. Every phone tells its player what to do, and when."]),
        ("The idea", [
            "A few of the players are secretly **Forsworn**. They are the traitors, and they know who each other are. Everyone else is one of the **Loyal**, and doesn’t know who anyone is. Every night, the Forsworn poison someone, and that player is out of the game. Every day, everyone votes to throw someone out. The Loyal win if they find every Forsworn before the end. The Forsworn win if even one of them is still in the game when it finishes.",
            "In between, you play party games for a shared prize pot, called the Purse, and for protection. You argue, you make alliances, and you lie to people you’ve known for years. A game usually lasts an hour or two. It’s best with drinks and snacks.",
        ]),
        ("Joining", [
            "Each game is called a **Table**. The host starts one in The Betrayal app and types their name. It can be a free game, or ad-free with a pass. The app then shows a six-character Table code. Everyone else opens The Betrayal app, types that code and their name, and they’re in. They can also scan the QR code on the host’s phone or the TV. Nobody needs to make an account, and the TV is optional. When everyone has joined, the host starts the game.",
        ]),
        ("Who’s who", [
            "**The Loyal** are most of the players. They don’t know who anyone else is. Their job is to work out who the Forsworn are and vote them out. They have nothing to go on but what people say, how people vote, and their gut feeling.",
            "**The Forsworn** are about one player in every four or five. Their phones tell them who the other Forsworn are. Each night they choose who is poisoned. By day they pretend to be Loyal, try to steer the vote, and quietly spoil the Trials.",
            "**The host** has a secret role like everyone else, and never sees anyone else’s. Their phone also has the buttons that move the game on. It begins each next part, starts each Trial once everyone has heard the rules, and can call a break, open the vote early or add a minute. The game plans its own Trials and Reckonings, so the host doesn’t have to.",
            "The game begins with **the Oath**. Every phone asks its player, in secret, whether they would like to be Forsworn. They can say yes, no, or either way. The roles are given out using the answers, starting with the people who said yes, but nobody is promised what they asked for. Then each player looks at their role, holding their phone close.",
            "Nobody is told how many Forsworn there are. Players only find out as Forsworn are exiled and their roles are shown.",
        ]),
        ("A round", [
            "The game is played in rounds. The number of rounds depends on how many are playing, so that the final starts with five or fewer players left, or four or fewer in a game of 8. Each round goes like this:",
            "• **A Trial.** This is a party game played on the phones, such as a quiz, a guessing game or charades. They’re all listed below. Each question closes by itself when everyone has answered or the clock runs out. Trials add to the Purse, and in most Trials the winner gets Sanctuary, which keeps them safe that night. The first round opens with Most Likely To, as an icebreaker.",
            "• **The Reckoning.** This is the debate and the vote. First there’s an open debate on a timer, with thirty seconds for each player still in, and four minutes at most. Then everyone votes on their phone, in secret. The vote closes when everyone has voted. The player with the most votes is exiled, which means they’re voted out. If there’s a tie, the tied players face a second vote. If that ties too, the game picks one of them at random. While more than sixteen players are left, two players are exiled each round.",
            "• **The reveal.** Everyone sees whether the exiled player was Forsworn or Loyal. As they leave, they can type one last line for the TV.",
            "• **The night.** The Forsworn secretly choose someone to poison, on their phones. They choose two players when twelve or more are left, and three when twenty or more are left. They must all agree, so the night waits until they choose the same player. If the clock runs out first, the player chosen most is poisoned. Everyone else taps a name too, so nobody can tell who is choosing. The Forsworn also have a secret chat, under **Your role** on every phone, so they can talk at any time. A player holding Sanctuary can’t be poisoned.",
            "• **Dawn.** This is the morning, when everyone finds out who was poisoned. The poisoned player finds out first, in secret on their phone. Then the host reveals it to everyone. The poisoned player stands up, says so, and gets thirty seconds of last words. Then they leave the table. If they once came top in Most Likely To, the TV says so too.",
            "Between the parts of the game, the host can call a short break. At any time, they can also pause the game, which stops every clock, for the doorbell or a top-up. If someone feels ill, the host can take them out of the game without anyone learning their role.",
        ]),
        ("The dead", [
            "Nobody goes home when they’re out. Players who are exiled or poisoned become **Ghosts**. They stay at the party and watch the game on their phones. Ghosts can’t vote, but at every Reckoning they can say who they think should go. If they pick the player who is exiled, everyone is told. In The Statue, the Ghosts do their worst to make the living players laugh.",
        ]),
        ("Sanctuary", [
            "**Sanctuary** keeps its holder safe from being poisoned that night. It lasts for one night, and it’s the prize in most Trials. At most a quarter of the players still in can hold it at the same time. Before the game starts, the host chooses whether Sanctuary is won **in public** or **in secret**. In public, everyone is told who has it. In secret, only the winner knows they’re safe. A Forsworn who wins a secret Sanctuary gets nothing, and is the only one who knows.",
        ]),
        ("Twists", [
            "Twists are surprises, and each one happens once in a game. The phones explain each twist when it happens. Before the start, the host can switch them all off, for a simpler first game.",
            "• **The Casting Vote** comes about halfway through. The winner of that Trial gets it instead of Sanctuary, and nobody else knows who has it. It’s a secret tie-breaker. If a Reckoning’s vote ties and its holder voted for one of the tied players, their vote decides it.",
            "• **The Temptation** comes later the same day. Everyone secretly chooses PURSE or SELF. If exactly one player chooses SELF, they get Sanctuary and the Purse grows. If nobody does, the Purse grows by double. If two or more choose SELF, nobody gets Sanctuary and the Purse shrinks.",
            "• **The Crown** comes in the last round before the final. Everyone is told who wins it. It gives its holder Sanctuary that night. Once, at a Reckoning, they can also lay it down to be safe from that vote.",
            "• **The Confessor** comes in the final. The winner of that Trial is told, in secret, the name of one Forsworn who is still playing.",
        ]),
        ("The Purse", [
            "**The Purse** is the shared prize pot. Every Trial adds to it, up to its target, and the better everyone plays, the more goes in. In a knockout, players drop out until one is left. A knockout has a winner, but no score for the group as a whole, so it adds half its share. The knockouts are Rock Paper Scissors Royale, One Leg and The Statue.",
            "At the end, the winners take the Purse. If the Loyal win, they take what they built. If the Forsworn win, they take what the Purse fell short of its target. So every point the Forsworn quietly spoil is theirs.",
            "In Rapid Quiz, What Changed? and Snap, each wrong answer from a Forsworn takes 50 out of the Purse, up to half of that Trial’s points. Rapid Quiz’s brutal questions don’t count. Everyone hears how many wrong answers there were, but never whose. A Loyal player’s wrong answers cost nothing, so a shrinking Purse is a clue.",
            "There is also **a prize**, chosen by the host. It should be something worth lying to your friends for. If the host doesn’t choose one, the prize is chocolate coins, one for every 100 points the winners take from the Purse. The host can also set better prizes for when the winners take more. For the Loyal that means a fuller Purse, and for the Forsworn an emptier one. Everyone knows the Purse decides the prize, but not what the prize is.",
        ]),
        ("The end game", [
            "The last round is **the final**. It starts when five or fewer players are left, or four or fewer in a game of 8.",
            "• **A last Trial**, for the Purse and perhaps something more. There’s no Sanctuary in the final, because there’s no night left to survive.",
            "• **The Reckoning, without reveals.** Everyone votes a player out, but this time their role isn’t shown.",
            "• **Trust or Doubt.** When four or fewer are left, each player makes a secret choice on their phone. They choose TRUST if they believe every Forsworn is gone, or DOUBT if not. The game only ends if everyone chooses TRUST. If not, it’s back to the Reckoning for another exile, and another vote.",
            "• **The Unmasking.** One by one, the last players’ roles are shown. If only Loyal are left, the Loyal win and share the Purse. If a Forsworn is still in the game, the Forsworn win, and take what the Purse fell short of its target.",
            "• **The last betrayal.** If two or more Forsworn reach the end, each one secretly chooses HONOUR or BETRAY. If they all choose HONOUR, they share the winnings. If one betrays, they take everything. If two or more betray, nobody gets anything.",
            "• **The awards.** Everyone’s role is shown, then up to six awards for the game, such as The Grand Deceiver, The Sharpest Eye, Barking Up the Wrong Tree and The Ghost Who Saw.",
        ]),
        ("Trials", [
            "The game picks them in a random order, so no two games run the same way.",
            "• **Most Likely To.** A prompt appears on every phone. Vote for the person it fits best, then see who the table chose. There’s no prize, only a reputation.",
            "• **Rapid Quiz.** Fifteen questions: five easy, five medium and five brutal. Type your answer before the clock runs out. You get a point for every right answer, and one more if you’re the fastest.",
            "• **Longest Word.** You get twelve letters. Type the longest real word you can make from them.",
            "• **Closest Guess.** The answer to each question is a number. The closest guesses score.",
            "• **Memory Wall.** Twelve words appear, then vanish. Type every one you can remember.",
            "• **Snap.** A symbol changes every few seconds. When it matches the one before, tap SNAP. A wrong tap costs you a point.",
            "• **Rock Paper Scissors Royale.** Players are paired up at random and choose on their phones. If you lose, you’re out. It goes on until one player is left standing.",
            "• **One Leg.** Everyone stands up on one leg. If you put a foot down, tap the button to say you’re out. The last one standing wins.",
            "• **Screen Charades.** One player at a time gets a secret word on their phone and acts it out. When someone guesses it, the actor taps who guessed.",
            "• **Hum It.** Like charades, but your phone gives you a song to hum.",
            "• **Draw It.** Like charades, but you draw it, on paper, a board or in the air. No letters and no numbers.",
            "• **The Statue.** The living players freeze. The Ghosts can do anything except touch them, to make them move or laugh.",
            "• **Two Truths and a Lie.** One player says three things about themselves, and one of them is a lie. Everyone else votes on their phone for the lie.",
            "• **Higher or Lower.** You see a question and a number. Is the real answer higher or lower?",
            "• **What Changed?** Twelve symbols appear. They vanish, then come back with something different. Tap what changed. The first right answer scores double.",
            "The quiz, charades, songs, pictures and guessing games use a bank of thousands of questions and prompts, and nothing repeats within a game. A free game plays 8 of these 15 Trials, and a pass adds the other 7.",
        ]),
        ("What you need", [
            "• 8 to 24 players. 8 to 16 is the sweet spot.",
            "• An hour or two. That’s about an hour for 8 to 10 players, an hour and a half for 12 to 16, and about two hours for 20 to 24.",
            "• A prize.",
            "• A phone each, with The Betrayal app.",
            "• A TV, if you like. It turns the game into a show, but it’s optional. You can AirPlay the host’s phone to it, and while the game is open the TV shows the game, not what’s on the phone. Or you can make an iPad or a spare phone the TV, with **Set up a TV** on the start screen.",
            "Playing on your own, or learning the game? Tap **Practice against bots** on the start screen. The bots play every part, and the Trials that need people in the room are left out. A practice game is a free game, so it has ads.",
        ]),
    ]

    private static let faqText: [(String, [String])] = [
        ("What is The Betrayal?", ["It’s a party game for 8 to 24 players in one room, each playing on their own phone. It’s best with 8 to 16. A few players are secretly the **Forsworn**, the traitors. Everyone else is **Loyal**, and has one evening to find them. Trials, which are quizzes and party games on the phones, fill a shared prize pot called the Purse. Each round, a secret vote exiles someone, which means they’re voted out. Each night, the Forsworn poison someone."]),
        ("Does everyone need the app?", ["Yes. Everyone plays on their own phone with The Betrayal app, the host included. Nobody needs to make an account, and joining a game is always free."]),
        ("How long does a game take?", ["About an hour for 8 to 10 players, an hour and a half for 12 to 16, and about two hours for 20 to 24. A Table, which is one game, stays open for 48 hours, so you can set it up in the afternoon."]),
        ("What does it cost?", [
            "Hosting is free. A free game shows a banner ad at the bottom of each phone’s screen. Each phone also shows a short full-screen ad when the debate before each vote starts, at night once that player has chosen, and at the end. There are never ads during a Trial or a vote. A free game plays 8 of the 15 Trials, with half the questions.",
            "• A **Night Pass** makes one night ad-free, with every Trial and the full question banks. Its 24 hours start the first time you use it, and every game you start in those 24 hours is ad-free.",
            "• The **Host Pass** is a yearly subscription. It makes every game you host ad-free, with every Trial.",
            "A pass belongs to the host, and it takes the ads away for everyone at the Table. Guests never need one. You can see the prices under **Your passes** on the start screen.",
        ]),
        ("Does the host get to play?", ["Yes. The host has a secret role like everyone else, and never sees anyone else’s. Their phone also has the buttons that move the game on. It begins each next part, starts each Trial once everyone has heard the rules, and can call a break, open the vote early or add a minute."]),
        ("Do we need a TV?", ["No, but it turns the game into a show. You can AirPlay the host’s phone to the TV. While the game is open, the TV shows the game, not what’s on the host’s phone. Or you can make an iPad or a spare phone the TV, with **Set up a TV** on the start screen. Without a TV, everyone joins with the code on the host’s phone."]),
        ("Can I try it on my own?", ["Yes. Tap **Practice against bots** on the start screen. The bots play every part, the clocks are shorter, and the Trials that need people in the room are left out. A practice game is a free game, so it shows ads, and a pass can’t be used on it."]),
        ("What if the Wi-Fi drops?", ["Every phone reconnects by itself and carries on where it was, because the game runs on our server, not on anyone’s phone. If someone’s battery dies, they can join again on another phone, and the host lets them back in. If it’s the host’s phone that dies, anyone at the Table can let the host back in. Once the host’s phone has been quiet for two minutes, another player can take over as host."]),
        ("Who wins the Purse?", ["If the Loyal win, they share the Purse they built. If the Forsworn win, they take what the Purse **fell short** of its target. That’s why the Forsworn want the Purse to stay low, and quietly spoil the Trials."]),
        ("I have a new phone. Where’s my pass?", ["To get a Host Pass on a new phone, tap **Restore purchases** under **Your passes**. A Night Pass stays on the phone that bought it. If you lose a phone with an unused Night Pass on it, Apple can refund it at reportaproblem.apple.com."]),
        ("How do I cancel the Host Pass?", ["Tap **Manage subscription** under **Your passes**, or go to your Apple Account’s subscriptions in Settings. You can cancel at any time. To stop it renewing, cancel at least 24 hours before the end of the year. It keeps working until the end of the year you’ve paid for."]),
        ("I saw an ad that shouldn’t be there.", ["Please tell us with **Report an ad** at the bottom of the start screen, or email us. Say what the ad showed, and roughly when. We’ll have it blocked."]),
        ("Who is it for?", ["Adults, at a party or a night in. It has themes of secrecy, betrayal and make-believe poisoning. Anyone under 18 should only play with a parent or guardian’s agreement."]),
    ]

    private static let termsText: [(String, [String])] = [
        ("", ["These terms apply when you play The Betrayal in the app, or buy a pass in it. Please read them before you buy. If you don’t agree with them, don’t buy or use a pass. The app itself is licensed to you under Apple’s standard licence agreement for apps (the link is below)."]),
        ("1. Who we are", ["The Betrayal is an independent business based in England. You can contact us at info@thebetrayal.co.uk."]),
        ("2. What you’re buying", [
            "Every game is played at a **Table**, an online game room. A Table can be played for **48 hours** from when it opens, then becomes read-only, and is deleted, with everything in it, 7 days after that. You can have one game open at a time with a pass: starting a new game closes the one that was open.",
            "• **A free game** costs nothing. It shows advertisements: a banner at the foot of the screen, and a short full-screen one on each phone as each Reckoning’s debate starts, at night once you’ve chosen, and at the end (never during a Trial or a vote). It uses the base set of Trials and questions. A practice game is a free game.",
            "• **A Night Pass** is one night without advertisements and with every Trial and the full question banks. Its **24 hours** start the first time you use it, to start a game or on a free game from its lobby, and every game you start in them is ad-free. If no game in those 24 hours gets past the Oath, the night comes back for another time.",
            "• **The Host Pass** (a yearly subscription) makes every game you host ad-free, with every Trial and the full question banks, for as long as the subscription is paid.",
            "A pass is for you and your own parties of 8 to 24 players in one place; you may not resell or share it with other hosts. A pass works only for Tables you host in this app. It is digital content: nothing is posted to you.",
            "To play, you need an internet connection and a phone with the app for each player; a TV is optional. We don’t supply these.",
        ]),
        ("3. Buying in the app", [
            "The price is shown in the app, in your currency, before you pay, and includes VAT where it applies. Payment is taken by Apple, through your Apple Account. We never see your card details, your name or your email address.",
            "Your contract with us starts when Apple confirms your payment and your pass is shown to you. The app keeps it on the phone you bought it on, under **Your passes**, and uses it when you start a game. **Restore purchases** brings a Host Pass to your other devices. A Night Pass stays on the phone it was bought on: if you lose that phone before using it, Apple can refund it (see 5).",
            "If a price is obviously wrong, we may cancel the purchase and have it refunded in full.",
        ]),
        ("4. The Host Pass: renewal and cancelling", [
            "The Host Pass renews automatically every year, at the price you agreed when you subscribed, and Apple takes the payment from your Apple Account, unless you cancel at least 24 hours before the end of the year. Cancel at any time in your Apple Account’s subscriptions (in Settings, or **Manage subscription** in the app). Cancelling stops future payments; your Host Pass keeps working until the end of the year you’ve paid for. If a payment fails, it stops opening new games until it’s paid. If the price changes, Apple tells you before it takes effect, and you can cancel first.",
        ]),
        ("5. Refunds and your right to cancel", [
            "Purchases in the app are refunded by Apple: ask at reportaproblem.apple.com. If Apple refunds a Night Pass whose 24 hours haven’t started, the pass is cancelled. You normally have 14 days to cancel a purchase of digital content, but you lose that right once the content is supplied; a pass is supplied as soon as you’ve paid. Apple’s own terms may give you more.",
        ]),
        ("6. If something goes wrong", [
            "The Consumer Rights Act 2015 says digital content must be as described, fit for purpose and of satisfactory quality. If the game doesn’t work as it should and we can’t fix it within a reasonable time, you are entitled to a repair, a replacement pass, or a refund. Contact us to ask. Nothing in these terms affects your legal rights.",
            "The game runs over the internet. We work to keep it available, but we can’t promise it will never be interrupted, for example by a problem with your own connection or network, or with our hosting provider. If an outage on our side spoils your party, contact us and we’ll put it right.",
        ]),
        ("7. Playing safely", [
            "You, as the host, are responsible for the party and for the people at it. In particular:",
            "• Some Trials have players standing on one leg or moving around the room. Clear the space, and let anyone sit out any part they don’t want to do.",
            "• The game has themes of secrecy, betrayal and (make-believe) poisoning. It is meant for adults. Anyone under 18 should only play with a parent or guardian’s agreement and supervision.",
            "• Please drink responsibly. Don’t let anyone drive after drinking.",
            "• Only put first names or nicknames into the game. See our privacy notice.",
        ]),
        ("8. Using the game fairly", ["Don’t try to break, overload, copy or get around the security of the service, guess other people’s passes or Table codes, or use it to break the law. We may cancel a pass, without refund, if it is used in breach of these terms."]),
        ("9. Our intellectual property", ["The name “The Betrayal” and its logo, artwork, music, questions, text and software belong to us or our licensors. The app, and any pass, gives you a personal, non-transferable licence to use the game for your parties. You may not copy, sell or distribute any part of it. Fonts are used under the SIL Open Font License."]),
        ("10. Our responsibility to you", [
            "If we break these terms, we are responsible for loss or damage you suffer that is a foreseeable result of our breach or our negligence. We are not responsible for loss that was not foreseeable. We only supply the game for domestic and private use, and are not liable to businesses for loss of profit, business or opportunity.",
            "We do not exclude or limit our liability where it would be unlawful to do so. That includes liability for death or personal injury caused by our negligence, for fraud, and for breaching your legal rights as a consumer.",
        ]),
        ("11. Changes", ["We may improve the game and change these terms from time to time. The terms that apply to your purchase are the ones in the app when you made it."]),
        ("12. Law and disputes", [
            "These terms are governed by the law of England and Wales. You can bring proceedings in the courts of England and Wales; if you live in Scotland or Northern Ireland you can also bring them in your local courts.",
            "If you have a complaint, please contact us first at info@thebetrayal.co.uk. We’ll reply within 24 hours.",
        ]),
    ]

    private static let privacyText: [(String, [String])] = [
        ("", ["This notice explains what personal information The Betrayal collects when you use the app, why, and what your rights are. We collect as little as we can: there are no accounts. Free games show ads from Google, as described below; games with a pass show none."]),
        ("Who is responsible for your data", ["The Betrayal is the controller of your personal data under the UK General Data Protection Regulation (UK GDPR) and the Data Protection Act 2018. Contact us at info@thebetrayal.co.uk."]),
        ("What we collect, and why", [
            "• **Purchases in the app.** Apple takes the payment, so we never receive your name, email address or card. Apple gives us the purchase’s references, the product, the price and currency, the country of your App Store, and whether a Host Pass is active. *Why:* to give you your pass, keep a Host Pass working while it’s paid, handle refunds and keep our accounts. *Lawful basis:* contract; legal obligation (tax records). *How long:* 6 years after the purchase, as UK tax law requires.",
            "• **Pass records:** each pass’s code, when it was created and used, and the Tables it opened. *Why:* to run the service and stop codes being misused. *Lawful basis:* contract. *How long:* 6 years, with the purchase.",
            "• **Game data:** what is entered to run a game, including the name or nickname each player types, the roles, answers, votes, last words, the messages the Forsworn send each other, and the score. *Why:* to run the game on the players’ phones and the TV. *Lawful basis:* contract (with the host); legitimate interests (for guests). *How long:* deleted automatically 7 days after the Table’s 48 hours run out.",
            "• **Diagnostics:** a record of each game as it is played (every change the host makes, so we can replay it to find and fix problems); and from each phone and TV at a Table, a log of what happened on it: the screens it showed, what was tapped or sent (never what was typed, though an error shown on the screen can repeat a name), the ads and offers it showed, purchases started, connection trouble, errors and crashes, with the device’s model and its system and app versions. Each device is a random number of its own at each Table, not linked from one Table to the next. *Why:* to find and fix problems, and see how the app and its ads are working. *Lawful basis:* legitimate interests (keeping the game working). *How long:* deleted with the Table.",
            "• **Counts:** how many games were started and got going, how many ads and offers were shown and tapped, and how many passes were bought, each day. Nothing about who. *Why:* to see how the app is used and whether free games pay for themselves. *Lawful basis:* legitimate interests. *How long:* kept as daily totals.",
            "• **Technical data:** your IP address and basic request details. *Why:* to deliver the game, keep it secure and limit repeated wrong codes. *Lawful basis:* legitimate interests (security). *How long:* wrong-guess counts are held in memory for up to an hour; our host’s logs are kept for up to 30 days.",
            "• **Problem reports** (Report a problem): what you tell us, your email if you give it, and this phone’s recent log at the Table (the diagnostics above). *Why:* to investigate the problem and reply to you. *Lawful basis:* legitimate interests. *How long:* 12 months.",
            "• **Messages you send us** by email. *Why:* to answer you. *Lawful basis:* legitimate interests. *How long:* 2 years.",
        ]),
        ("On your phone", [
            "The app keeps a few things on the phone itself, so it can take you back to your game: the name you last played under, your place at each Table you’ve joined, your last Table, and the passes you’ve bought or used. They never leave the phone except to play, and deleting the app deletes them.",
            "The camera is used only to read a Table’s QR code, when you choose to scan one. Nothing it sees is recorded or sent anywhere.",
            "Your choices about ads (Google’s consent form, and Apple’s question about tracking) are kept on the phone too. Change them with **Ad choices** on the start screen, where the law asks for it, and Apple’s in Settings, under Privacy & Security, Tracking.",
        ]),
        ("Guests at a party", ["If you’re a guest, the name or nickname you typed when you joined is in the game. It appears on the phones and the TV, we only use it to run that game, and it is deleted with the Table. We ask everyone to use first names or nicknames only. If you want your name removed sooner, ask the host, who can remove you, or contact us."]),
        ("Who we share it with", [
            "We don’t sell your data or share it for marketing. We use these providers:",
            "• **Cloudflare, Inc.** hosts the game server and the game rooms, forwards problem reports to our inbox, and processes data for us under contract.",
            "• **Apple** takes payments in the app and handles refunds and subscriptions, as an independent controller under its own privacy policy.",
            "• **Google Ireland Limited (AdMob)** shows the ads in free games, and only there: a game with a pass never starts it. When the app opens, it also asks Google’s consent service whether the law where you are needs your consent to ads, so that **Ad choices** can appear on the start screen; that request sends Google basic information about the device, such as its IP address. It may collect your device’s IP address, information about the device and app, and how you interact with ads, to show and measure ads and prevent fraud; it uses your device’s advertising identifier, and personalises ads, only if you agree in its consent form and allow tracking when Apple asks. If you don’t, the ads are not personalised. Google uses this data as an independent controller under its own privacy policy (policies.google.com/privacy). *Lawful basis:* consent for personalised ads; legitimate interests (paying for free games) for the rest.",
            "We may also share data where the law requires it.",
        ]),
        ("International transfers", ["Cloudflare, Apple and Google may process data outside the UK, including in the United States. When they do, the transfer is protected by the UK–US data bridge or by the UK International Data Transfer Addendum to the EU standard contractual clauses."]),
        ("Your rights", [
            "You have the right to ask for a copy of your data, and to have it corrected or deleted. You can also object to or restrict how we use it, and ask for it in a portable format. Ask us at info@thebetrayal.co.uk. We’ll reply within 24 hours, and complete your request within one month. There is normally no charge.",
            "If you’re unhappy with how we’ve handled your data, you can complain to the Information Commissioner’s Office at ico.org.uk or on 0303 123 1113. We’d appreciate the chance to put it right first.",
        ]),
        ("Changes", ["If we change this notice we’ll update the date at the top. If a change affects you significantly, we’ll tell you in the app."]),
    ]
}

struct PageView: View {
    let page: Page
    var close: (() -> Void)? = nil
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            Column {
                HStack {
                    Spacer()
                    if let close { Button("Close", action: close).glassButton() }
                }
                H1(page.title)
                if let u = page.updated { Small(u) }
                ForEach(Array(page.sections.enumerated()), id: \.offset) { _, s in
                    if !s.0.isEmpty { H2(s.0, sec: true) }
                    ForEach(Array(s.1.enumerated()), id: \.offset) { _, p in paragraph(p) }
                }
                if page == .terms {
                    Button("Apple’s licence agreement for apps") { openURL(Page.eula) }.btn(.ghost, .sm, fit: true).padding(.top, 8)
                }
                Button("Email us") { openURL(URL(string: "mailto:" + Page.contact)!) }.btn(.ghost, .sm, fit: true).padding(.top, 8)
            }
        }
        .background(Backdrop())
    }

    @ViewBuilder private func paragraph(_ p: String) -> some View {
        if p.hasPrefix("• ") {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("•").font(Theme.ui(18)).foregroundStyle(Theme.brass2)
                Para(rich(String(p.dropFirst(2))))
            }
        } else {
            Para(rich(p))
        }
    }
}

// **bold** and *italic* within a line
func rich(_ s: String, size: CGFloat = 18) -> Text {
    var out = Text("")
    var bold = false
    for (i, part) in s.components(separatedBy: "**").enumerated() {
        if i > 0 { bold.toggle() }
        for (j, bit) in part.components(separatedBy: "*").enumerated() {
            let t = Text(bit)
            out = out + (bold ? t.font(Theme.ui(size, .bold)) : j % 2 == 1 ? t.font(Theme.ui(size, .medium)).foregroundColor(Theme.tallow2) : t)
        }
    }
    return out
}
