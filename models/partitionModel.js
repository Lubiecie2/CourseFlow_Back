const db = require("./db");

const partitionModel = {
  getAllPartitions: async (tableName) => {
    try {
      const query = `
        SELECT 
          child.relname AS partition_name,
          pg_size_pretty(pg_relation_size(child.oid)) AS size,
          true AS is_attached,
          substring(pg_catalog.pg_get_expr(child.relpartbound, child.oid), 
                   'FROM \\(''(.+?)''\\).*TO \\(''(.+?)''\\)') AS bounds
        FROM pg_inherits
        JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
        JOIN pg_class child ON pg_inherits.inhrelid = child.oid
        WHERE parent.relname = $1
        
        UNION ALL
        
        SELECT 
          c.relname AS partition_name,
          pg_size_pretty(pg_relation_size(c.oid)) AS size,
          false AS is_attached,
          NULL AS bounds
        FROM pg_class c
        WHERE c.relname LIKE $2
        AND c.relkind = 'r'
        AND NOT EXISTS (
          SELECT 1 FROM pg_inherits WHERE pg_inherits.inhrelid = c.oid
        )
        
        ORDER BY partition_name`;

      const result = await db.query(query, [tableName, `${tableName}\\_y%`]);

      const processedResults = result.rows.map((row) => {
        if (row.bounds) {
          const matches = row.bounds.split(",");
          if (matches && matches.length === 2) {
            const startDateStr = matches[0];
            const endDateStr = matches[1];

            const startDate = startDateStr
              ? new Date(startDateStr).toISOString().split("T")[0]
              : null;
            const endDate = endDateStr
              ? new Date(endDateStr).toISOString().split("T")[0]
              : null;

            return {
              ...row,
              start_date: startDate,
              end_date: endDate,
              bounds: undefined,
            };
          }
        }

        const match = row.partition_name.match(/y(\d{4})(\d{2})$/);
        if (match) {
          const year = parseInt(match[1]);
          const month = parseInt(match[2]);

          const startDate = new Date(year, month - 1, 1);
          const endDate = new Date(year, month, 0);

          return {
            ...row,
            start_date: startDate.toISOString().split("T")[0],
            end_date: endDate.toISOString().split("T")[0],
            bounds: undefined,
          };
        }

        return {
          ...row,
          bounds: undefined,
        };
      });

      return processedResults;
    } catch (error) {
      console.error("Błąd podczas pobierania partycji:", error);
      throw error;
    }
  },

  createPartition: async (tableName, year, month) => {
    try {
      const query = "SELECT create_monthly_partition($1, $2, $3) AS result";
      const result = await db.query(query, [tableName, year, month]);
      return result.rows[0].result;
    } catch (error) {
      console.error("Błąd podczas tworzenia partycji:", error);
      throw error;
    }
  },

  detachPartition: async (tableName, year, month) => {
    try {
      const query = "SELECT detach_partition($1, $2, $3) AS result";
      const result = await db.query(query, [tableName, year, month]);
      return result.rows[0].result;
    } catch (error) {
      console.error("Błąd podczas odłączania partycji:", error);
      throw error;
    }
  },

  attachPartition: async (tableName, year, month) => {
    try {
      const query = "SELECT attach_partition($1, $2, $3) AS result";
      const result = await db.query(query, [tableName, year, month]);
      return result.rows[0].result;
    } catch (error) {
      console.error("Błąd podczas podłączania partycji:", error);
      throw error;
    }
  },

  preparePartitions: async (tableName, monthsAhead = 2) => {
    try {
      const now = new Date();
      const results = [];

      const currentYear = now.getFullYear();
      const currentMonth = now.getMonth() + 1;

      results.push(
        await partitionModel.createPartition(
          tableName,
          currentYear,
          currentMonth
        )
      );

      for (let i = 1; i <= monthsAhead; i++) {
        let futureDate = new Date(now);
        futureDate.setMonth(now.getMonth() + i);

        const futureYear = futureDate.getFullYear();
        const futureMonth = futureDate.getMonth() + 1;

        results.push(
          await partitionModel.createPartition(
            tableName,
            futureYear,
            futureMonth
          )
        );
      }

      return results;
    } catch (error) {
      console.error("Błąd podczas przygotowywania partycji:", error);
      throw error;
    }
  },
};

module.exports = partitionModel;
