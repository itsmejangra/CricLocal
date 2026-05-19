-- Matches table
CREATE TABLE IF NOT EXISTS matches (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  format TEXT NOT NULL,
  totalOvers INTEGER NOT NULL,
  playersPerSide INTEGER NOT NULL,
  team1Name TEXT NOT NULL,
  team2Name TEXT NOT NULL,
  tossWinner TEXT,
  tossDecision TEXT,
  venue TEXT,
  matchDate TEXT NOT NULL,
  status TEXT NOT NULL,
  winnerTeam TEXT,
  resultSummary TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL
);

-- Players table
CREATE TABLE IF NOT EXISTS players (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  teamName TEXT NOT NULL,
  matchId TEXT NOT NULL,
  battingOrder INTEGER,
  isKeeper INTEGER NOT NULL,
  isCaptain INTEGER NOT NULL,
  FOREIGN KEY (matchId) REFERENCES matches (id) ON DELETE CASCADE
);

-- Innings table
CREATE TABLE IF NOT EXISTS innings (
  id TEXT PRIMARY KEY,
  matchId TEXT NOT NULL,
  battingTeam TEXT NOT NULL,
  bowlingTeam TEXT NOT NULL,
  inningsNumber INTEGER NOT NULL,
  totalRuns INTEGER NOT NULL,
  totalWickets INTEGER NOT NULL,
  totalOversCompleted INTEGER NOT NULL,
  totalBallsInCurrentOver INTEGER NOT NULL,
  totalExtras INTEGER NOT NULL,
  wides INTEGER NOT NULL,
  noBalls INTEGER NOT NULL,
  byes INTEGER NOT NULL,
  legByes INTEGER NOT NULL,
  status TEXT NOT NULL,
  target INTEGER,
  FOREIGN KEY (matchId) REFERENCES matches (id) ON DELETE CASCADE
);

-- Deliveries table
CREATE TABLE IF NOT EXISTS deliveries (
  id TEXT PRIMARY KEY,
  inningsId TEXT NOT NULL,
  overNumber INTEGER NOT NULL,
  ballNumber INTEGER NOT NULL,
  batsmanId TEXT NOT NULL,
  nonStrikerId TEXT NOT NULL,
  bowlerId TEXT NOT NULL,
  runsScored INTEGER NOT NULL,
  extraRuns INTEGER NOT NULL,
  extraType TEXT,
  totalRuns INTEGER NOT NULL,
  isWicket INTEGER NOT NULL,
  dismissalType TEXT,
  dismissedPlayerId TEXT,
  fielder1Id TEXT,
  fielder2Id TEXT,
  isWide INTEGER NOT NULL,
  isNoBall INTEGER NOT NULL,
  isBye INTEGER NOT NULL,
  isLegBye INTEGER NOT NULL,
  isLegal INTEGER NOT NULL,
  commentary TEXT,
  timestamp TEXT NOT NULL,
  FOREIGN KEY (inningsId) REFERENCES innings (id) ON DELETE CASCADE
);

-- Batsman Innings
CREATE TABLE IF NOT EXISTS batsman_innings (
  id TEXT PRIMARY KEY,
  inningsId TEXT NOT NULL,
  playerId TEXT NOT NULL,
  runs INTEGER NOT NULL,
  ballsFaced INTEGER NOT NULL,
  fours INTEGER NOT NULL,
  sixes INTEGER NOT NULL,
  isOut INTEGER NOT NULL,
  dismissalType TEXT,
  bowlerId TEXT,
  fielder1Id TEXT,
  fielder2Id TEXT,
  battingPosition INTEGER NOT NULL,
  startTime TEXT NOT NULL,
  endTime TEXT,
  FOREIGN KEY (inningsId) REFERENCES innings (id) ON DELETE CASCADE
);

-- Bowler Innings
CREATE TABLE IF NOT EXISTS bowler_innings (
  id TEXT PRIMARY KEY,
  inningsId TEXT NOT NULL,
  playerId TEXT NOT NULL,
  ballsBowled INTEGER NOT NULL,
  maidens INTEGER NOT NULL,
  runsConceded INTEGER NOT NULL,
  wickets INTEGER NOT NULL,
  noBalls INTEGER NOT NULL,
  wides INTEGER NOT NULL,
  dotBalls INTEGER NOT NULL,
  FOREIGN KEY (inningsId) REFERENCES innings (id) ON DELETE CASCADE
);
