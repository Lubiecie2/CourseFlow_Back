const { redisClient } = require("../config/redis");
const db = require("../models/db");

const wafConfig = {
  rateLimiting: {
    enabled: true,
    windowMs: 60000,
    maxRequests: 100,
  },
  sqlInjection: {
    enabled: true,
    patterns: [
      /(\bUNION\b.*\bSELECT\b)/i,
      /(\bSELECT\b.*\bFROM\b)/i,
      /(\bINSERT\b.*\bINTO\b)/i,
      /(\bUPDATE\b.*\bSET\b)/i,
      /(\bDELETE\b.*\bFROM\b)/i,
      /(\bDROP\b.*\bTABLE\b)/i,
      /(\';|\"\;|`\;)/i,
      /(OR\s+1=1|AND\s+1=1)/i,
      /'[^']*'[\s]*\|\|[\s]*'[^']*'/i,
      /EXEC[\s]*\(/i,
      /xp_cmdshell/i,
    ],
  },
  xss: {
    enabled: true,
    patterns: [
      /<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi,
      /<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>/gi,
      /javascript:/gi,
      /on\w+\s*=/gi,
      /<img[^>]+src[\\s]*=[\\s]*[\"\\']?[\\s]*javascript:/gi,
      /<svg[^>]*on\w+[^>]*>/gi,
      /eval\s*\(/gi,
      /expression\s*\(/gi,
    ],
  },
};

const getClientIP = (req) => {
  return (
    req.headers["x-forwarded-for"]?.split(",")[0] ||
    req.headers["x-real-ip"] ||
    req.connection.remoteAddress ||
    req.socket.remoteAddress ||
    req.ip ||
    "127.0.0.1"
  );
};

const logSecurityEvent = async (
  type,
  ip,
  endpoint,
  description,
  userAgent = "",
  risk = "medium"
) => {
  const event = {
    event_id: `evt_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
    event_type: type,
    ip_address: ip,
    endpoint,
    user_agent: userAgent,
    description,
    risk_level: risk,
    action_taken: "blocked",
  };

  console.log(`🛡️ WAF BLOCKED: ${type} from ${ip} - ${description}`);

  try {
    await db.query(
      `INSERT INTO waf_security_events (event_id, event_type, ip_address, endpoint, user_agent, description, risk_level, action_taken) 
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        event.event_id,
        event.event_type,
        event.ip_address,
        event.endpoint,
        event.user_agent,
        event.description,
        event.risk_level,
        event.action_taken,
      ]
    );
  } catch (dbError) {
    console.warn("Nie udało się zapisać eventu WAF w bazie:", dbError.message);
  }
};

const checkRateLimit = async (ip, endpoint) => {
  if (!wafConfig.rateLimiting.enabled) return { allowed: true };

  const key = `waf_rate:${ip}:${endpoint}`;

  try {
    const requests = await redisClient.get(key);

    if (!requests) {
      await redisClient.setEx(
        key,
        Math.floor(wafConfig.rateLimiting.windowMs / 1000),
        "1"
      );
      return {
        allowed: true,
        remaining: wafConfig.rateLimiting.maxRequests - 1,
      };
    }

    const count = parseInt(requests);
    if (count >= wafConfig.rateLimiting.maxRequests) {
      await logSecurityEvent(
        "rate_limit",
        ip,
        endpoint,
        `Rate limit exceeded: ${count} requests`,
        "",
        "medium"
      );

      return {
        allowed: false,
        retryAfter: Math.floor(wafConfig.rateLimiting.windowMs / 1000),
      };
    }

    await redisClient.incr(key);
    return {
      allowed: true,
      remaining: wafConfig.rateLimiting.maxRequests - count - 1,
    };
  } catch (redisError) {
    console.warn("Redis error in rate limiting:", redisError.message);
    return { allowed: true };
  }
};

const checkSQLInjection = (input, fieldName) => {
  if (!wafConfig.sqlInjection.enabled || !input) return { safe: true };

  const inputStr =
    typeof input === "object" ? JSON.stringify(input) : String(input);

  for (const pattern of wafConfig.sqlInjection.patterns) {
    if (pattern.test(inputStr)) {
      return {
        safe: false,
        threat: "sql_injection",
        field: fieldName,
        input: inputStr.substring(0, 200),
      };
    }
  }

  return { safe: true };
};

const checkXSS = (input, fieldName) => {
  if (!wafConfig.xss.enabled || !input) return { safe: true };

  const inputStr =
    typeof input === "object" ? JSON.stringify(input) : String(input);

  for (const pattern of wafConfig.xss.patterns) {
    if (pattern.test(inputStr)) {
      return {
        safe: false,
        threat: "xss",
        field: fieldName,
        input: inputStr.substring(0, 200),
      };
    }
  }

  return { safe: true };
};

const wafMiddleware = async (req, res, next) => {
  const startTime = process.hrtime();
  const ip = getClientIP(req);
  const endpoint = req.path;
  const userAgent = req.get("User-Agent") || "Unknown";

  const skipPaths = [
    "/health",
    "/favicon.ico",
    "/api/waf",
    "/uploads",
    "/api/notifications",
  ];
  if (skipPaths.some((path) => endpoint.startsWith(path))) {
    return next();
  }

  try {
    const rateCheck = await checkRateLimit(ip, endpoint);
    if (!rateCheck.allowed) {
      const [seconds, nanoseconds] = process.hrtime(startTime);
      const processingTime = (seconds * 1000 + nanoseconds / 1000000).toFixed(
        2
      );

      res.set({
        "X-WAF-Status": "blocked",
        "X-WAF-Reason": "rate_limit",
        "X-WAF-Processing-Time": `${processingTime}ms`,
        "Retry-After": rateCheck.retryAfter,
      });

      return res.status(429).json({
        success: false,
        message: "Zbyt wiele żądań. Spróbuj ponownie za chwilę.",
        retryAfter: rateCheck.retryAfter,
        type: "rate_limit",
      });
    }

    const allInputs = { ...req.query, ...req.body, ...req.params };
    for (const [key, value] of Object.entries(allInputs)) {
      const sqlCheck = checkSQLInjection(value, key);
      if (!sqlCheck.safe) {
        await logSecurityEvent(
          "sql_injection",
          ip,
          endpoint,
          `SQL injection attempt in field '${key}': ${sqlCheck.input}`,
          userAgent,
          "high"
        );

        res.set({
          "X-WAF-Status": "blocked",
          "X-WAF-Reason": "sql_injection",
        });

        return res.status(403).json({
          success: false,
          message: "Żądanie zostało zablokowane ze względów bezpieczeństwa.",
          reason: "Wykryto próbę SQL injection",
          type: "sql_injection",
        });
      }
    }

    for (const [key, value] of Object.entries(allInputs)) {
      const xssCheck = checkXSS(value, key);
      if (!xssCheck.safe) {
        await logSecurityEvent(
          "xss",
          ip,
          endpoint,
          `XSS attempt in field '${key}': ${xssCheck.input}`,
          userAgent,
          "high"
        );

        res.set({
          "X-WAF-Status": "blocked",
          "X-WAF-Reason": "xss",
        });

        return res.status(403).json({
          success: false,
          message: "Żądanie zostało zablokowane ze względów bezpieczeństwa.",
          reason: "Wykryto próbę XSS",
          type: "xss",
        });
      }
    }

    const [seconds, nanoseconds] = process.hrtime(startTime);
    const processingTime = (seconds * 1000 + nanoseconds / 1000000).toFixed(2);

    res.set({
      "X-WAF-Status": "passed",
      "X-WAF-Processing-Time": `${processingTime}ms`,
      "X-Content-Type-Options": "nosniff",
      "X-Frame-Options": "SAMEORIGIN",
      "X-XSS-Protection": "1; mode=block",
    });

    next();
  } catch (error) {
    console.error("WAF middleware error:", error);
    next();
  }
};

module.exports = {
  wafMiddleware,
  getWAFConfig: () => wafConfig,
  updateWAFConfig: (newConfig) => {
    if (newConfig.rateLimiting) {
      if (newConfig.rateLimiting.enabled !== undefined) {
        wafConfig.rateLimiting.enabled = newConfig.rateLimiting.enabled;
      }
      if (newConfig.rateLimiting.maxRequests !== undefined) {
        wafConfig.rateLimiting.maxRequests = newConfig.rateLimiting.maxRequests;
      }
    }

    if (newConfig.sqlInjection) {
      if (newConfig.sqlInjection.enabled !== undefined) {
        wafConfig.sqlInjection.enabled = newConfig.sqlInjection.enabled;
      }
    }

    if (newConfig.xss) {
      if (newConfig.xss.enabled !== undefined) {
        wafConfig.xss.enabled = newConfig.xss.enabled;
      }
    }

    console.log("WAF Config updated:", wafConfig);
  },
};
