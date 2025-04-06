const db = require("../models/db");

const Role = {
  addRole: async (roleName) => {
    const query = "INSERT INTO roles (name) VALUES ($1) RETURNING id, name";
    const result = await db.query(query, [roleName]);
    return result.rows[0];
  },
  addPermission: async (roleId, permissions) => {
    const queries = permissions.map((permId) => {
      return db.query(
        "INSERT INTO role_permissions (role_id, permission_id) VALUES ($1, $2)",
        [roleId, permId]
      );
    });

    await Promise.all(queries);
  },

  getRole: async () => {
    const query = `
      SELECT 
    roles.id, 
    roles.name, 
    COALESCE(JSON_AGG(
        JSON_BUILD_OBJECT('id', permissions.id, 'name', permissions.name)
    ) FILTER (WHERE permissions.id IS NOT NULL), '[]') AS permissions
FROM roles
LEFT JOIN role_permissions ON roles.id = role_permissions.role_id
LEFT JOIN permissions ON role_permissions.permission_id = permissions.id WHERE roles.name != 'admin' AND roles.name != 'user'
GROUP BY roles.id;
    `;
    const result = await db.query(query);
    return result.rows;
  },
  getPermissionByRole: async (roleId) => {
    const query = `
      SELECT permissions.id, permissions.name
      FROM permissions
      JOIN role_permissions ON permissions.id = role_permissions.permission_id
      WHERE role_permissions.role_id = $1;
    `;
    const result = await db.query(query, [roleId]);
    return result.rows;
  },
  getPermission: async () => {
    const query = "SELECT permissions.id, permissions.name FROM permissions; ";
    const result = await db.query(query);
    return result.rows;
  },

  getRoleById: async (roleId) => {
    const query = "SELECT * FROM roles WHERE id = $1;";
    const result = await db.query(query, [roleId]);
    return result.rows[0];
  },

  updateRoleName: async (roleId, roleName) => {
    const query = "UPDATE roles SET name = $1 WHERE id = $2;";
    await db.query(query, [roleName, roleId]);
  },

  deleteRolePermissions: async (roleId) => {
    const query = "DELETE FROM role_permissions WHERE role_id = $1;";
    await db.query(query, [roleId]);
  },

  addRolePermissions: async (roleId, permissions) => {
    const insertPromises = permissions.map((permId) =>
      db.query(
        "INSERT INTO role_permissions (role_id, permission_id) VALUES ($1, $2)",
        [roleId, permId]
      )
    );
    await Promise.all(insertPromises);
  },

  deleteRole: async (roleId) => {
    await db.query("DELETE FROM role_permissions WHERE role_id = $1", [roleId]);
    await db.query("DELETE FROM roles WHERE id = $1", [roleId]);
  },
};
module.exports = Role;
