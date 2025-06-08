const courseNoteModel = require("../models/courseNoteModel");
const path = require("path");
const fs = require("fs");

const courseNoteController = {
  getNotesByCourse: async (req, res) => {
    try {
      const { courseId } = req.params;
      const limit = parseInt(req.query.limit) || 10;
      const page = parseInt(req.query.page) || 1;
      const offset = (page - 1) * limit;

      const result = await courseNoteModel.getNotesByCourse(
        courseId,
        limit,
        offset
      );

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas pobierania notatek",
          error: result.error,
        });
      }

      return res.status(200).json({
        success: true,
        notes: result.notes,
        pagination: {
          total: result.total,
          page,
          limit,
          totalPages: Math.ceil(result.total / limit),
        },
      });
    } catch (error) {
      console.error("Błąd w kontrolerze notatek:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas obsługi żądania",
        error: error.message,
      });
    }
  },

  getAllNotes: async (req, res) => {
    try {
      const limit = parseInt(req.query.limit) || 10;
      const page = parseInt(req.query.page) || 1;
      const offset = (page - 1) * limit;

      const result = await courseNoteModel.getAllNotes(limit, offset);

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas pobierania notatek",
          error: result.error,
        });
      }

      return res.status(200).json({
        success: true,
        notes: result.notes,
        pagination: {
          total: result.total,
          page,
          limit,
          totalPages: Math.ceil(result.total / limit),
        },
      });
    } catch (error) {
      console.error("Błąd w kontrolerze notatek:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas obsługi żądania",
        error: error.message,
      });
    }
  },

  getNoteById: async (req, res) => {
    try {
      const { id } = req.params;
      const result = await courseNoteModel.getNoteById(id);

      if (!result.success) {
        return res.status(404).json({
          success: false,
          message: result.message || "Notatka nie została znaleziona",
          error: result.error,
        });
      }

      return res.status(200).json({
        success: true,
        note: result.note,
      });
    } catch (error) {
      console.error("Błąd w kontrolerze notatek:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas obsługi żądania",
        error: error.message,
      });
    }
  },

  createNote: async (req, res) => {
    try {
      const { title, content, courseId } = req.body;
      const userId = req.user.id;

      if (!title || !content) {
        return res.status(400).json({
          success: false,
          message: "Tytuł i treść notatki są wymagane",
        });
      }

      let filePath = null;
      let fileName = null;

      if (req.files && req.files.document && req.files.document[0]) {
        filePath = req.files.document[0].path.replace(/\\/g, "/");
        fileName = req.files.document[0].originalname;
      }

      const data = {
        title,
        content,
        userId,
        courseId: courseId ? parseInt(courseId) : null,
        filePath,
        fileName,
      };

      const result = await courseNoteModel.createNote(data);

      if (!result.success) {
        if (filePath) {
          fs.unlink(filePath, (err) => {
            if (err)
              console.error(
                "Błąd podczas usuwania pliku po nieudanym tworzeniu notatki:",
                err
              );
          });
        }
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas tworzenia notatki",
          error: result.error,
        });
      }

      const io = req.app.get("io");
      if (io) {
        io.to(`course-${courseId}`).emit("new-note", result.note);
        io.to("notes-list").emit("new-note", result.note);
      }

      return res.status(201).json({
        success: true,
        message: "Notatka została pomyślnie utworzona",
        note: result.note,
      });
    } catch (error) {
      console.error("Błąd w kontrolerze notatek:", error);
      if (req.file && req.file.path) {
        fs.unlink(
          path.join(__dirname, "..", req.file.path.replace(/\\/g, "/")),
          (err) => {
            if (err)
              console.error(
                "Błąd podczas usuwania pliku po błędzie w kontrolerze:",
                err
              );
          }
        );
      }
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas obsługi żądania",
        error: error.message,
      });
    }
  },

  updateNote: async (req, res) => {
    try {
      const { id } = req.params;
      const { title, content } = req.body;
      const userId = req.user.id;
      const isAdmin = req.user.role_id === 1;

      if (!title && !content && !req.file) {
        return res.status(400).json({
          success: false,
          message: "Nie podano żadnych danych do aktualizacji.",
        });
      }

      const dataToUpdate = {};
      if (title) dataToUpdate.title = title;
      if (content) dataToUpdate.content = content;

      if (req.files && req.files.document && req.files.document[0]) {
        dataToUpdate.filePath = req.files.document[0].path.replace(/\\/g, "/");
        dataToUpdate.fileName = req.files.document[0].originalname;
      }

      const result = await courseNoteModel.updateNote(
        id,
        dataToUpdate,
        userId,
        isAdmin
      );

      if (!result.success) {
        if (req.file && dataToUpdate.filePath) {
          fs.unlink(
            path.join(__dirname, "..", dataToUpdate.filePath),
            (err) => {
              if (err)
                console.error(
                  "Błąd podczas usuwania nowego pliku po nieudanej aktualizacji notatki:",
                  err
                );
            }
          );
        }
        const statusCode =
          result.message && result.message.includes("uprawnień")
            ? 403
            : result.message && result.message.includes("znaleziona")
            ? 404
            : 500;
        return res.status(statusCode).json({
          success: false,
          message:
            result.message || "Wystąpił błąd podczas aktualizacji notatki",
          error: result.error,
        });
      }

      const io = req.app.get("io");
      if (io && result.note) {
        io.to(`course-${result.note.course_id}`).emit(
          "note-updated",
          result.note
        );
      }

      return res.status(200).json({
        success: true,
        message: result.message || "Notatka została pomyślnie zaktualizowana",
        note: result.note,
      });
    } catch (error) {
      console.error("Błąd w kontrolerze notatek:", error);
      if (req.file && req.file.path) {
        fs.unlink(
          path.join(__dirname, "..", req.file.path.replace(/\\/g, "/")),
          (err) => {
            if (err)
              console.error(
                "Błąd podczas usuwania pliku po błędzie w kontrolerze aktualizacji:",
                err
              );
          }
        );
      }
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas obsługi żądania",
        error: error.message,
      });
    }
  },

  deleteNote: async (req, res) => {
    try {
      const { id } = req.params;
      const userId = req.user.id;
      const isAdmin = req.user.role_id === 1;

      const noteToDelete = await courseNoteModel.getNoteById(id);
      if (!noteToDelete.success) {
        return res.status(404).json({
          success: false,
          message: "Notatka nie została znaleziona",
        });
      }

      const result = await courseNoteModel.deleteNote(id, userId, isAdmin);

      if (!result.success) {
        const statusCode = result.message.includes("uprawnień") ? 403 : 404;
        return res.status(statusCode).json({
          success: false,
          message: result.message,
        });
      }

      const io = req.app.get("io");
      if (io && noteToDelete.note) {
        io.to(`course-${noteToDelete.note.course_id}`).emit("note-removed", id);
      }

      return res.status(200).json({
        success: true,
        message: result.message,
      });
    } catch (error) {
      console.error("Błąd w kontrolerze notatek:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas usuwania notatki",
        error: error.message,
      });
    }
  },

  downloadNoteFile: async (req, res) => {
    try {
      const { id } = req.params;
      const result = await courseNoteModel.getNoteById(id);

      if (!result.success || !result.note.file_path) {
        return res.status(404).json({
          success: false,
          message: "Plik nie został znaleziony",
        });
      }

      let filePath;
      if (result.note.file_path.startsWith("uploads/")) {
        filePath = path.join(__dirname, "..", result.note.file_path);
      } else {
        filePath = result.note.file_path;
      }

      console.log("Próba dostępu do pliku:", filePath);

      if (!fs.existsSync(filePath)) {
        console.error("Plik nie istnieje pod ścieżką:", filePath);
        return res.status(404).json({
          success: false,
          message: "Plik nie istnieje",
        });
      }

      const fileExt = path.extname(result.note.file_name).toLowerCase();
      let contentType = "application/octet-stream";

      if (fileExt === ".pdf") contentType = "application/pdf";
      else if (fileExt === ".txt") contentType = "text/plain";
      else if ([".jpg", ".jpeg"].includes(fileExt)) contentType = "image/jpeg";
      else if (fileExt === ".png") contentType = "image/png";
      else if (fileExt === ".gif") contentType = "image/gif";
      else if (fileExt === ".webp") contentType = "image/webp";

      res.setHeader("Content-Type", contentType);
      res.setHeader(
        "Content-Disposition",
        `attachment; filename="${result.note.file_name}"`
      );

      const fileStream = fs.createReadStream(filePath);
      fileStream.pipe(res);
    } catch (error) {
      console.error("Błąd podczas pobierania pliku notatki:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas pobierania pliku",
        error: error.message,
      });
    }
  },
};

module.exports = courseNoteController;
