const db = require("./db");

const wafModel = {
  getSecurityEvents: async (
    since = null,
    until = null,
    limit = 50,
    offset = 0
  ) => {
    try {
      let query = `
        SELECT 
          event_id,
          event_type,
          ip_address,
          endpoint,
          user_agent,
          description,
          risk_level,
          action_taken,
          created_at
        FROM waf_security_events
      `;

      let countQuery = `SELECT COUNT(*) as total FROM waf_security_events`;
      const params = [];
      const countParams = [];
      let whereConditions = [];

      // FILTRY DATY
      if (since) {
        whereConditions.push(`created_at >= $${params.length + 1}`);
        params.push(new Date(since));
        countParams.push(new Date(since));
      }

      if (until) {
        whereConditions.push(`created_at <= $${params.length + 1}`);
        params.push(new Date(until));
        countParams.push(new Date(until));
      }

      // DODAJ WHERE CLAUSE
      if (whereConditions.length > 0) {
        const whereClause = ` WHERE ${whereConditions.join(" AND ")}`;
        query += whereClause;
        countQuery += whereClause;
      }

      // SORTOWANIE I PAGINACJA
      query += ` ORDER BY created_at DESC LIMIT $${params.length + 1} OFFSET $${
        params.length + 2
      }`;
      params.push(limit, offset);

      // WYKONAJ ZAPYTANIA
      const [events, totalResult] = await Promise.all([
        db.query(query, params),
        db.query(countQuery, countParams),
      ]);

      return {
        success: true,
        events: events.rows,
        total: parseInt(totalResult.rows[0].total),
        pagination: {
          limit,
          offset,
          hasMore: events.rows.length === limit,
        },
      };
    } catch (error) {
      console.error("Błąd pobierania security events:", error);
      return {
        success: false,
        error: error.message,
        events: [],
        total: 0,
      };
    }
  },

  getDashboardStats: async () => {
    try {
      const last24h = new Date(Date.now() - 24 * 60 * 60 * 1000);

      // ROZSZERZONE STATYSTYKI - wszystkie czasy + ostatnie 24h
      const statsQuery = `
        SELECT 
          -- Wszystkie czasy (dla wykresów zagrożeń)
          COUNT(*) as total_events,
          COUNT(CASE WHEN event_type = 'rate_limit' THEN 1 END) as total_rate_limit,
          COUNT(CASE WHEN event_type = 'sql_injection' THEN 1 END) as total_sql_injection,
          COUNT(CASE WHEN event_type = 'xss' THEN 1 END) as total_xss,
          
          -- Ostatnie 24h (dla aktualnych statystyk)
          COUNT(CASE WHEN created_at >= $1 THEN 1 END) as last_24h_events,
          COUNT(CASE WHEN event_type = 'rate_limit' AND created_at >= $1 THEN 1 END) as last_24h_rate_limit,
          COUNT(CASE WHEN event_type = 'sql_injection' AND created_at >= $1 THEN 1 END) as last_24h_sql_injection,
          COUNT(CASE WHEN event_type = 'xss' AND created_at >= $1 THEN 1 END) as last_24h_xss
        FROM waf_security_events
      `;

      // TOP ATAKUJĄCE IP (ostatnie 7 dni)
      const last7days = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
      const topIPsQuery = `
        SELECT 
          ip_address, 
          COUNT(*) as attack_count
        FROM waf_security_events 
        WHERE created_at >= $1
        GROUP BY ip_address 
        ORDER BY attack_count DESC 
        LIMIT 5
      `;

      // TOP ATAKOWANE ENDPOINTY (ostatnie 7 dni)
      const topEndpointsQuery = `
        SELECT 
          endpoint, 
          COUNT(*) as attack_count
        FROM waf_security_events 
        WHERE endpoint IS NOT NULL AND created_at >= $1
        GROUP BY endpoint 
        ORDER BY attack_count DESC 
        LIMIT 5
      `;

      const [statsResult, topIPsResult, topEndpointsResult] = await Promise.all(
        [
          db.query(statsQuery, [last24h]),
          db.query(topIPsQuery, [last7days]),
          db.query(topEndpointsQuery, [last7days]),
        ]
      );

      return {
        success: true,
        stats: statsResult.rows[0],
        topAttackers: topIPsResult.rows,
        topTargetedEndpoints: topEndpointsResult.rows,
      };
    } catch (error) {
      console.error("Błąd pobierania statystyk dashboard:", error);
      return {
        success: false,
        error: error.message,
      };
    }
  },
};

module.exports = wafModel;
