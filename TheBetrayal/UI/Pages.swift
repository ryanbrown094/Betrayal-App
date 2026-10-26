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
        case .rules: return "How to play"
        case .faq: return "FAQs"
        case .terms: return "Terms of sale and use"
        case .privacy: return "Privacy notice"
        }
    }
    var updated: String? { self == .rules || self == .faq ? nil : "Last updated: 26 October 2026" }

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
        ("", ["Everything that happens at a night of The Betrayal, from the first oath to the last betrayal. You don’t need to learn any of it before the night: every phone tells its player what to do, when."]),
        ("The idea", [
            "A few of your guests are secretly **Forsworn**. Everyone else is one of the **Loyal**. Every night the Forsworn poison someone, and every day the table votes to throw someone out. The Loyal win if they find every Forsworn before the end. The Forsworn win if even one of them is still at the table when the game finishes.",
            "In between, you play party games for a shared Purse and for protection, you argue, you make alliances, and you lie to people you’ve known for years. A typical game lasts an hour or two. Play it with drinks and snacks.",
        ]),
        ("Joining", [
            "The host starts a Table in The Betrayal app (free, or ad-free with a pass) and types their name. Everyone else opens The Betrayal app, types the six-character Table code (or scans the QR code on the TV) and their name. There’s no account to make. The TV is optional: without one, the host just reads the code out. When everyone’s in, the host taps **Start**.",
        ]),
        ("Who’s who", [
            "**The Loyal** are most of the table. They don’t know who anyone else is. Their job is to work out who the Forsworn are and vote them out, with nothing to go on but conversation, voting patterns and gut feeling.",
            "**The Forsworn** are about one guest in four or five, and their phones tell them who the others are. Each night they choose who is poisoned. By day they act like the Loyal, steer the vote, and quietly sabotage the Trials.",
            "**The host** has a secret role like everyone else and never sees anyone else’s. Their phone also moves the evening on, beginning the next part or calling a break. The game plans its own Trials and Reckonings.",
            "The night begins with **the Oath**. Every phone asks its player, privately: would you like to be Forsworn? Yes, make me Forsworn; I’d rather be Loyal; or Either way. The roles are dealt from the answers (volunteers first), though nobody is promised what they asked for. Then each player looks at their role with their phone held close.",
            "Nobody is told how many Forsworn there are. Players only find out as Forsworn are exiled and revealed.",
        ]),
        ("A round", [
            "The game is played in rounds, planned from the size of the table so that the final starts with five or fewer. Each round goes like this:",
            "• **A Trial.** A party game played on the phones: a quiz, a guessing game, charades and so on (all of them are listed below). Each question closes by itself when everyone has answered or the clock runs out. Trials add to the Purse, and most give Sanctuary to the winner. Most tables open the evening with Most Likely To, as the icebreaker.",
            "• **The Reckoning.** A few minutes of open debate on a timer, then everyone votes on their phone, in secret. The vote closes when everyone’s in. The player with the most votes is exiled. A tie goes to a revote between the tied players; a second tie is settled by lot. At a table bigger than sixteen, there are two exiles.",
            "• **The reveal.** The exiled player’s role is shown: Forsworn or Loyal. They can type one last line for the TV on the way out.",
            "• **The night.** Heads down. The Forsworn choose a victim on their phones (two at a table of twelve or more, three at twenty or more). Everyone else taps someone too, so nobody at the table can tell who is choosing. The Forsworn can also whisper to each other in set phrases (“Vote with me tomorrow”). A player holding Sanctuary can’t be poisoned.",
            "• **Dawn.** The victim learns first, in secret on their phone. Then the host reveals the night to everyone. The victim was poisoned: they stand, announce it and get thirty seconds of last words, then leave the table. If the table voted them most likely to something, the TV remembers that too.",
            "The host can call a short break whenever they like, or pause the game, which stops every clock, for the doorbell or a top-up. If someone is taken ill, the host can take them out of the game without anyone learning their role.",
        ]),
        ("The dead", [
            "Nobody goes home when they’re out. Exiled and poisoned players become **Ghosts**: they stay at the party and watch the game on their phones. They can’t vote, but at every Reckoning they can call who they think goes, and the table is told which Ghosts called it. In The Statue, the Ghosts do their worst to make the living laugh.",
        ]),
        ("Sanctuary", [
            "Sanctuary protects its holder from that night’s poison. It’s the prize in most Trials, and it lasts one night. At most a quarter of the table can hold one at the same time. The host chooses at the start whether Sanctuary is won **in public**, named for everyone, or **in secret**, so only the winner knows they’re safe. A Forsworn who wins a secret Sanctuary gets nothing, and is the only one who knows.",
        ]),
        ("Twists", [
            "Each comes once in the evening, and the phones explain it when it happens. The host can switch them all off before the start, for a plainer first game.",
            "• **The Casting Vote**, about halfway: its Trial’s winner gets it instead of Sanctuary, and nobody else knows who. If a Reckoning ties and they voted for one of the tied players, their vote decides it.",
            "• **The Temptation**: everyone chooses, in secret, PURSE or SELF. Exactly one SELF takes Sanctuary and the Purse grows. Nobody, and it grows double. Two or more, and nobody gets it, and the Purse shrinks.",
            "• **The Crown**, on the last round before the final: named for everyone, it brings Sanctuary that night, and once, at a Reckoning, its holder can lay it down to be safe from that exile.",
            "• **The Confessor**, in the final: the winner of its Trial is told, privately, the name of a Forsworn still at the table.",
        ]),
        ("The Purse", [
            "Every Trial adds to a shared Purse, up to its target: the better the table plays, the more goes in. The winners take it at the end: the Loyal take what they built, but the Forsworn take what it fell short of the target, so every point they quietly sabotage is theirs. Each wrong answer from a Forsworn costs the Purse, and the table hears how many there were, never whose. A Loyal player can guess freely, so a shrinking Purse is a clue.",
            "There is also **a prize**, chosen by the host: something worth lying to your friends for. If they don’t choose one, it’s chocolate coins, one for every 100 points the winners take from the Purse. The host can set better prizes for a fuller Purse, or, if the Forsworn win, an emptier one; the table knows the Purse decides the prize, but not what it is.",
        ]),
        ("The end game", [
            "The last round is **the final**, with five or fewer at the table.",
            "• **A last Trial**, for the Purse and perhaps something more. There’s no Sanctuary in the final, because there is no night left to survive.",
            "• **The Reckoning, without reveals.** The table votes a player out, but this time their role is not shown.",
            "• **Trust or Doubt.** With four or fewer left, each survivor chooses on their phone, in secret: TRUST if they believe every Forsworn is gone, DOUBT if not. Only a unanimous TRUST ends the game. Otherwise, it’s back to the Reckoning for another exile, and another vote.",
            "• **The Unmasking.** One by one, the last players’ roles are turned over. If only Loyal are left, the Loyal win and share the Purse. If a Forsworn is still at the table, the Forsworn win, and take what the Purse fell short.",
            "• **The last betrayal.** If two or more Forsworn survive, each chooses in secret: HONOUR or BETRAY. If they all honour the pact, they share the winnings. If one betrays, they take everything. If two or more betray, nobody does.",
            "• **The awards.** Everyone’s role, then up to six awards for the night: The Grand Deceiver, The Sharpest Eye, Barking Up the Wrong Tree, The Ghost Who Saw and more.",
        ]),
        ("Trials", [
            "The game deals them in a random order, so no two evenings run the same.",
            "• **Most Likely To.** A prompt on every phone. Vote for the person it fits best, and see the verdict. There’s no prize, only a reputation.",
            "• **Rapid Quiz.** Eight questions, easy to brutal. Type your answer before the clock runs out: a point for every right answer, and one more for the fastest.",
            "• **Longest Word.** Twelve letters. Type the longest real word you can make from them.",
            "• **Closest Guess.** A question with a number for an answer. The closest guesses score.",
            "• **Memory Wall.** Twelve words appear, then vanish. Type every one you remember.",
            "• **Snap.** A symbol changes every few seconds. When it matches the one before, tap SNAP. A wrong tap costs you.",
            "• **Rock Paper Scissors Royale.** Paired off at random, choose on your phone. Lose and you’re out, until one is left standing.",
            "• **One Leg.** Everyone up, on one leg. Put a foot down and tap “I’m out”. Last one standing wins.",
            "• **Screen Charades.** One player at a time gets a secret word on their phone and acts it out. When someone guesses, the actor taps who.",
            "• **Hum It.** Like charades, but the phone gives you a song to hum.",
            "• **Draw It.** Like charades, but you draw it: on paper, a board, or in the air. No letters, no numbers.",
            "• **The Statue.** The living freeze. The Ghosts may do anything, short of touching, to make them move or laugh.",
            "• **Two Truths and a Lie.** One player tells three things about themselves. Everyone else votes on their phone for the lie.",
            "• **Higher or Lower.** A question and a number: is the real answer higher or lower?",
            "• **What Changed?** Twelve symbols appear. They vanish, and come back with something different. Tap what changed; the first right answer scores double.",
            "The quiz, charades, songs, pictures and guessing games draw on a bank of thousands of questions and prompts, and nothing repeats within a game.",
        ]),
        ("What you need", [
            "• 8 to 24 players. 8 to 16 is the sweet spot.",
            "• An hour or two: about an hour for 8 to 10 players, an hour and a half for 12 to 16, and about two hours for 20 to 24.",
            "• A prize.",
            "On your own, or learning the game? **Practice against bots** on the start screen: the bots play every part, and the Trials that need people in the room are left out.",
            "• A phone each, with The Betrayal app. A TV makes it a show, but it’s optional: AirPlay the host’s phone to it (the TV shows the game, never the phone’s screen), or open the app on an iPad connected to it and choose **Use this screen as the TV**.",
        ]),
    ]

    private static let faqText: [(String, [String])] = [
        ("What is The Betrayal?", ["A party game for 8 to 24 players in one room, best with 8 to 16, each playing on their own phone. A few players are secretly the **Forsworn**; the rest, the **Loyal**, have one evening to find them. Trials (quizzes and party games on the phones) fill a shared Purse, a secret vote exiles someone each round, and each night the Forsworn poison someone."]),
        ("Does everyone need the app?", ["Yes: everyone plays on their own phone with The Betrayal app, the host included. There’s no account to make, and joining a game is always free."]),
        ("How long does a game take?", ["About an hour for 8 to 10 players, an hour and a half for 12 to 16, and about two hours for 20 to 24. A Table stays open for 48 hours, so you can set it up in the afternoon."]),
        ("What does it cost?", [
            "Hosting is free. A free game shows an ad between rounds, never while you play, and plays 8 of the 15 Trials with half the questions.",
            "• A **Night Pass** makes one night ad-free, with every Trial and the full question banks: every game you start in the 24 hours after you first use it.",
            "• The **Host Pass**, a yearly subscription, makes every game you host ad-free, with every Trial.",
            "A pass is the host’s, and takes the ads away for everyone at the Table: guests never need one. The prices are under **Your passes**.",
        ]),
        ("Does the host get to play?", ["Yes. The host has a secret role like everyone else and never sees anyone else’s. Their phone also moves the evening on, beginning the next part or calling a break."]),
        ("Do we need a TV?", ["No, but it makes it a show. AirPlay the host’s phone to it (the TV shows the game, never the phone’s screen), or open the app on an iPad connected to it and choose **Use this screen as the TV** under **Join a game**. Without a TV, the host just reads out the Table code."]),
        ("Can I try it on my own?", ["Yes: **Practice against bots** on the start screen. The bots play every part, the clocks are short, and the Trials that need people in the room are left out."]),
        ("What if the Wi-Fi drops?", ["Every phone reconnects by itself and picks up where it was: the game lives on our server, not on anyone’s phone. If someone’s battery dies, they join again on another phone, and the host lets them back in."]),
        ("Who wins the Purse?", ["The Loyal, if they win, share the Purse they built. The Forsworn, if they win, take what it **fell short** of its target, so every point they quietly sabotage is theirs."]),
        ("I have a new phone. Where’s my pass?", ["A Host Pass comes back with **Restore purchases**, under **Your passes**. If you lose a phone with an unused Night Pass on it, email us the order ID from Apple’s receipt and we’ll restore it."]),
        ("How do I cancel the Host Pass?", ["With **Manage subscription** under **Your passes**, or in your Apple Account’s subscriptions in Settings, at any time up to 24 hours before the end of the year. It keeps working until the end of the year you’ve paid for."]),
        ("I saw an ad that shouldn’t be there.", ["Please tell us with **Report an ad** at the foot of the start screen, or email us: what it showed, and roughly when. We’ll have it blocked."]),
        ("Who is it for?", ["Adults, at a party or a night in: it has themes of secrecy, betrayal and make-believe poisoning. Anyone under 18 should only play with a parent or guardian’s agreement."]),
    ]

    private static let termsText: [(String, [String])] = [
        ("", ["These terms apply when you play The Betrayal in the app, or buy a pass in it. Please read them before you buy. If you don’t agree with them, don’t buy or use a pass. The app itself is licensed to you under Apple’s standard licence agreement for apps (the link is below)."]),
        ("1. Who we are", ["The Betrayal is an independent business based in England. You can contact us at info@thebetrayal.co.uk."]),
        ("2. What you’re buying", [
            "Every game is played at a **Table**, an online game room. A Table can be played for **48 hours** from when it opens, then becomes read-only, and is deleted, with everything in it, 7 days after that. You can have one game open at a time with a pass: starting a new game closes the one that was open.",
            "• **A free game** costs nothing. It shows an advertisement between rounds, never while you play, and uses the base set of Trials and questions.",
            "• **A Night Pass** is one night without advertisements and with every Trial and the full question banks. Its **24 hours** start the first time you use it, to start a game or on a free game from its lobby, and every game you start in them is ad-free. If no game in those 24 hours gets past the Oath, the night comes back for another time.",
            "• **The Host Pass** (a yearly subscription) gives you one code that makes every game you host ad-free, with every Trial and the full question banks, for as long as the subscription is paid.",
            "A pass is for you and your own parties of 8 to 24 players in one place; you may not resell or share it with other hosts. A pass works only for Tables you host in this app. It is digital content: nothing is posted to you.",
            "To play, you need an internet connection and a phone with the app for each player; a TV is optional. We don’t supply these.",
        ]),
        ("3. Buying in the app", [
            "The price is shown in the app, in your currency, before you pay, and includes VAT where it applies. Payment is taken by Apple, through your Apple Account. We never see your card details, your name or your email address.",
            "Your contract with us starts when Apple confirms your payment and your pass is shown to you. The app keeps it on the phone you bought it on, under **Your passes**, and uses it when you start a game. **Restore purchases** brings a Host Pass to your other devices. If you lose the phone with an unused Night Pass on it, contact us with the order ID from Apple’s receipt and we’ll restore it.",
            "If a price is obviously wrong, we may cancel the purchase and have it refunded in full.",
        ]),
        ("4. The Host Pass: renewal and cancelling", [
            "The Host Pass renews automatically every year, at the price you agreed when you subscribed, and Apple takes the payment from your Apple Account, unless you cancel at least 24 hours before the end of the year. Cancel at any time in your Apple Account’s subscriptions (in Settings, or **Manage subscription** in the app). Cancelling stops future payments; your code keeps working until the end of the year you’ve paid for. If a payment fails, the code stops opening new games until it’s paid. If the price changes, Apple tells you before it takes effect, and you can cancel first.",
        ]),
        ("5. Refunds and your right to cancel", [
            "Purchases in the app are refunded by Apple: ask at reportaproblem.apple.com. If Apple refunds a Night Pass whose 24 hours haven’t started, its code is cancelled. You normally have 14 days to cancel a purchase of digital content, but you lose that right once the content is supplied; a pass is supplied as soon as you’ve paid. Apple’s own terms may give you more.",
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
            "• **Game data:** what is entered to run a game, including the name or nickname each player types, the roles, answers, votes and the score. *Why:* to run the game on the players’ phones and the TV. *Lawful basis:* contract (with the host); legitimate interests (for guests). *How long:* deleted automatically 7 days after the Table’s 48 hours run out.",
            "• **Diagnostics:** a record of each game as it is played (every change the host makes, so we can replay it to find and fix problems). *Lawful basis:* legitimate interests (keeping the game working). *How long:* deleted with the Table.",
            "• **Counts:** how many games were started and got going, how many ads and offers were shown and tapped, and how many passes were bought, each day. Nothing about who. *Why:* to see how the app is used and whether free games pay for themselves. *Lawful basis:* legitimate interests. *How long:* kept as daily totals.",
            "• **Technical data:** your IP address and basic request details. *Why:* to deliver the game, keep it secure and limit repeated wrong codes. *Lawful basis:* legitimate interests (security). *How long:* wrong-guess counts are held in memory for up to an hour; our host’s logs are kept for up to 30 days.",
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
            "• **Cloudflare, Inc.** hosts the game server and the game rooms, and processes data for us under contract.",
            "• **Apple** takes payments in the app and handles refunds and subscriptions, as an independent controller under its own privacy policy.",
            "• **Google Ireland Limited (AdMob)** shows the ads in free games, and only there: a game with a pass never starts it. It may collect your device’s IP address, information about the device and app, and how you interact with ads, to show and measure ads and prevent fraud; it uses your device’s advertising identifier, and personalises ads, only if you agree in its consent form and allow tracking when Apple asks. If you don’t, the ads are not personalised. Google uses this data as an independent controller under its own privacy policy (policies.google.com/privacy). *Lawful basis:* consent for personalised ads; legitimate interests (paying for free games) for the rest.",
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
                    if let close { Button("Close", action: close).btn(.dark, .sm, fit: true) }
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
