const { getWAFConfig, updateWAFConfig } = require("../middleware/waf");
const wafModel = require("../models/wafModel");

const wafController = {
  getStatus: async (req, res) => {
    try {
      const config = getWAFConfig();

      // POBIERZ STATYSTYKI Z BAZY (nie z pamięci)
      const dbStats = await wafModel.getDashboardStats();

      if (!dbStats.success) {
        return res.status(500).json({
          success: false,
          message: "Błąd podczas pobierania statusu WAF",
          error: dbStats.error,
        });
      }

      return res.status(200).json({
        success: true,
        status: {
          enabled: true,
          provider: "LocalWAF",
          version: "1.0.0",
          uptime: "Online",
          rules: {
            rateLimitEnabled: config.rateLimiting.enabled,
            rateLimitMax: config.rateLimiting.maxRequests,
            sqlInjectionEnabled: config.sqlInjection.enabled,
            sqlInjectionRules: config.sqlInjection.patterns.length,
            xssEnabled: config.xss.enabled,
            xssRules: config.xss.patterns.length,
          },
          stats: {
            totalRequests: parseInt(dbStats.stats.total_events) || 0,
            blockedRequests: parseInt(dbStats.stats.total_events) || 0,
            blockRate: dbStats.stats.total_events > 0 ? "100%" : "0%",
            threats: {
              rateLimit: parseInt(dbStats.stats.total_rate_limit) || 0,
              sqlInjection: parseInt(dbStats.stats.total_sql_injection) || 0,
              xss: parseInt(dbStats.stats.total_xss) || 0,
            },
          },
        },
      });
    } catch (error) {
      console.error("Błąd statusu WAF:", error);
      return res.status(500).json({
        success: false,
        message: "Błąd podczas sprawdzania statusu WAF",
        error: error.message,
      });
    }
  },

  getDashboard: async (req, res) => {
    try {
      const config = getWAFConfig();

      // WSZYSTKIE DANE Z BAZY
      const dbStats = await wafModel.getDashboardStats();
      const allEvents = await wafModel.getSecurityEvents(null, null, 20, 0);

      if (!dbStats.success) {
        return res.status(500).json({
          success: false,
          message: "Błąd podczas pobierania statystyk z bazy danych",
          error: dbStats.error,
        });
      }

      if (!allEvents.success) {
        return res.status(500).json({
          success: false,
          message: "Błąd podczas pobierania eventów z bazy danych",
          error: allEvents.error,
        });
      }

      return res.status(200).json({
        success: true,
        data: {
          provider: "LocalWAF",

          // STATYSTYKI TYLKO Z BAZY
          totalRequests: parseInt(dbStats.stats.total_events) || 0,
          blockedRequests: parseInt(dbStats.stats.total_events) || 0,
          blockRate: dbStats.stats.total_events > 0 ? "100%" : "0%",

          // ZAGROŻENIA Z BAZY (wszystkie czasy)
          threats: {
            rateLimit: parseInt(dbStats.stats.total_rate_limit) || 0,
            sqlInjection: parseInt(dbStats.stats.total_sql_injection) || 0,
            xss: parseInt(dbStats.stats.total_xss) || 0,
            total: parseInt(dbStats.stats.total_events) || 0,
          },

          // STATYSTYKI OSTATNIE 24h Z BAZY
          last24h: {
            totalEvents: parseInt(dbStats.stats.last_24h_events) || 0,
            rateLimitBlocks: parseInt(dbStats.stats.last_24h_rate_limit) || 0,
            sqlInjectionBlocks:
              parseInt(dbStats.stats.last_24h_sql_injection) || 0,
            xssBlocks: parseInt(dbStats.stats.last_24h_xss) || 0,
          },

          topAttackers: dbStats.topAttackers.map((attacker) => ({
            ip: attacker.ip_address,
            attacks: parseInt(attacker.attack_count),
          })),

          topTargetedEndpoints: dbStats.topTargetedEndpoints.map(
            (endpoint) => ({
              endpoint: endpoint.endpoint,
              attacks: parseInt(endpoint.attack_count),
            })
          ),

          // EVENTY Z BAZY
          recentEvents: allEvents.events.map((event) => ({
            id: event.event_id,
            timestamp: event.created_at,
            type: event.event_type,
            ip: event.ip_address,
            endpoint: event.endpoint,
            description: event.description,
            risk: event.risk_level,
            action: event.action_taken,
          })),

          config: {
            rateLimitEnabled: config.rateLimiting.enabled,
            rateLimitMax: config.rateLimiting.maxRequests,
            sqlInjectionEnabled: config.sqlInjection.enabled,
            xssEnabled: config.xss.enabled,
          },
        },
      });
    } catch (error) {
      console.error("Błąd dashboard WAF:", error);
      return res.status(500).json({
        success: false,
        message: "Błąd podczas pobierania dashboard WAF",
        error: error.message,
      });
    }
  },

  getSecurityEvents: async (req, res) => {
    try {
      const { since, until, limit = 50, page = 1 } = req.query;
      const offset = (parseInt(page) - 1) * parseInt(limit);

      const result = await wafModel.getSecurityEvents(
        since,
        until,
        parseInt(limit),
        offset
      );

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Błąd podczas pobierania eventów bezpieczeństwa",
          error: result.error,
        });
      }

      return res.status(200).json({
        success: true,
        events: result.events.map((event) => ({
          id: event.event_id,
          timestamp: event.created_at,
          type: event.event_type,
          ip: event.ip_address,
          endpoint: event.endpoint,
          userAgent: event.user_agent,
          description: event.description,
          risk: event.risk_level,
          action: event.action_taken,
        })),
        pagination: {
          total: result.total,
          page: parseInt(page),
          limit: parseInt(limit),
          totalPages: Math.ceil(result.total / parseInt(limit)),
          hasMore: result.pagination.hasMore,
        },
      });
    } catch (error) {
      console.error("Błąd pobierania security events:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas pobierania eventów bezpieczeństwa",
        error: error.message,
      });
    }
  },

  updateConfig: async (req, res) => {
    try {
      const { config } = req.body;

      if (!config || typeof config !== "object") {
        return res.status(400).json({
          success: false,
          message: "Nieprawidłowa konfiguracja WAF",
        });
      }

      if (config.rateLimiting?.maxRequests) {
        if (
          config.rateLimiting.maxRequests < 1 ||
          config.rateLimiting.maxRequests > 10000
        ) {
          return res.status(400).json({
            success: false,
            message: "Maksymalna liczba żądań musi być między 1 a 10000",
          });
        }
      }

      updateWAFConfig(config);

      return res.status(200).json({
        success: true,
        message: "Konfiguracja WAF została zaktualizowana",
        config: getWAFConfig(),
      });
    } catch (error) {
      console.error("Błąd aktualizacji konfiguracji WAF:", error);
      return res.status(500).json({
        success: false,
        message: "Błąd podczas aktualizacji konfiguracji",
        error: error.message,
      });
    }
  },
};

module.exports = wafController;
