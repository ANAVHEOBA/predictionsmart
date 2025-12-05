# PredictionSmart - Full Feature List

Extracted from Polymarket UI analysis. This is the complete feature set we need to build.

---

## 1. Market Types

### 1.1 Binary Markets (Yes/No)
Simple two-outcome markets.

**Examples:**
- "Will China invade Taiwan in 2025?" → Yes / No
- "US national Bitcoin reserve in 2025?" → Yes / No
- "Will the US confirm that aliens exist in 2025?" → Yes / No
- "Will Trump acquire Greenland in 2025?" → Yes / No

**Data:**
- Question
- Yes price / No price
- Total volume
- Timeframe label (weekly, monthly, annual)

---

### 1.2 Multi-Outcome Markets (Multiple Choice)
Markets with more than 2 possible outcomes. Only ONE can win.

**Examples:**
- "Which party holds the most seats after Argentina Deputies Election?"
  - LLA (71%), UP (27%), PRO (<1%), UCR (<1%), etc.

- "Top Spotify Song 2025"
  - Die With a Smile (98%), Ordinary (1%), Golden (<1%), etc.

- "Game of the Year 2025"
  - Clair Obscur (94%), Hollow Knight (2%), Death Stranding 2 (2%), etc.

- "2026 NHL Stanley Cup Champion"
  - Colorado (18%), Tampa Bay (9%), Carolina (9%), etc.

- "StarLadder Budapest Major 2025 Winner"
  - FURIA (27%), Team Falcons (24%), Vitality (17%), etc.

**Data:**
- Question
- List of outcomes with individual Yes/No prices
- Total volume

---

### 1.3 Range/Bracket Markets
Price or value falls within a specific range. Multiple brackets, one wins.

**Examples:**
- "Solana price on December 1?"
  - <90, 90-100, 100-110, 110-120, 120-130, 130-140, 140-150, etc.

- "Bitcoin above ___ on December 3?"
  - 78,000, 80,000, 82,000, 84,000, 86,000, 88,000, 90,000, etc.

- "What price will gold close at in 2025?"
  - <$3200, $3200-$3300, $3300-$3400, ..., >$4000

- "Honduras Presidential Election Margin of Victory"
  - Nasralla <3%, Nasralla 3-6%, Nasralla 6-9%, etc.

**Data:**
- Question
- List of ranges/brackets with prices
- Total volume
- Timeframe (weekly, etc.)

---

### 1.4 Threshold Markets
"Will X reach Y by date Z?"

**Examples:**
- "Will Zcash hit $1000 by December 31?" → 7% chance
- "Hyperliquid all time high by December 31?" → 3% chance
- "Will MrBeast hit 105 Billion views by December 31?" → 87% chance

**Data:**
- Asset/metric
- Target threshold
- Deadline
- Current probability

---

### 1.5 Sports Markets
Live and upcoming sports events.

**Examples:**
- "Rayo Vallecano vs Valencia CF" → Rayo 47%, Draw, Valencia 24%
- "Rockets vs Jazz" → Rockets 85%, Jazz 16%
- "Utah vs Sharks" → Utah 61%, Sharks 40%
- "AFC Ajax vs FC Groningen" → Ajax 45%, Draw, Groningen 25%
- "College Football Playoff: #1 Overall Seed"

**Data:**
- Teams/participants
- Win probabilities (+ Draw for soccer)
- League (LALIGA, NBA, NHL, ERE, etc.)
- Start time
- Volume

---

### 1.6 Esports Markets
Competitive gaming events.

**Examples:**
- "PARIVISION vs NIP" → 52% vs 49%
- "StarLadder Budapest Major 2025 Winner"

**Data:**
- Teams
- Game (COUNTER STRIKE, etc.)
- Start time
- Volume

---

### 1.7 Geopolitical Markets
World events, conflicts, diplomacy.

**Examples:**
- "Will Russia capture Rodynske by December 31?" → 53%
- "US forces in Venezuela by December 31?" → 13%
- "Where will Zelenskyy and Putin meet next?"
- "Will China invade Taiwan in 2025?"

---

### 1.8 Entertainment/Culture Markets
Movies, music, gaming, celebrities.

**Examples:**
- "Which movie has second biggest opening weekend in 2025?"
- "Top Spotify Song 2025"
- "Game of the Year 2025"
- "Will MrBeast hit X Billion views?"

---

### 1.9 Weather/Climate Markets
Temperature, natural events.

**Examples:**
- "Where will 2026 rank among the hottest years on record?"
  - 1st (23%), 2nd (36%), 3rd (9%), 4th (32%), etc.

---

### 1.10 Finance/Earnings Markets
Stock prices, earnings, economic indicators.

**Examples:**
- "Mag 7: 52-Week High by December 31?"
  - Tesla (21%), Amazon (19%), Nvidia (14%), Microsoft (9%), Meta (1%)

---

## 2. Categories

From Polymarket navigation:

| Category | Description |
|----------|-------------|
| Trending | Hot markets by activity |
| Breaking | Recent news-related markets |
| New | Recently created markets |
| Politics | Elections, legislation, government |
| Sports | All sports betting |
| Finance | Stocks, earnings, economic |
| Crypto | Cryptocurrency prices, events |
| Geopolitics | International relations, conflicts |
| Earnings | Company earnings reports |
| Tech | Technology companies, products |
| Culture | Entertainment, celebrities |
| World | Global events |
| Economy | Economic indicators |
| Elections | Specific election markets |
| Mentions | Social media mentions |

---

## 3. Tags/Filters

Quick filter tags from Polymarket:

- Trump
- Ukraine
- Venezuela
- Honduras Election
- Equities
- Fed
- Thanksgiving
- Epstein
- Best of 2025
- Derivatives
- Gaza
- China
- Chile Election
- Google Search
- Gemini 3
- Parlays
- Earnings
- Global Elections
- Israel
- Trade War
- AI
- US Election
- Crypto Prices
- Bitcoin
- Weather
- Movies

---

## 4. Market Card Display

What each market card shows:

### Binary Market Card
```
┌─────────────────────────────────────────┐
│ [icon] Question text                    │
│                                         │
│         XX%                             │
│        chance                           │
│                                         │
│    [Yes]        [No]                    │
│                                         │
│ $XXk Vol.  |  timeframe                 │
└─────────────────────────────────────────┘
```

### Multi-Outcome Market Card
```
┌─────────────────────────────────────────┐
│ [icon] Question text                    │
│                                         │
│ Option A          XX%   [Yes XX%][No]   │
│ Option B          XX%   [Yes XX%][No]   │
│ Option C          XX%   [Yes XX%][No]   │
│ ...more options                         │
│                                         │
│ $XXm Vol.                               │
└─────────────────────────────────────────┘
```

### Sports Market Card
```
┌─────────────────────────────────────────┐
│ Team A            XX%                   │
│ Team B            XX%                   │
│                                         │
│ [Team A] [DRAW] [Team B]                │
│                                         │
│ $XXk Vol. | LEAGUE | TIME               │
└─────────────────────────────────────────┘
```

---

## 5. Market Data Fields

### Core Fields (All Markets)
| Field | Type | Description |
|-------|------|-------------|
| question | string | The prediction question |
| image_url | string | Market card icon/image |
| volume | u64 | Total trading volume |
| category | string | Primary category |
| tags | vector<string> | Searchable tags |
| created_at | u64 | Creation timestamp |
| end_date | u64 | When market resolves |
| status | u8 | Open, closed, resolved |

### Binary Market Fields
| Field | Type | Description |
|-------|------|-------------|
| yes_price | u64 | Current YES price (0-100) |
| no_price | u64 | Current NO price (0-100) |

### Multi-Outcome Market Fields
| Field | Type | Description |
|-------|------|-------------|
| outcomes | vector<Outcome> | List of possible outcomes |
| outcome.label | string | Outcome name |
| outcome.yes_price | u64 | YES price for this outcome |
| outcome.no_price | u64 | NO price for this outcome |

### Sports Market Fields
| Field | Type | Description |
|-------|------|-------------|
| team_a | string | First team/participant |
| team_b | string | Second team/participant |
| team_a_odds | u64 | Team A win probability |
| team_b_odds | u64 | Team B win probability |
| draw_odds | u64 | Draw probability (optional) |
| league | string | League name (NBA, NHL, etc.) |
| start_time | u64 | Event start time |

### Range Market Fields
| Field | Type | Description |
|-------|------|-------------|
| ranges | vector<Range> | List of brackets |
| range.min | u64 | Bracket minimum |
| range.max | u64 | Bracket maximum |
| range.price | u64 | Current price |

---

## 6. Timeframe Labels

Markets display different timeframe indicators:

| Label | Meaning |
|-------|---------|
| weekly | Resolves within a week |
| monthly | Resolves within a month |
| annual | Resolves within a year |
| specific date | "Dec 31", "December 3" |
| live | Currently happening (sports) |

---

## 7. Volume Display

Volume formatting:

| Raw Value | Display |
|-----------|---------|
| < 1,000 | $XXX |
| 1,000 - 999,999 | $XXk |
| 1,000,000+ | $XXm |

---

## 8. User Actions

What users can do:

| Action | Description |
|--------|-------------|
| Buy Yes | Purchase YES shares |
| Buy No | Purchase NO shares |
| Sell | Sell existing shares |
| View Details | Open full market page |
| Share | Share market link |
| Add to Watchlist | Track market |
| Create Market | Submit new market |

---

## 9. Special Features

### 9.1 Parlays
Combine multiple bets into one.

### 9.2 Earn 4%
Yield on deposits (liquidity provision?).

### 9.3 Live Markets
Real-time sports/esports with live updates.

---

## 10. Resolution Sources

How different market types resolve:

| Market Type | Resolution Source |
|-------------|-------------------|
| Crypto Prices | Pyth/Oracle price feed |
| Sports | Official game results |
| Elections | Official election results |
| Geopolitical | News sources / Admin |
| Entertainment | Official announcements |
| Weather | Official weather data |

---

## 11. Implementation Priority

### Phase 1 (MVP)
- [ ] Binary markets (Yes/No)
- [ ] Basic categories
- [ ] Volume tracking
- [ ] Admin resolution

### Phase 2
- [ ] Multi-outcome markets
- [ ] Range/bracket markets
- [ ] Tags/filters
- [ ] Pyth oracle integration

### Phase 3
- [ ] Sports markets with live data
- [ ] Esports markets
- [ ] Timeframe labels
- [ ] Advanced resolution types

### Phase 4
- [ ] Parlays
- [ ] Yield/earn features
- [ ] User-created markets
- [ ] Reputation system

---

## 12. Summary Stats

From the Polymarket page analyzed:

- **Market Types**: Binary, Multi-outcome, Range, Sports, Esports
- **Categories**: 15+ categories
- **Tags**: 25+ quick filter tags
- **Volume Range**: $57k to $38m per market
- **Timeframes**: Weekly, Monthly, Annual, Specific dates
- **Sports Leagues**: NBA, NHL, LALIGA, ERE, TUR, etc.
- **Esports**: Counter Strike, others
