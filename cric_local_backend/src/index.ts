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
				await env.DB.prepare(`
					INSERT INTO players (id, name, teamName, matchId, battingOrder, isKeeper, isCaptain)
					VALUES (?, ?, ?, ?, ?, ?, ?)
					ON CONFLICT(id) DO UPDATE SET
						name = excluded.name, battingOrder = excluded.battingOrder,
						isKeeper = excluded.isKeeper, isCaptain = excluded.isCaptain
				`).bind(p.id, p.name, p.teamName, p.matchId, p.battingOrder ?? null, p.isKeeper ? 1 : 0, p.isCaptain ? 1 : 0).run();
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
					const lastInningsId = innings.results[innings.results.length - 1].id;
					recentDeliveries = await env.DB.prepare("SELECT * FROM deliveries WHERE inningsId = ? ORDER BY timestamp DESC LIMIT 20").bind(lastInningsId).all();
					
					// Get all batsman and bowler stats for the match
					const inningsIds = innings.results.map((inn: any) => `'${inn.id}'`).join(',');
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

			return new Response("Not Found", { status: 404, headers: corsHeaders });
		} catch (error: any) {
			return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: corsHeaders });
		}
	},
};
