const Role = require("../models/roleModel");

const roleController = {
  createRole: async (req, res) => {
    const { roleName, permission } = req.body;

    try {
      const role = await Role.addRole(roleName);

      if (permission && permission.length > 0) {
        await Role.addPermission(role.id, permission);
      }
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
      console.log(roles);
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
      console.error("Błąd podczas pobierania ról:", error);
      return res
        .status(500)
        .json({ message: "Wystąpił błąd podczas pobierania ról." });
    }
  },
  getPermissions: async (req, res) => {
    try {
      const permission = await Role.getPermission();
      res.status(200).json(permission);
    } catch (error) {
      console.error("Błąd podczas pobierania ról:", error);
      return res
        .status(500)
        .json({ message: "Wystąpił błąd podczas pobierania ról." });
    }
  },
  updateRole: async (req, res) => {
    const { roleId } = req.params;
    const { roleName, permissions } = req.body;

    const role = await Role.getRoleById(roleId);

    console.log("Znaleziona rola", role);
    if (!role) {
      return res.status(404).json({ message: "Rola nie znaleziona." });
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

    return res.status(200).json({
      message: "Rola została zaktualizowana pomyślnie.",
    });
  },
};

module.exports = roleController;
