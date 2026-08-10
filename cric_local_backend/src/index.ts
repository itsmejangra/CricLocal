export interface Env {
	DB: D1Database;
}

async function autoAbandonExpiredMatches(db: D1Database): Promise<void> {
	try {
		const liveMatches = await db.prepare("SELECT id, updatedAt FROM matches WHERE status = 'live'").all();
		const now = Date.now();
		const oneDayMs = 24 * 60 * 60 * 1000;
		const idsToAbandon: string[] = [];
		for (const match of liveMatches.results) {
			const updatedTime = new Date(match.updatedAt as string).getTime();
			if (now - updatedTime > oneDayMs) {
				idsToAbandon.push(match.id as string);
			}
		}
		if (idsToAbandon.length > 0) {
			const nowIso = new Date().toISOString();
			for (const id of idsToAbandon) {
				await db.prepare("UPDATE matches SET status = 'abandoned', updatedAt = ? WHERE id = ?").bind(nowIso, id).run();
			}
		}
	} catch (e) {
		console.error("Error auto-abandoning expired matches:", e);
	}
}

export default {
	async fetch(request: Request, env: Env): Promise<Response> {
		const url = new URL(request.url);
		const { pathname, searchParams } = url;

		// Helper to handle CORS
		const corsHeaders = {
			"Access-Control-Allow-Origin": "*",
			"Access-Control-Allow-Methods": "GET, POST, OPTIONS",
			"Access-Control-Allow-Headers": "Content-Type",
		};

		if (request.method === "OPTIONS") {
			return new Response(null, { headers: corsHeaders });
		}

		try {
			// Auto abandon expired live matches on any database read/write
			await autoAbandonExpiredMatches(env.DB);

			// ── SYNC MATCH ────────────────────────────────────────────────────────
			if (pathname === "/sync-match" && request.method === "POST") {
				const match = await request.json();
				await env.DB.prepare(`
					INSERT INTO matches (id, title, format, totalOvers, playersPerSide, team1Name, team2Name, venue, matchDate, status, resultSummary, createdAt, updatedAt, creatorId, youtubeVideoId)
					VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
					ON CONFLICT(id) DO UPDATE SET
						status = excluded.status,
						resultSummary = excluded.resultSummary,
						updatedAt = excluded.updatedAt,
						creatorId = excluded.creatorId,
						youtubeVideoId = excluded.youtubeVideoId
				`).bind(
					match.id, match.title, match.format, match.totalOvers, match.playersPerSide,
					match.team1Name, match.team2Name, match.venue ?? null, match.matchDate,
					match.status, match.resultSummary ?? null, match.createdAt, match.updatedAt,
					match.creatorId ?? null, match.youtubeVideoId ?? null
				).run();
				return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── SYNC INNINGS ─────────────────────────────────────────────────────
			if (pathname === "/sync-innings" && request.method === "POST") {
				const inn = await request.json();
				await env.DB.prepare(`
					INSERT INTO innings (id, matchId, battingTeam, bowlingTeam, inningsNumber, totalRuns, totalWickets, totalOversCompleted, totalBallsInCurrentOver, totalExtras, wides, noBalls, byes, legByes, status, target, currentStrikerId, currentNonStrikerId, currentBowlerId)
					VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
					ON CONFLICT(id) DO UPDATE SET
						totalRuns = excluded.totalRuns, totalWickets = excluded.totalWickets,
						totalOversCompleted = excluded.totalOversCompleted, totalBallsInCurrentOver = excluded.totalBallsInCurrentOver,
						totalExtras = excluded.totalExtras, wides = excluded.wides,
						noBalls = excluded.noBalls, byes = excluded.byes,
						legByes = excluded.legByes, status = excluded.status, target = excluded.target,
						currentStrikerId = excluded.currentStrikerId, currentNonStrikerId = excluded.currentNonStrikerId, currentBowlerId = excluded.currentBowlerId
				`).bind(
					inn.id, inn.matchId, inn.battingTeam, inn.bowlingTeam, inn.inningsNumber,
					inn.totalRuns, inn.totalWickets, inn.totalOversCompleted, inn.totalBallsInCurrentOver,
					inn.totalExtras, inn.wides, inn.noBalls, inn.byes, inn.legByes, inn.status, inn.target ?? null,
					inn.currentStrikerId ?? null, inn.currentNonStrikerId ?? null, inn.currentBowlerId ?? null
				).run();
				return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── SYNC DELIVERY ─────────────────────────────────────────────────────
			if (pathname === "/sync-delivery" && request.method === "POST") {
				const ball = await request.json();
				await env.DB.prepare(`
					INSERT INTO deliveries (id, inningsId, overNumber, ballNumber, batsmanId, nonStrikerId, bowlerId, runsScored, extraRuns, extraType, totalRuns, isWicket, dismissalType, dismissedPlayerId, fielder1Id, fielder2Id, isWide, isNoBall, isBye, isLegBye, isLegal, commentary, timestamp)
					VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
					ON CONFLICT(id) DO NOTHING
				`).bind(
					ball.id, ball.inningsId, ball.overNumber, ball.ballNumber, ball.batsmanId,
					ball.nonStrikerId, ball.bowlerId, ball.runsScored, ball.extraRuns, ball.extraType ?? null,
					ball.totalRuns, ball.isWicket ? 1 : 0, ball.dismissalType ?? null, ball.dismissedPlayerId ?? null,
					ball.fielder1Id ?? null, ball.fielder2Id ?? null, ball.isWide ? 1 : 0, ball.isNoBall ? 1 : 0,
					ball.isBye ? 1 : 0, ball.isLegBye ? 1 : 0, ball.isLegal ? 1 : 0, ball.commentary ?? null, ball.timestamp ?? null
				).run();
				return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── SYNC PLAYER ─────────────────────────────────────────────────────
			if (pathname === "/sync-player" && request.method === "POST") {
				const p = await request.json();
				// Normalize name: remove (c), (C), (k), (K), (c&k), etc.
				let normalizedName = p.name ? p.name.replace(/\s*\(c\)\s*$/i, '')
												.replace(/\s*\(k\)\s*$/i, '')
												.replace(/\s*\(c&k\)\s*$/i, '')
												.replace(/\s*\(†\)\s*$/i, '')
												.trim() : p.name;

				await env.DB.prepare(`
					INSERT INTO players (id, name, teamName, matchId, battingOrder, isKeeper, isCaptain)
					VALUES (?, ?, ?, ?, ?, ?, ?)
					ON CONFLICT(id) DO UPDATE SET
						name = excluded.name, battingOrder = excluded.battingOrder,
						isKeeper = excluded.isKeeper, isCaptain = excluded.isCaptain
				`).bind(p.id, normalizedName, p.teamName, p.matchId, p.battingOrder ?? null, p.isKeeper ? 1 : 0, p.isCaptain ? 1 : 0).run();
				return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── SYNC BATSMAN INNINGS ─────────────────────────────────────────────────────
			if (pathname === "/sync-batsman-innings" && request.method === "POST") {
				const bi = await request.json();
				await env.DB.prepare(`
					INSERT INTO batsman_innings (id, inningsId, playerId, runs, ballsFaced, fours, sixes, isOut, dismissalType, dismissalDescription, battingPosition, startTime, endTime)
					VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
					ON CONFLICT(id) DO UPDATE SET
						runs = excluded.runs, ballsFaced = excluded.ballsFaced,
						fours = excluded.fours, sixes = excluded.sixes,
						isOut = excluded.isOut, dismissalType = excluded.dismissalType,
						dismissalDescription = excluded.dismissalDescription, endTime = excluded.endTime
				`).bind(
					bi.id, bi.inningsId, bi.playerId, bi.runs ?? 0, bi.ballsFaced ?? 0, bi.fours ?? 0, bi.sixes ?? 0,
					bi.isOut ? 1 : 0, bi.dismissalType ?? null, bi.dismissalDescription ?? null,
					bi.battingPosition ?? 0, bi.startTime ?? null, bi.endTime ?? null
				).run();
				return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── SYNC BOWLER INNINGS ─────────────────────────────────────────────────────
			if (pathname === "/sync-bowler-innings" && request.method === "POST") {
				const bi = await request.json();
				await env.DB.prepare(`
					INSERT INTO bowler_innings (id, inningsId, playerId, ballsBowled, maidens, runsConceded, wickets, noBalls, wides, dotBalls)
					VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
					ON CONFLICT(id) DO UPDATE SET
						ballsBowled = excluded.ballsBowled, maidens = excluded.maidens,
						runsConceded = excluded.runsConceded, wickets = excluded.wickets,
						noBalls = excluded.noBalls, wides = excluded.wides, dotBalls = excluded.dotBalls
				`).bind(
					bi.id, bi.inningsId, bi.playerId, bi.ballsBowled ?? 0, bi.maidens ?? 0,
					bi.runsConceded ?? 0, bi.wickets ?? 0, bi.noBalls ?? 0, bi.wides ?? 0, bi.dotBalls ?? 0
				).run();
				return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── GET ALL MATCHES ────────────────────────────────────────────────────
			if (pathname === "/matches" && request.method === "GET") {
				const creatorId = searchParams.get("creatorId");
				let matches;
				if (creatorId) {
					matches = await env.DB.prepare("SELECT * FROM matches WHERE creatorId = ? ORDER BY createdAt DESC LIMIT 50").bind(creatorId).all();
				} else {
					matches = await env.DB.prepare("SELECT * FROM matches ORDER BY createdAt DESC LIMIT 50").all();
				}
				return new Response(JSON.stringify(matches.results), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── UPDATE YOUTUBE VIDEO ID ───────────────────────────────────────────
			if (pathname.startsWith("/match/") && pathname.endsWith("/youtube") && request.method === "POST") {
				const matchId = pathname.split("/")[2];
				const { youtubeVideoId } = await request.json();
				await env.DB.prepare(`
					UPDATE matches SET youtubeVideoId = ?, updatedAt = ? WHERE id = ?
				`).bind(youtubeVideoId ?? null, new Date().toISOString(), matchId).run();
				return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── GET LIVE MATCH ────────────────────────────────────────────────────
			if (pathname.startsWith("/match/") && !pathname.endsWith("/youtube") && request.method === "GET") {
				const matchId = pathname.split("/")[2];
				const match = await env.DB.prepare("SELECT * FROM matches WHERE id = ?").bind(matchId).first();
				if (!match) return new Response("Match not found", { status: 404, headers: corsHeaders });

				const innings = await env.DB.prepare("SELECT * FROM innings WHERE matchId = ? ORDER BY inningsNumber ASC").bind(matchId).all();
				const allPlayers = await env.DB.prepare("SELECT * FROM players WHERE matchId = ?").bind(matchId).all();
				let recentDeliveries = { results: [] };
				let batsmanStats = { results: [] };
				let bowlerStats = { results: [] };
				
				if (innings.results.length > 0) {
					const inningsIds = innings.results.map((inn: any) => `'${inn.id}'`).join(',');
					recentDeliveries = await env.DB.prepare(`SELECT * FROM deliveries WHERE inningsId IN (${inningsIds}) ORDER BY timestamp DESC`).all();
					
					// Get all batsman and bowler stats for the match
					batsmanStats = await env.DB.prepare(`SELECT * FROM batsman_innings WHERE inningsId IN (${inningsIds})`).all();
					bowlerStats = await env.DB.prepare(`SELECT * FROM bowler_innings WHERE inningsId IN (${inningsIds})`).all();
				}

				return new Response(JSON.stringify({
					match: match,
					innings: innings.results,
					recentDeliveries: recentDeliveries.results.reverse(),
					allPlayers: allPlayers.results,
					batsmanStats: batsmanStats.results,
					bowlerStats: bowlerStats.results
				}), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── SYNC SAVED TEAM ──────────────────────────────────────────────────
			if (pathname === "/sync-saved-team" && request.method === "POST") {
				const team = await request.json();
				await env.DB.prepare(`
					INSERT INTO saved_teams (id, name, createdAt, updatedAt, creatorId)
					VALUES (?, ?, ?, ?, ?)
					ON CONFLICT(id) DO UPDATE SET
						name = excluded.name,
						updatedAt = excluded.updatedAt,
						creatorId = excluded.creatorId
				`).bind(team.id, team.name, team.createdAt, team.updatedAt, team.creatorId ?? null).run();
				return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── SYNC SAVED TEAM PLAYER ───────────────────────────────────────────
			if (pathname === "/sync-saved-team-player" && request.method === "POST") {
				const p = await request.json();
				await env.DB.prepare(`
					INSERT INTO saved_team_players (id, teamId, name, orderIndex, isCaptain)
					VALUES (?, ?, ?, ?, ?)
					ON CONFLICT(id) DO UPDATE SET
						name = excluded.name,
						orderIndex = excluded.orderIndex,
						isCaptain = excluded.isCaptain
				`).bind(p.id, p.teamId, p.name, p.orderIndex, p.isCaptain ?? 0).run();
				return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── DELETE SAVED TEAM ────────────────────────────────────────────────
			if (pathname === "/delete-saved-team" && request.method === "POST") {
				const body = await request.json();
				const teamId = body.id;
				const creatorId = body.creatorId;

				if (creatorId) {
					// Verify ownership before delete
					const team = await env.DB.prepare("SELECT id FROM saved_teams WHERE id = ? AND creatorId = ?").bind(teamId, creatorId).first();
					if (!team) return new Response("Forbidden", { status: 403, headers: corsHeaders });
				}

				await env.DB.prepare("DELETE FROM saved_teams WHERE id = ?").bind(teamId).run();
				await env.DB.prepare("DELETE FROM saved_team_players WHERE teamId = ?").bind(teamId).run();
				return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── CLEAR TEAM PLAYERS ────────────────────────────────────────────────
			if (pathname === "/clear-team-players" && request.method === "POST") {
				const body = await request.json();
				const teamId = body.id;
				const creatorId = body.creatorId;

				if (creatorId) {
					// Verify ownership before delete
					const team = await env.DB.prepare("SELECT id FROM saved_teams WHERE id = ? AND creatorId = ?").bind(teamId, creatorId).first();
					if (!team) return new Response("Forbidden", { status: 403, headers: corsHeaders });
				}

				await env.DB.prepare("DELETE FROM saved_team_players WHERE teamId = ?").bind(teamId).run();
				return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── GET ALL SAVED TEAMS ──────────────────────────────────────────────
			if (pathname === "/saved-teams" && request.method === "GET") {
				const creatorId = searchParams.get("creatorId");
				let teams;
				let players;
				if (creatorId) {
					teams = await env.DB.prepare("SELECT * FROM saved_teams WHERE creatorId = ? ORDER BY updatedAt DESC").bind(creatorId).all();
					players = await env.DB.prepare("SELECT * FROM saved_team_players WHERE teamId IN (SELECT id FROM saved_teams WHERE creatorId = ?) ORDER BY orderIndex ASC").bind(creatorId).all();
				} else {
					teams = await env.DB.prepare("SELECT * FROM saved_teams ORDER BY updatedAt DESC").all();
					players = await env.DB.prepare("SELECT * FROM saved_team_players ORDER BY orderIndex ASC").all();
				}
				return new Response(JSON.stringify({
					teams: teams.results,
					players: players.results
				}), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── GET PLAYER BATTING STATS ────────────────────────────────────────
			if (pathname.startsWith("/player-stats/batting/") && request.method === "GET") {
				const name = decodeURIComponent(pathname.split("/")[3]);
				const creatorId = searchParams.get("creatorId");
				
				let query = `
					SELECT 
						COALESCE(SUM(bi.runs), 0) as totalRuns,
						COALESCE(SUM(bi.ballsFaced), 0) as ballsFaced,
						COALESCE(SUM(bi.fours), 0) as fours,
						COALESCE(SUM(bi.sixes), 0) as sixes,
						COUNT(CASE WHEN bi.isOut = 1 THEN 1 END) as dismissals,
						COALESCE(MAX(bi.runs), 0) as highestScore,
						COUNT(bi.id) as innings,
						COUNT(DISTINCT p.matchId) as matchCount,
						COUNT(CASE WHEN bi.runs >= 30 AND bi.runs < 50 THEN 1 END) as thirties,
						COUNT(CASE WHEN bi.runs >= 50 AND bi.runs < 100 THEN 1 END) as fifties,
						COUNT(CASE WHEN bi.runs >= 100 THEN 1 END) as hundreds
					FROM players p
					JOIN matches m ON m.id = p.matchId
					LEFT JOIN batsman_innings bi ON bi.playerId = p.id
					WHERE LOWER(TRIM(p.name)) = LOWER(TRIM(?))
				`;
				
				let stats;
				if (creatorId) {
					query += " AND m.creatorId = ?";
					stats = await env.DB.prepare(query).bind(name, creatorId).first();
				} else {
					stats = await env.DB.prepare(query).bind(name).first();
				}
				
				if (!stats || (stats as any).matchCount === 0) {
					return new Response(JSON.stringify({}), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
				}
				return new Response(JSON.stringify(stats), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── GET PLAYER BOWLING STATS ────────────────────────────────────────
			if (pathname.startsWith("/player-stats/bowling/") && request.method === "GET") {
				const name = decodeURIComponent(pathname.split("/")[3]);
				const creatorId = searchParams.get("creatorId");

				let statsQuery = `
					SELECT 
						COALESCE(SUM(bi.runsConceded), 0) as runsConceded,
						COALESCE(SUM(bi.wickets), 0) as wickets,
						COALESCE(SUM(bi.ballsBowled), 0) as ballsBowled,
						COALESCE(SUM(bi.maidens), 0) as maidens,
						COUNT(bi.id) as innings,
						COUNT(DISTINCT p.matchId) as matchCount
					FROM players p
					JOIN matches m ON m.id = p.matchId
					LEFT JOIN bowler_innings bi ON bi.playerId = p.id
					WHERE LOWER(TRIM(p.name)) = LOWER(TRIM(?))
				`;

				let bestQuery = `
					SELECT bi.wickets, bi.runsConceded 
					FROM bowler_innings bi
					JOIN players p ON bi.playerId = p.id
					JOIN matches m ON m.id = p.matchId
					WHERE LOWER(TRIM(p.name)) = LOWER(TRIM(?))
				`;

				let stats;
				let best;
				if (creatorId) {
					statsQuery += " AND m.creatorId = ?";
					bestQuery += " AND m.creatorId = ? ORDER BY bi.wickets DESC, bi.runsConceded ASC LIMIT 1";
					stats = await env.DB.prepare(statsQuery).bind(name, creatorId).first();
					best = await env.DB.prepare(bestQuery).bind(name, creatorId).first();
				} else {
					bestQuery += " ORDER BY bi.wickets DESC, bi.runsConceded ASC LIMIT 1";
					stats = await env.DB.prepare(statsQuery).bind(name).first();
					best = await env.DB.prepare(bestQuery).bind(name).first();
				}

				if (!stats || (stats as any).matchCount === 0) {
					return new Response(JSON.stringify({}), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
				}

				const finalStats = { 
					...(stats as object), 
					bestWickets: (best as any)?.wickets ?? 0, 
					bestRuns: (best as any)?.runsConceded ?? 0 
				};

				return new Response(JSON.stringify(finalStats), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── GET TEAM H2H STATS ─────────────────────────────────────────────
			if (pathname.startsWith("/team-h2h") && request.method === "GET") {
				const parts = pathname.split("/");
				const team1 = decodeURIComponent(parts[2]);
				const team2 = decodeURIComponent(parts[3]);
				const creatorId = searchParams.get("creatorId");

				if (!team1 || !team2) {
					return new Response(JSON.stringify({ error: "Missing team names" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
				}

				let query = `
					SELECT * FROM matches
					WHERE (
						(team1Name LIKE ? AND team2Name LIKE ?)
						OR
						(team1Name LIKE ? AND team2Name LIKE ?)
					)
					AND status = 'completed'
				`;

				let matches;
				if (creatorId) {
					query += " AND creatorId = ? ORDER BY createdAt DESC";
					matches = await env.DB.prepare(query).bind(team1, team2, team2, team1, creatorId).all();
				} else {
					query += " ORDER BY createdAt DESC";
					matches = await env.DB.prepare(query).bind(team1, team2, team2, team1).all();
				}

				if (matches.results.length === 0) {
					return new Response(JSON.stringify({ totalMatches: 0 }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
				}

				let t1Wins = 0;
				let t2Wins = 0;
				let draws = 0;
				const recentResults: any[] = [];
				const t1Scores: number[] = [];
				const t2Scores: number[] = [];

				const t1Lower = team1.toLowerCase().trim();
				const t2Lower = team2.toLowerCase().trim();

				for (const match of (matches.results as any[])) {
					const winner = match.winnerTeam;
					if (winner) {
						const winnerLower = winner.toLowerCase().trim();
						if (winnerLower === t1Lower) t1Wins++;
						else if (winnerLower === t2Lower) t2Wins++;
						else draws++;
					} else {
						draws++;
					}

					recentResults.push({
						title: match.title,
						resultSummary: match.resultSummary,
						winnerTeam: winner,
						matchDate: match.matchDate
					});

					// Fetch innings for scores
					const innings = await env.DB.prepare("SELECT battingTeam, totalRuns FROM innings WHERE matchId = ?").bind(match.id).all();
					for (const inn of (innings.results as any[])) {
						const teamLower = (inn.battingTeam as string).toLowerCase().trim();
						if (teamLower === t1Lower) t1Scores.add ? t1Scores.push(inn.totalRuns) : t1Scores.push(inn.totalRuns); // Array.push hack for types
						else if (teamLower === t2Lower) t2Scores.push(inn.totalRuns);
					}
				}

				return new Response(JSON.stringify({
					totalMatches: matches.results.length,
					team1Wins: t1Wins,
					team2Wins: t2Wins,
					draws: draws,
					team1HighestScore: t1Scores.length > 0 ? Math.max(...t1Scores) : 0,
					team2HighestScore: t2Scores.length > 0 ? Math.max(...t2Scores) : 0,
					team1LowestScore: t1Scores.length > 0 ? Math.min(...t1Scores) : 0,
					team2LowestScore: t2Scores.length > 0 ? Math.min(...t2Scores) : 0,
					team1AvgScore: t1Scores.length > 0 ? t1Scores.reduce((a, b) => a + b, 0) / t1Scores.length : 0,
					team2AvgScore: t2Scores.length > 0 ? t2Scores.reduce((a, b) => a + b, 0) / t2Scores.length : 0,
					recentMatches: recentResults
				}), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── GET LEADERBOARDS ───────────────────────────────────────────────
			if (pathname === "/leaderboards" && request.method === "GET") {
				const creatorId = searchParams.get("creatorId");
				let batters;
				let bowlers;
				let allRounders;

				if (creatorId) {
					batters = await env.DB.prepare(`
						SELECT 
							p.name,
							p.teamName,
							SUM(bi.runs) as totalRuns,
							COUNT(bi.id) as innings,
							SUM(bi.ballsFaced) as ballsFaced,
							ROUND(CAST(SUM(bi.runs) AS REAL) / NULLIF(COUNT(CASE WHEN bi.isOut = 1 THEN 1 END), 0), 2) as average
						FROM players p
						JOIN matches m ON m.id = p.matchId
						JOIN batsman_innings bi ON bi.playerId = p.id
						WHERE LOWER(p.name) NOT LIKE 'player %' AND m.creatorId = ?
						GROUP BY LOWER(TRIM(p.name))
						ORDER BY totalRuns DESC, average DESC
						LIMIT 5
					`).bind(creatorId).all();

					bowlers = await env.DB.prepare(`
						SELECT 
							p.name,
							p.teamName,
							SUM(bi.wickets) as totalWickets,
							COUNT(bi.id) as innings,
							SUM(bi.runsConceded) as runsConceded,
							SUM(bi.ballsBowled) as ballsBowled,
							ROUND(CAST(SUM(bi.runsConceded) AS REAL) / NULLIF(SUM(bi.ballsBowled) / 6.0, 0), 2) as economy
						FROM players p
						JOIN matches m ON m.id = p.matchId
						JOIN bowler_innings bi ON bi.playerId = p.id
						WHERE LOWER(p.name) NOT LIKE 'player %' AND m.creatorId = ?
						GROUP BY LOWER(TRIM(p.name))
						ORDER BY totalWickets DESC, economy ASC
						LIMIT 5
					`).bind(creatorId).all();

					allRounders = await env.DB.prepare(`
						SELECT 
							p.name,
							p.teamName,
							COALESCE(bat.runs, 0) as runs,
							COALESCE(bowl.wickets, 0) as wickets,
							(COALESCE(bat.runs, 0) + (COALESCE(bowl.wickets, 0) * 20)) as points
						FROM players p
						JOIN matches m ON m.id = p.matchId
						LEFT JOIN (
							SELECT p2.name, SUM(bi.runs) as runs 
							FROM players p2 
							JOIN matches m2 ON m2.id = p2.matchId
							JOIN batsman_innings bi ON bi.playerId = p2.id 
							WHERE m2.creatorId = ?
							GROUP BY LOWER(TRIM(p2.name))
						) bat ON LOWER(TRIM(bat.name)) = LOWER(TRIM(p.name))
						LEFT JOIN (
							SELECT p3.name, SUM(bi2.wickets) as wickets 
							FROM players p3 
							JOIN matches m3 ON m3.id = p3.matchId
							JOIN bowler_innings bi2 ON bi2.playerId = p3.id 
							WHERE m3.creatorId = ?
							GROUP BY LOWER(TRIM(p3.name))
						) bowl ON LOWER(TRIM(bowl.name)) = LOWER(TRIM(p.name))
						WHERE LOWER(p.name) NOT LIKE 'player %' AND m.creatorId = ?
						GROUP BY LOWER(TRIM(p.name))
						HAVING runs > 0 AND wickets > 0
						ORDER BY points DESC
						LIMIT 5
					`).bind(creatorId, creatorId, creatorId).all();
				} else {
					batters = await env.DB.prepare(`
						SELECT 
							p.name,
							p.teamName,
							SUM(bi.runs) as totalRuns,
							COUNT(bi.id) as innings,
							SUM(bi.ballsFaced) as ballsFaced,
							ROUND(CAST(SUM(bi.runs) AS REAL) / NULLIF(COUNT(CASE WHEN bi.isOut = 1 THEN 1 END), 0), 2) as average
						FROM players p
						JOIN batsman_innings bi ON bi.playerId = p.id
						WHERE LOWER(p.name) NOT LIKE 'player %'
						GROUP BY LOWER(TRIM(p.name))
						ORDER BY totalRuns DESC, average DESC
						LIMIT 5
					`).all();

					bowlers = await env.DB.prepare(`
						SELECT 
							p.name,
							p.teamName,
							SUM(bi.wickets) as totalWickets,
							COUNT(bi.id) as innings,
							SUM(bi.runsConceded) as runsConceded,
							SUM(bi.ballsBowled) as ballsBowled,
							ROUND(CAST(SUM(bi.runsConceded) AS REAL) / NULLIF(SUM(bi.ballsBowled) / 6.0, 0), 2) as economy
						FROM players p
						JOIN bowler_innings bi ON bi.playerId = p.id
						WHERE LOWER(p.name) NOT LIKE 'player %'
						GROUP BY LOWER(TRIM(p.name))
						ORDER BY totalWickets DESC, economy ASC
						LIMIT 5
					`).all();

					allRounders = await env.DB.prepare(`
						SELECT 
							p.name,
							p.teamName,
							COALESCE(bat.runs, 0) as runs,
							COALESCE(bowl.wickets, 0) as wickets,
							(COALESCE(bat.runs, 0) + (COALESCE(bowl.wickets, 0) * 20)) as points
						FROM players p
						LEFT JOIN (
							SELECT p2.name, SUM(bi.runs) as runs 
							FROM players p2 JOIN batsman_innings bi ON bi.playerId = p2.id 
							GROUP BY LOWER(TRIM(p2.name))
						) bat ON LOWER(TRIM(bat.name)) = LOWER(TRIM(p.name))
						LEFT JOIN (
							SELECT p3.name, SUM(bi2.wickets) as wickets 
							FROM players p3 JOIN bowler_innings bi2 ON bi2.playerId = p3.id 
							GROUP BY LOWER(TRIM(p3.name))
						) bowl ON LOWER(TRIM(bowl.name)) = LOWER(TRIM(p.name))
						WHERE LOWER(p.name) NOT LIKE 'player %'
						GROUP BY LOWER(TRIM(p.name))
						HAVING runs > 0 AND wickets > 0
						ORDER BY points DESC
						LIMIT 5
					`).all();
				}

				return new Response(JSON.stringify({
					batters: batters.results,
					bowlers: bowlers.results,
					allRounders: allRounders.results
				}), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}
			
			// ── PLAYER BATTING RANKINGS ────────────────────────────────────────
			if (pathname === "/player-rankings/batting" && request.method === "GET") {
				const creatorId = searchParams.get("creatorId");
				let creatorFilter = "";
				let bindings: any[] = [];
				if (creatorId) {
					creatorFilter = " AND m.creatorId = ?";
					bindings.push(creatorId);
				}

				const query = `
					SELECT 
						LOWER(TRIM(p.name)) as nameKey,
						p.name,
						p.teamName,
						SUBSTR(MIN(m.matchDate),1,4) || '-' || SUBSTR(MAX(m.matchDate),1,4) as span,
						COUNT(DISTINCT p.id) as mat,
						COUNT(bi.id) as inns,
						COUNT(CASE WHEN bi.isOut = 0 THEN 1 END) as notOuts,
						COALESCE(SUM(bi.runs), 0) as runs,
						COALESCE(MAX(bi.runs), 0) as hs,
						COALESCE(SUM(bi.ballsFaced), 0) as bf,
						COUNT(CASE WHEN bi.runs >= 100 THEN 1 END) as hundreds,
						COUNT(CASE WHEN bi.runs >= 50 AND bi.runs < 100 THEN 1 END) as fifties,
						COUNT(CASE WHEN bi.runs = 0 AND bi.isOut = 1 THEN 1 END) as ducks,
						COALESCE(SUM(bi.fours), 0) as fours,
						COALESCE(SUM(bi.sixes), 0) as sixes,
						COUNT(CASE WHEN bi.isOut = 1 THEN 1 END) as dismissals
					FROM players p
					JOIN matches m ON m.id = p.matchId
					JOIN batsman_innings bi ON bi.playerId = p.id
					WHERE LOWER(p.name) NOT LIKE 'player %'${creatorFilter}
					GROUP BY LOWER(TRIM(p.name))
					HAVING runs > 0
					ORDER BY runs DESC
					LIMIT 50
				`;

				const results = await env.DB.prepare(query).bind(...bindings).all();

				// Post-process to compute average, SR, and HS not-out indicator
				const processed = [];
				for (const row of results.results as any[]) {
					const dismissals = row.dismissals as number;
					const runs = row.runs as number;
					const bf = row.bf as number;
					const ave = dismissals > 0 ? Math.round((runs / dismissals) * 100) / 100 : null;
					const sr = bf > 0 ? Math.round((runs * 100.0 / bf) * 100) / 100 : 0;

					// Check if highest score was not out
					let hsDisplay = row.hs.toString();
					try {
						let hsCheckQuery = `
							SELECT bi.isOut FROM batsman_innings bi
							JOIN players p ON bi.playerId = p.id
							JOIN matches m ON m.id = p.matchId
							WHERE LOWER(TRIM(p.name)) = ? AND bi.runs = ?
						`;
						let hsBindings: any[] = [row.nameKey, row.hs];
						if (creatorId) {
							hsCheckQuery += " AND m.creatorId = ?";
							hsBindings.push(creatorId);
						}
						hsCheckQuery += " ORDER BY bi.runs DESC LIMIT 1";
						const hsRow = await env.DB.prepare(hsCheckQuery).bind(...hsBindings).first();
						if (hsRow && (hsRow as any).isOut === 0) {
							hsDisplay = row.hs + '*';
						}
					} catch (e) { /* ignore HS check error */ }

					processed.push({
						name: row.name,
						teamName: row.teamName,
						span: row.span,
						mat: row.mat,
						inns: row.inns,
						notOuts: row.notOuts,
						runs: runs,
						hs: hsDisplay,
						ave: ave,
						bf: bf,
						sr: sr,
						hundreds: row.hundreds,
						fifties: row.fifties,
						ducks: row.ducks,
						fours: row.fours,
						sixes: row.sixes,
					});
				}

				return new Response(JSON.stringify(processed), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── PLAYER BOWLING RANKINGS ────────────────────────────────────────
			if (pathname === "/player-rankings/bowling" && request.method === "GET") {
				const creatorId = searchParams.get("creatorId");
				let bindings: any[] = [];
				if (creatorId) {
					bindings.push(creatorId); // for subquery
					bindings.push(creatorId); // for main query
				}

				const query = `
					SELECT 
						p.name,
						p.teamName,
						SUBSTR(MIN(m.matchDate),1,4) || '-' || SUBSTR(MAX(m.matchDate),1,4) as span,
						COUNT(DISTINCT p.id) as mat,
						COUNT(bi.id) as inns,
						COALESCE(SUM(bi.ballsBowled), 0) as balls,
						COALESCE(SUM(bi.maidens), 0) as maidens,
						COALESCE(SUM(bi.runsConceded), 0) as runs,
						COALESCE(SUM(bi.wickets), 0) as wkts,
						COUNT(CASE WHEN bi.wickets >= 4 THEN 1 END) as fourWickets,
						COUNT(CASE WHEN bi.wickets >= 5 THEN 1 END) as fiveWickets,
						COALESCE(SUM(bi.dotBalls), 0) as dots,
						(
							SELECT bi2.wickets || '/' || bi2.runsConceded
							FROM bowler_innings bi2
							JOIN players p2 ON p2.id = bi2.playerId
							JOIN matches m2 ON m2.id = p2.matchId
							WHERE LOWER(TRIM(p2.name)) = LOWER(TRIM(p.name))
							${creatorId ? "AND m2.creatorId = ?" : ""}
							ORDER BY bi2.wickets DESC, bi2.runsConceded ASC
							LIMIT 1
						) as bbi
					FROM players p
					JOIN matches m ON m.id = p.matchId
					JOIN bowler_innings bi ON bi.playerId = p.id
					WHERE LOWER(p.name) NOT LIKE 'player %' ${creatorId ? "AND m.creatorId = ?" : ""}
					GROUP BY LOWER(TRIM(p.name))
					HAVING wkts > 0
					ORDER BY wkts DESC, runs ASC
					LIMIT 50
				`;

				const results = await env.DB.prepare(query).bind(...bindings).all();

				const processed = (results.results as any[]).map((row: any) => {
					const balls = row.balls as number;
					const runs = row.runs as number;
					const wkts = row.wkts as number;
					const overs = Math.floor(balls / 6) + (balls % 6) / 10;
					const ave = wkts > 0 ? Math.round((runs / wkts) * 100) / 100 : null;
					const econ = balls > 0 ? Math.round((runs / (balls / 6.0)) * 100) / 100 : 0;
					const sr = wkts > 0 ? Math.round((balls / wkts) * 100) / 100 : null;

					return {
						name: row.name,
						teamName: row.teamName,
						span: row.span,
						mat: row.mat,
						inns: row.inns,
						balls: balls,
						overs: overs,
						maidens: row.maidens,
						runs: runs,
						wkts: wkts,
						bbi: row.bbi ?? '-',
						ave: ave,
						econ: econ,
						sr: sr,
						fourWickets: row.fourWickets,
						fiveWickets: row.fiveWickets,
						dots: row.dots,
					};
				});

				return new Response(JSON.stringify(processed), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}
			
			// ── CONTACT FEEDBACK ──────────────────────────────────────────────────
			if (pathname === "/contact" && request.method === "POST") {
				const body = await request.json();
				const { email, message } = body;
				await env.DB.prepare("INSERT INTO feedback (email, message, createdAt) VALUES (?, ?, ?)")
					.bind(email, message, new Date().toISOString()).run();
				return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── GET FEEDBACKS (Admin) ────────────────────────────────────────────────
			if (pathname === "/feedbacks" && request.method === "GET") {
				const feedbacks = await env.DB.prepare("SELECT * FROM feedback ORDER BY createdAt DESC").all();
				return new Response(JSON.stringify(feedbacks.results), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── GET NOTIFICATIONS ──────────────────────────────────────────────────
			if (pathname === "/notifications" && request.method === "GET") {
				const notifications = [
					{
						id: 'apk-220',
						title: 'New APK Available!',
						message: 'Version 2.2.0 is now available with Head-to-Head stats and improved data matching. Download now!',
						type: 'update',
						createdAt: new Date().toISOString(),
						actionUrl: 'https://cric-local-api.eduhub.workers.dev/download/apk'
					},
					{
						id: 'feat-h2h',
						title: 'Head-to-Head Stats!',
						message: 'Compare two players or teams across all local and global matches.',
						type: 'feature',
						createdAt: new Date().toISOString(),
					},
					{
						id: 'feat-search',
						title: 'Global Search Added',
						message: 'You can now search for players, teams, and matches globally across the app.',
						type: 'feature',
						createdAt: new Date(Date.now() - 86400000).toISOString(),
					}
				];
				return new Response(JSON.stringify(notifications), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── DOWNLOAD APK ──────────────────────────────────────────────────────
			if (pathname === "/download/apk" && request.method === "GET") {
				return Response.redirect("https://criclocal.eduhubacademy.org/CricHero.apk", 302);
			}

			return new Response("Not Found", { status: 404, headers: corsHeaders });
		} catch (error: any) {
			return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: corsHeaders });
		}
	},
};
