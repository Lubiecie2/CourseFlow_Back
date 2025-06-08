const fs = require("fs");
const path = require("path");
const db = require("./db");

const courseNoteModel = {
  getNotesByCourse: async (courseId, limit, offset) => {
    try {
      const query = `
        SELECT 
          n.id, n.title, n.content, n.user_id, n.course_id, n.file_path, n.file_name, n.created_at, n.updated_at,
          u.first_name, u.last_name, u.email,
          c.title as course_title,
          COUNT(*) OVER() as full_count
        FROM course_notes n
        JOIN users u ON n.user_id = u.id
        LEFT JOIN courses c ON n.course_id = c.id
        WHERE n.course_id = $1
        ORDER BY n.created_at DESC
        LIMIT $2 OFFSET $3
      `;

      const result = await db.query(query, [courseId, limit, offset]);
      const total =
        result.rows.length > 0 ? parseInt(result.rows[0].full_count) : 0;

      return {
        success: true,
        notes: result.rows,
        total,
      };
    } catch (error) {
      console.error("Błąd podczas pobierania notatek dla kursu:", error);
      return {
        success: false,
        error: error.message,
      };
    }
  },

  getAllNotes: async (limit, offset) => {
    try {
      const query = `
        SELECT 
          n.id, n.title, n.content, n.user_id, n.course_id, n.file_path, n.file_name, n.created_at, n.updated_at,
          u.first_name, u.last_name, u.email,
          c.title as course_title,
          COUNT(*) OVER() as full_count
        FROM course_notes n
        JOIN users u ON n.user_id = u.id
        LEFT JOIN courses c ON n.course_id = c.id
        ORDER BY n.created_at DESC
        LIMIT $1 OFFSET $2
      `;

      const result = await db.query(query, [limit, offset]);
      const total =
        result.rows.length > 0 ? parseInt(result.rows[0].full_count) : 0;

      return {
        success: true,
        notes: result.rows,
        total,
      };
    } catch (error) {
      console.error("Błąd podczas pobierania wszystkich notatek:", error);
      return {
        success: false,
        error: error.message,
      };
    }
  },

  getNoteById: async (noteId) => {
    try {
      const query = `
        SELECT 
          n.id, n.title, n.content, n.user_id, n.course_id, n.file_path, n.file_name, n.created_at, n.updated_at,
          u.first_name, u.last_name, u.email,
          c.title as course_title
        FROM course_notes n
        JOIN users u ON n.user_id = u.id
        LEFT JOIN courses c ON n.course_id = c.id
        WHERE n.id = $1
      `;
      const result = await db.query(query, [noteId]);

      if (result.rows.length === 0) {
        return {
          success: false,
          message: "Notatka nie została znaleziona",
        };
      }

      return {
        success: true,
        note: result.rows[0],
      };
    } catch (error) {
      console.error("Błąd podczas pobierania notatki:", error);
      return {
        success: false,
        error: error.message,
      };
    }
  },

  createNote: async (data) => {
    try {
      const { title, content, userId, courseId, filePath, fileName } = data;

      const query = `
      INSERT INTO course_notes(title, content, user_id, course_id, file_path, file_name, created_at, updated_at)
      VALUES($1, $2, $3, $4, $5, $6, NOW(), NOW())
      RETURNING id, title, content, user_id, course_id, file_path, file_name, created_at, updated_at
    `;

      const values = [title, content, userId, courseId, filePath, fileName];

      const result = await db.query(query, values);
      const newNote = result.rows[0];

      const userQuery = `SELECT id, first_name, last_name, email FROM users WHERE id = $1`;
      const userResult = await db.query(userQuery, [newNote.user_id]);

      return {
        success: true,
        note: {
          ...newNote,
          user: {
            id: newNote.user_id,
            first_name: userResult.rows[0].first_name,
            last_name: userResult.rows[0].last_name,
            email: userResult.rows[0].email,
          },
        },
      };
    } catch (error) {
      console.error("Błąd podczas tworzenia notatki:", error);
      return {
        success: false,
        error: error.message,
      };
    }
  },

  updateNote: async (noteId, data, userId, isAdmin = false) => {
    try {
      const { title, content, filePath, fileName } = data;

      const checkQuery = `SELECT user_id, file_path FROM course_notes WHERE id = $1`;
      const checkResult = await db.query(checkQuery, [noteId]);

      if (checkResult.rows.length === 0) {
        return {
          success: false,
          message: "Notatka nie została znaleziona",
        };
      }

      const noteOwnerId = checkResult.rows[0].user_id;
      const oldFilePath = checkResult.rows[0].file_path;

      if (noteOwnerId !== userId && !isAdmin) {
        return {
          success: false,
          message: "Nie masz uprawnień do edycji tej notatki",
        };
      }

      let updateFields = [];
      let values = [];
      let paramIndex = 1;

      if (title !== undefined) {
        updateFields.push(`title = $${paramIndex++}`);
        values.push(title);
      }
      if (content !== undefined) {
        updateFields.push(`content = $${paramIndex++}`);
        values.push(content);
      }
      if (filePath !== undefined) {
        updateFields.push(`file_path = $${paramIndex++}`);
        values.push(filePath);
        updateFields.push(`file_name = $${paramIndex++}`);
        values.push(fileName);

        if (oldFilePath && filePath !== oldFilePath) {
          const fullOldPath = path.join(__dirname, "..", oldFilePath);
          if (fs.existsSync(fullOldPath)) {
            fs.unlinkSync(fullOldPath);
          }
        }
      }

      if (updateFields.length === 0) {
        const noteResult = await courseNoteModel.getNoteById(noteId);
        return {
          success: true,
          message: "Nie podano danych do aktualizacji",
          note: noteResult.note,
        };
      }

      updateFields.push(`updated_at = NOW()`);
      values.push(parseInt(noteId));

      const query = `
        UPDATE course_notes
        SET ${updateFields.join(", ")}
        WHERE id = $${paramIndex}
        RETURNING id, title, content, user_id, course_id, file_path, file_name, created_at, updated_at
      `;

      const result = await db.query(query, values);
      const updatedNote = result.rows[0];

      const userQuery = `SELECT id, first_name, last_name, email FROM users WHERE id = $1`;
      const userResult = await db.query(userQuery, [updatedNote.user_id]);

      let courseTitle = null;
      if (updatedNote.course_id) {
        const courseQuery = `SELECT title FROM courses WHERE id = $1`;
        const courseResult = await db.query(courseQuery, [
          updatedNote.course_id,
        ]);
        if (courseResult.rows.length > 0) {
          courseTitle = courseResult.rows[0].title;
        }
      }

      return {
        success: true,
        message: "Notatka została pomyślnie zaktualizowana",
        note: {
          ...updatedNote,
          user: {
            id: updatedNote.user_id,
            first_name: userResult.rows[0].first_name,
            last_name: userResult.rows[0].last_name,
            email: userResult.rows[0].email,
          },
          course_title: courseTitle,
        },
      };
    } catch (error) {
      console.error("Błąd podczas aktualizacji notatki:", error);
      return {
        success: false,
        error: error.message,
      };
    }
  },

  deleteNote: async (noteId, userId, isAdmin = false) => {
    try {
      const checkQuery = `SELECT user_id, file_path FROM course_notes WHERE id = $1`;
      const checkResult = await db.query(checkQuery, [noteId]);

      if (checkResult.rows.length === 0) {
        return {
          success: false,
          message: "Notatka nie została znaleziona",
        };
      }

      const noteOwnerId = checkResult.rows[0].user_id;
      const filePath = checkResult.rows[0].file_path;

      if (noteOwnerId !== userId && !isAdmin) {
        return {
          success: false,
          message: "Nie masz uprawnień do usunięcia tej notatki",
        };
      }

      const deleteQuery = `DELETE FROM course_notes WHERE id = $1`;
      await db.query(deleteQuery, [noteId]);

      if (filePath) {
        const fullPath = path.join(__dirname, "..", filePath);
        if (fs.existsSync(fullPath)) {
          fs.unlinkSync(fullPath);
        }
      }

      return {
        success: true,
        message: "Notatka została pomyślnie usunięta",
      };
    } catch (error) {
      console.error("Błąd podczas usuwania notatki:", error);
      return {
        success: false,
        error: error.message,
      };
    }
  },

  getNoteFile: async (noteId) => {
    try {
      const query = `
        SELECT file_path, file_name 
        FROM course_notes 
        WHERE id = $1 AND file_path IS NOT NULL
      `;
      const result = await db.query(query, [noteId]);

      if (result.rows.length === 0) {
        return {
          success: false,
          message: "Plik nie został znaleziony",
        };
      }

      return {
        success: true,
        filePath: result.rows[0].file_path,
        fileName: result.rows[0].file_name,
      };
    } catch (error) {
      console.error("Błąd podczas pobierania pliku notatki:", error);
      return {
        success: false,
        error: error.message,
      };
    }
  },
};

module.exports = courseNoteModel;
