export interface Env {
	DB: D1Database;
}

export default {
	async fetch(request: Request, env: Env): Promise<Response> {
		const { pathname } = new URL(request.url);

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
			// ── SYNC MATCH ────────────────────────────────────────────────────────
			if (pathname === "/sync-match" && request.method === "POST") {
				const match = await request.json();
				await env.DB.prepare(`
					INSERT INTO matches (id, title, format, totalOvers, playersPerSide, team1Name, team2Name, venue, matchDate, status, resultSummary, createdAt, updatedAt)
					VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
					ON CONFLICT(id) DO UPDATE SET
						status = excluded.status,
						resultSummary = excluded.resultSummary,
						updatedAt = excluded.updatedAt
				`).bind(
					match.id, match.title, match.format, match.totalOvers, match.playersPerSide,
					match.team1Name, match.team2Name, match.venue, match.matchDate,
					match.status, match.resultSummary, match.createdAt, match.updatedAt
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
				const matches = await env.DB.prepare("SELECT * FROM matches ORDER BY createdAt DESC LIMIT 50").all();
				return new Response(JSON.stringify(matches.results), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── GET LIVE MATCH ────────────────────────────────────────────────────
			if (pathname.startsWith("/match/") && request.method === "GET") {
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
					INSERT INTO saved_teams (id, name, createdAt, updatedAt)
					VALUES (?, ?, ?, ?)
					ON CONFLICT(id) DO UPDATE SET
						name = excluded.name,
						updatedAt = excluded.updatedAt
				`).bind(team.id, team.name, team.createdAt, team.updatedAt).run();
				return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── SYNC SAVED TEAM PLAYER ───────────────────────────────────────────
			if (pathname === "/sync-saved-team-player" && request.method === "POST") {
				const p = await request.json();
				await env.DB.prepare(`
					INSERT INTO saved_team_players (id, teamId, name, orderIndex)
					VALUES (?, ?, ?, ?)
					ON CONFLICT(id) DO UPDATE SET
						name = excluded.name,
						orderIndex = excluded.orderIndex
				`).bind(p.id, p.teamId, p.name, p.orderIndex).run();
				return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── DELETE SAVED TEAM ────────────────────────────────────────────────
			if (pathname === "/delete-saved-team" && request.method === "POST") {
				const body = await request.json();
				const teamId = body.id;
				await env.DB.prepare("DELETE FROM saved_teams WHERE id = ?").bind(teamId).run();
				await env.DB.prepare("DELETE FROM saved_team_players WHERE teamId = ?").bind(teamId).run();
				return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── CLEAR TEAM PLAYERS ────────────────────────────────────────────────
			if (pathname === "/clear-team-players" && request.method === "POST") {
				const body = await request.json();
				const teamId = body.id;
				await env.DB.prepare("DELETE FROM saved_team_players WHERE teamId = ?").bind(teamId).run();
				return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── GET ALL SAVED TEAMS ──────────────────────────────────────────────
			if (pathname === "/saved-teams" && request.method === "GET") {
				const teams = await env.DB.prepare("SELECT * FROM saved_teams ORDER BY updatedAt DESC").all();
				const players = await env.DB.prepare("SELECT * FROM saved_team_players ORDER BY orderIndex ASC").all();
				return new Response(JSON.stringify({
					teams: teams.results,
					players: players.results
				}), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── GET PLAYER BATTING STATS ────────────────────────────────────────
			if (pathname.startsWith("/player-stats/batting/") && request.method === "GET") {
				const name = decodeURIComponent(pathname.split("/")[3]);
				const stats = await env.DB.prepare(`
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
					LEFT JOIN batsman_innings bi ON bi.playerId = p.id
					WHERE LOWER(TRIM(p.name)) = LOWER(TRIM(?))
				`).bind(name).first();
				
				if (!stats || (stats as any).matchCount === 0) {
					return new Response(JSON.stringify({}), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
				}
				return new Response(JSON.stringify(stats), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── GET PLAYER BOWLING STATS ────────────────────────────────────────
			if (pathname.startsWith("/player-stats/bowling/") && request.method === "GET") {
				const name = decodeURIComponent(pathname.split("/")[3]);
				const stats = await env.DB.prepare(`
					SELECT 
						COALESCE(SUM(bi.runsConceded), 0) as runsConceded,
						COALESCE(SUM(bi.wickets), 0) as wickets,
						COALESCE(SUM(bi.ballsBowled), 0) as ballsBowled,
						COALESCE(SUM(bi.maidens), 0) as maidens,
						COUNT(bi.id) as innings,
						COUNT(DISTINCT p.matchId) as matchCount
					FROM players p
					LEFT JOIN bowler_innings bi ON bi.playerId = p.id
					WHERE LOWER(TRIM(p.name)) = LOWER(TRIM(?))
				`).bind(name).first();

				if (!stats || (stats as any).matchCount === 0) {
					return new Response(JSON.stringify({}), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
				}

				const best = await env.DB.prepare(`
					SELECT bi.wickets, bi.runsConceded 
					FROM bowler_innings bi
					JOIN players p ON bi.playerId = p.id
					WHERE LOWER(TRIM(p.name)) = LOWER(TRIM(?))
					ORDER BY bi.wickets DESC, bi.runsConceded ASC
					LIMIT 1
				`).bind(name).first();

				const finalStats = { 
					...(stats as object), 
					bestWickets: (best as any)?.wickets ?? 0, 
					bestRuns: (best as any)?.runsConceded ?? 0 
				};

				return new Response(JSON.stringify(finalStats), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			// ── GET LEADERBOARDS ───────────────────────────────────────────────
			if (pathname === "/leaderboards" && request.method === "GET") {
				const batters = await env.DB.prepare(`
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

				const bowlers = await env.DB.prepare(`
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

				const allRounders = await env.DB.prepare(`
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

				return new Response(JSON.stringify({
					batters: batters.results,
					bowlers: bowlers.results,
					allRounders: allRounders.results
				}), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
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
						id: 'apk-210',
						title: 'New APK Available!',
						message: 'Version 2.1.0 is now available with improved live scoring and bug fixes. Download now!',
						type: 'update',
						createdAt: new Date().toISOString(),
						actionUrl: 'https://cric-local-api.eduhub.workers.dev/download/apk'
					},
					{
						id: 'feat-search',
						title: 'Global Search Added',
						message: 'You can now search for players, teams, and matches globally across the app.',
						type: 'feature',
						createdAt: new Date(Date.now() - 86400000).toISOString(),
					},
					{
						id: 'feat-w-plus',
						title: 'W+1 Run Out Scoring',
						message: 'Accurately record runs completed during run-out dismissals in the scoring ribbon.',
						type: 'feature',
						createdAt: new Date(Date.now() - 172800000).toISOString(),
					}
				];
				return new Response(JSON.stringify(notifications), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
			}

			return new Response("Not Found", { status: 404, headers: corsHeaders });
		} catch (error: any) {
			return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: corsHeaders });
		}
	},
};
