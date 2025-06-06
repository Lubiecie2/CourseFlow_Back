const Role = require("../models/roleModel");
const cacheService = require("../services/cacheServices");
const USERS_CACHE_KEY = "admin:all_users";

const roleController = {
  createRole: async (req, res) => {
    const { roleName, permission } = req.body;

    if (!roleName || typeof roleName !== "string") {
      return res.status(400).json({
        message: "Nazwa roli jest wymagana i musi być tekstem.",
      });
    }

    if (!Array.isArray(permission)) {
      return res.status(400).json({
        message: "Uprawnienia muszą być tablicą identyfikatorów.",
      });
    }

    try {
      const role = await Role.addRole(roleName);

      if (permission && permission.length > 0) {
        await Role.addPermission(role.id, permission);
      }

      await cacheService.invalidate(USERS_CACHE_KEY);
      console.log("🗑️ Cache invalidated after role creation");

      return res.status(201).json({
        message: "Rola została utworzona pomyślnie.",
        role,
      });
    } catch (error) {
      console.error(error);
      return res
        .status(500)
        .json({ message: "Wystąpił błąd podczas tworzenia roli." });
    }
  },
  getRolesWithPermissions: async (req, res) => {
    try {
      const roles = await Role.getRole();

      if (!roles || roles.length === 0) {
        return res
          .status(404)
          .json({ message: "No roles found in the system." });
      }

      const rolesWithPermissions = roles.map((role) => ({
        id: role.id,
        name: role.name,
        permissions: role.permissions.map((perm) => ({
          id: perm.id,
          name: perm.name,
        })),
      }));

      return res.status(200).json(rolesWithPermissions);
    } catch (error) {
      console.error("Error fetching roles:", error);
      return res
        .status(500)
        .json({ message: "An error occurred while fetching roles." });
    }
  },
  getPermissions: async (req, res) => {
    try {
      const permission = await Role.getPermission();

      console.log("Pobrane uprawnienia:", permission);

      if (!permission || permission.length === 0) {
        return res.status(404).json({
          message: "No permissions found.",
        });
      }

      res.status(200).json(permission);
    } catch (error) {
      console.error("Błąd podczas pobierania ról:", error);
      return res
        .status(500)
        .json({ message: "Wystąpił błąd podczas pobierania ról." });
    }
  },
  updateRole: async (req, res) => {
    try {
      const { roleId } = req.params;
      const { roleName, permissions } = req.body;

      const role = await Role.getRoleById(roleId);

      console.log("Znaleziona rola", role);
      if (!role) {
        return res.status(404).json({ message: "Role not found." });
      }

      if (roleName) {
        console.log("Aktualizacja nazwy roli na:", roleName);
        await Role.updateRoleName(roleId, roleName);
      }

      if (permissions && Array.isArray(permissions)) {
        console.log("Usuwanie starych uprawnień...");
        await Role.deleteRolePermissions(roleId);
        console.log("Dodawanie nowych uprawnień:", permissions);
        await Role.addRolePermissions(roleId, permissions);
      }

      await cacheService.invalidate(USERS_CACHE_KEY);
      console.log("🗑️ Cache invalidated after role update");

      return res.status(200).json({
        message: "Role successfully updated.",
      });
    } catch (error) {
      console.error("Error updating role:", error);
      return res.status(500).json({
        message: "An error occurred while updating the role.",
      });
    }
  },

  deleteRole: async (req, res) => {
    try {
      const { roleId } = req.params;

      if (!roleId || isNaN(Number(roleId))) {
        return res.status(400).json({ message: "Invalid role ID." });
      }

      const role = await Role.getRoleById(roleId);
      if (!role) {
        return res.status(404).json({ message: "Role not found." });
      }

      await Role.deleteRolePermissions(roleId);

      await Role.deleteRole(roleId);

      await cacheService.invalidate(USERS_CACHE_KEY);
      console.log("🗑️ Cache invalidated after role deletion");

      return res.status(200).json({ message: "Role deleted successfully." });
    } catch (error) {
      console.error("Error deleting role:", error);
      return res.status(500).json({ message: "Internal server error." });
    }
  },
};

module.exports = roleController;
