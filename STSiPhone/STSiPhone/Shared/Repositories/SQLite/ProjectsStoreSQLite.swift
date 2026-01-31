import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class ProjectsStoreSQLite {
    private let database: SQLiteDatabase
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(database: SQLiteDatabase) throws {
        self.database = database
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        try createSchemaIfNeeded()
    }

    // MARK: - Public API

    func fetchAllProjects() throws -> [Project] {
        var projects: [Project] = []
        let sql = """
        SELECT
            id, title, created_at, updated_at,
            casting_office, casting_director_json, representation_json,
            cc_contacts_json, bcc_contacts_json,
            is_favorite, is_archived, is_completed,
            scene_count, audition_due_date, shoot_date,
            project_type, genre,
            sides_file_name, breakdown_file_name, submitted_headshot_id,
            breakdown_notes, slate_selections_json,
            pay_deal_tags_raw, pay_rate_text, pay_craft_vs_money,
            pay_union_status_raw, pay_role_type_raw
        FROM projects
        ORDER BY created_at DESC;
        """

        let statement = try database.prepareStatement(sql)
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            let row = try ProjectRow(statement: statement, decoder: decoder)
            let roles = try fetchRoles(projectID: row.id)
            let sessions = try fetchSessions(projectID: row.id)
            let project = row.makeProject(roles: roles, sessions: sessions)
            projects.append(project)
        }
        return projects
    }

    func fetchProject(id: UUID) throws -> Project? {
        let sql = """
        SELECT
            id, title, created_at, updated_at,
            casting_office, casting_director_json, representation_json,
            cc_contacts_json, bcc_contacts_json,
            is_favorite, is_archived, is_completed,
            scene_count, audition_due_date, shoot_date,
            project_type, genre,
            sides_file_name, breakdown_file_name, submitted_headshot_id,
            breakdown_notes, slate_selections_json,
            pay_deal_tags_raw, pay_rate_text, pay_craft_vs_money,
            pay_union_status_raw, pay_role_type_raw
        FROM projects
        WHERE id = ?;
        """

        let statement = try database.prepareStatement(sql)
        defer { sqlite3_finalize(statement) }
        bindText(id.uuidString, statement: statement, index: 1)

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        let row = try ProjectRow(statement: statement, decoder: decoder)
        let roles = try fetchRoles(projectID: row.id)
        let sessions = try fetchSessions(projectID: row.id)
        return row.makeProject(roles: roles, sessions: sessions)
    }

    func upsertProject(_ project: Project) throws {
        try database.inTransaction {
            try upsertProjectRow(project)
            try replaceRoles(project.roles, projectID: project.id)
            try replaceSessions(project.sessions, projectID: project.id)
        }
    }

    func updatePIPSlateSession(projectID: UUID, sessionID: UUID, pipSlateSessionJSON: String?) throws {
        let sql = """
        UPDATE sessions
        SET pip_slate_session_json = ?, updated_at = ?
        WHERE id = ? AND project_id = ?;
        """

        let statement = try database.prepareStatement(sql)
        defer { sqlite3_finalize(statement) }

        if let json = pipSlateSessionJSON {
            bindText(json, statement: statement, index: 1)
        } else {
            sqlite3_bind_null(statement, 1)
        }

        sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
        bindText(sessionID.uuidString, statement: statement, index: 3)
        bindText(projectID.uuidString, statement: statement, index: 4)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteDatabaseError.execute(message: "Failed to update PiP slate session JSON")
        }
    }

    // MARK: - Archive state updates

    func setProjectArchived(projectID: UUID, isArchived: Bool) throws {
        let sql = "UPDATE projects SET is_archived = ?, updated_at = ? WHERE id = ?;"
        let statement = try database.prepareStatement(sql)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, isArchived ? 1 : 0)
        sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
        bindText(projectID.uuidString, statement: statement, index: 3)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteDatabaseError.execute(message: "Failed to update archive state for project \(projectID)")
        }
    }

    func setSessionArchived(projectID: UUID, sessionID: UUID, isArchived: Bool) throws {
        let sql = "UPDATE sessions SET is_archived = ?, updated_at = ? WHERE id = ? AND project_id = ?;"
        let statement = try database.prepareStatement(sql)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, isArchived ? 1 : 0)
        sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
        bindText(sessionID.uuidString, statement: statement, index: 3)
        bindText(projectID.uuidString, statement: statement, index: 4)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteDatabaseError.execute(message: "Failed to update archive state for session \(sessionID)")
        }
    }

    func unarchiveAllProjects() throws {
        let sql = "UPDATE projects SET is_archived = 0, updated_at = ? WHERE is_archived = 1;"
        let statement = try database.prepareStatement(sql)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, Date().timeIntervalSince1970)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteDatabaseError.execute(message: "Failed to unarchive all projects")
        }
    }

    func deleteProject(id: UUID) throws {
        let sql = "DELETE FROM projects WHERE id = ?;"
        let statement = try database.prepareStatement(sql)
        defer { sqlite3_finalize(statement) }
        bindText(id.uuidString, statement: statement, index: 1)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteDatabaseError.execute(message: "Failed to delete project \(id)")
        }
    }

    // MARK: - Schema

    private func createSchemaIfNeeded() throws {
        let statements: [String] = [
            """
            CREATE TABLE IF NOT EXISTS projects (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                casting_office TEXT,
                casting_director_json TEXT,
                representation_json TEXT,
                cc_contacts_json TEXT,
                bcc_contacts_json TEXT,
                is_favorite INTEGER NOT NULL DEFAULT 0,
                is_archived INTEGER NOT NULL DEFAULT 0,
                is_completed INTEGER NOT NULL DEFAULT 0,
                scene_count INTEGER NOT NULL DEFAULT 1,
                audition_due_date REAL,
                shoot_date REAL,
                project_type TEXT,
                genre TEXT,
                sides_file_name TEXT,
                breakdown_file_name TEXT,
                submitted_headshot_id TEXT,
                breakdown_notes TEXT,
                slate_selections_json TEXT,
                pay_deal_tags_raw TEXT,
                pay_rate_text TEXT,
                pay_craft_vs_money REAL,
                pay_union_status_raw TEXT,
                pay_role_type_raw TEXT
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS roles (
                id TEXT PRIMARY KEY,
                project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
                name TEXT NOT NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
                type TEXT NOT NULL,
                date REAL NOT NULL,
                updated_at REAL NOT NULL,
                audition_due_date_override REAL,
                scene_count_override INTEGER,
                submitted_headshot_id_override TEXT,
                slate_selections_override_json TEXT,
                role_name TEXT,
                notes TEXT,
                callback_notes TEXT,
                parking_info TEXT,
                is_archived INTEGER NOT NULL DEFAULT 0,
                is_favorite INTEGER NOT NULL DEFAULT 0,
                primary_orientation TEXT,
                smart_fill_enabled INTEGER,
                slate_prompt TEXT,
                slate_prompt_mode TEXT,
                slate_prompt_override TEXT,
                slate_prompt_inputs_hash TEXT,
                slate_prompt_updated_at REAL,
                last_custom_slate_prompt TEXT,
                sides_file_name TEXT,
                breakdown_file_name TEXT,
                breakdown_notes TEXT,
                location_json TEXT,
                contact_json TEXT,
                pip_slate_session_json TEXT,
                in_person_address_json TEXT,
                in_person_address_raw_paste TEXT,
                casting_phone TEXT,
                rep_phone TEXT,
                checklist_progress_json TEXT,
                unlocked_badges_json TEXT
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS takes (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
                project_id TEXT NOT NULL,
                file_path TEXT NOT NULL,
                thumbnail_path TEXT,
                duration_seconds REAL,
                created_at REAL NOT NULL,
                scene_number INTEGER,
                take_number INTEGER,
                slate_number TEXT,
                slate_id TEXT,
                take_notes TEXT,
                rating TEXT,
                take_type TEXT,
                submitted_at REAL,
                captured_orientation TEXT,
                override_smart_fill TEXT,
                smart_filled_file_path TEXT,
                edited_file_path TEXT,
                export_metadata_json TEXT,
                exported_from_take_ids_json TEXT,
                edit_metadata_json TEXT,
                smart_fill_settings_json TEXT,
                pip_slate_metadata_json TEXT,
                last_export_date REAL
            );
            """,
            "CREATE INDEX IF NOT EXISTS idx_sessions_project_id ON sessions(project_id);",
            "CREATE INDEX IF NOT EXISTS idx_takes_session_id ON takes(session_id);",
            "CREATE INDEX IF NOT EXISTS idx_takes_project_id ON takes(project_id);"
        ]

        try statements.forEach { try database.execute($0) }

        // Add submitted_at column if the table predates this field.
        if !columnExists("submitted_at", in: "takes") {
            try database.execute("ALTER TABLE takes ADD COLUMN submitted_at REAL;")
        }

        // Add new session override columns if the table predates these fields.
        if !columnExists("audition_due_date_override", in: "sessions") {
            try database.execute("ALTER TABLE sessions ADD COLUMN audition_due_date_override REAL;")
        }
        if !columnExists("scene_count_override", in: "sessions") {
            try database.execute("ALTER TABLE sessions ADD COLUMN scene_count_override INTEGER;")
        }
        if !columnExists("submitted_headshot_id_override", in: "sessions") {
            try database.execute("ALTER TABLE sessions ADD COLUMN submitted_headshot_id_override TEXT;")
        }
        if !columnExists("slate_selections_override_json", in: "sessions") {
            try database.execute("ALTER TABLE sessions ADD COLUMN slate_selections_override_json TEXT;")
        }
        if !columnExists("in_person_address_json", in: "sessions") {
            try database.execute("ALTER TABLE sessions ADD COLUMN in_person_address_json TEXT;")
        }
        if !columnExists("in_person_address_raw_paste", in: "sessions") {
            try database.execute("ALTER TABLE sessions ADD COLUMN in_person_address_raw_paste TEXT;")
        }
        if !columnExists("casting_phone", in: "sessions") {
            try database.execute("ALTER TABLE sessions ADD COLUMN casting_phone TEXT;")
        }
        if !columnExists("rep_phone", in: "sessions") {
            try database.execute("ALTER TABLE sessions ADD COLUMN rep_phone TEXT;")
        }
        if !columnExists("slate_prompt_mode", in: "sessions") {
            try database.execute("ALTER TABLE sessions ADD COLUMN slate_prompt_mode TEXT;")
        }
        if !columnExists("slate_prompt_override", in: "sessions") {
            try database.execute("ALTER TABLE sessions ADD COLUMN slate_prompt_override TEXT;")
        }
        if !columnExists("slate_prompt_inputs_hash", in: "sessions") {
            try database.execute("ALTER TABLE sessions ADD COLUMN slate_prompt_inputs_hash TEXT;")
        }
        if !columnExists("slate_prompt_updated_at", in: "sessions") {
            try database.execute("ALTER TABLE sessions ADD COLUMN slate_prompt_updated_at REAL;")
        }
        if !columnExists("last_custom_slate_prompt", in: "sessions") {
            try database.execute("ALTER TABLE sessions ADD COLUMN last_custom_slate_prompt TEXT;")
        }
    }

    // MARK: - Insert helpers

    private func upsertProjectRow(_ project: Project) throws {
        let sql = """
        INSERT INTO projects (
            id, title, created_at, updated_at,
            casting_office, casting_director_json, representation_json,
            cc_contacts_json, bcc_contacts_json,
            is_favorite, is_archived, is_completed,
            scene_count, audition_due_date, shoot_date,
            project_type, genre,
            sides_file_name, breakdown_file_name, submitted_headshot_id,
            breakdown_notes, slate_selections_json,
            pay_deal_tags_raw, pay_rate_text, pay_craft_vs_money,
            pay_union_status_raw, pay_role_type_raw
        ) VALUES (
            ?, ?, ?, ?,
            ?, ?, ?,
            ?, ?,
            ?, ?, ?,
            ?, ?, ?,
            ?, ?,
            ?, ?, ?,
            ?, ?,
            ?, ?, ?,
            ?, ?
        )
        ON CONFLICT(id) DO UPDATE SET
            title = excluded.title,
            created_at = excluded.created_at,
            updated_at = excluded.updated_at,
            casting_office = excluded.casting_office,
            casting_director_json = excluded.casting_director_json,
            representation_json = excluded.representation_json,
            cc_contacts_json = excluded.cc_contacts_json,
            bcc_contacts_json = excluded.bcc_contacts_json,
            is_favorite = excluded.is_favorite,
            is_archived = excluded.is_archived,
            is_completed = excluded.is_completed,
            scene_count = excluded.scene_count,
            audition_due_date = excluded.audition_due_date,
            shoot_date = excluded.shoot_date,
            project_type = excluded.project_type,
            genre = excluded.genre,
            sides_file_name = excluded.sides_file_name,
            breakdown_file_name = excluded.breakdown_file_name,
            submitted_headshot_id = excluded.submitted_headshot_id,
            breakdown_notes = excluded.breakdown_notes,
            slate_selections_json = excluded.slate_selections_json,
            pay_deal_tags_raw = excluded.pay_deal_tags_raw,
            pay_rate_text = excluded.pay_rate_text,
            pay_craft_vs_money = excluded.pay_craft_vs_money,
            pay_union_status_raw = excluded.pay_union_status_raw,
            pay_role_type_raw = excluded.pay_role_type_raw;
        """

        let statement = try database.prepareStatement(sql)
        defer { sqlite3_finalize(statement) }

        bindText(project.id.uuidString, statement: statement, index: 1)
        bindText(project.title, statement: statement, index: 2)
        sqlite3_bind_double(statement, 3, project.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 4, Date().timeIntervalSince1970)
        bindOptionalText(project.castingOffice, statement: statement, index: 5)
        bindOptionalText(encodeJSON(project.castingDirector), statement: statement, index: 6)
        bindOptionalText(encodeJSON(project.representation), statement: statement, index: 7)
        bindOptionalText(encodeJSON(project.ccContacts), statement: statement, index: 8)
        bindOptionalText(encodeJSON(project.bccContacts), statement: statement, index: 9)
        sqlite3_bind_int(statement, 10, project.isFavorite ? 1 : 0)
        sqlite3_bind_int(statement, 11, project.isArchived ? 1 : 0)
        sqlite3_bind_int(statement, 12, project.isCompleted ? 1 : 0)
        sqlite3_bind_int(statement, 13, Int32(project.sceneCount))
        bindDate(statement, index: 14, date: project.auditionDueDate)
        bindDate(statement, index: 15, date: project.shootDate)
        bindText(project.projectType, statement: statement, index: 16)
        bindText(project.genre, statement: statement, index: 17)
        bindOptionalText(project.sidesFileName, statement: statement, index: 18)
        bindOptionalText(project.breakdownFileName, statement: statement, index: 19)
        if let headshotID = project.submittedHeadshotID {
            bindText(headshotID.uuidString, statement: statement, index: 20)
        } else {
            sqlite3_bind_null(statement, 20)
        }
        bindOptionalText(project.breakdownNotes, statement: statement, index: 21)
        bindOptionalText(encodeJSON(project.slateSelections), statement: statement, index: 22)
        bindOptionalText(project.payDealTagsRaw, statement: statement, index: 23)
        bindOptionalText(project.payRateText, statement: statement, index: 24)
        if let craftValue = project.payCraftVsMoney {
            sqlite3_bind_double(statement, 25, craftValue)
        } else {
            sqlite3_bind_null(statement, 25)
        }
        bindOptionalText(project.payUnionStatusRaw, statement: statement, index: 26)
        bindOptionalText(project.payRoleTypeRaw, statement: statement, index: 27)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteDatabaseError.execute(message: "Failed to upsert project")
        }
    }

    private func columnExists(_ column: String, in table: String) -> Bool {
        let sql = "PRAGMA table_info(\(table));"
        guard let statement = try? database.prepareStatement(sql) else { return false }
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let namePointer = sqlite3_column_text(statement, 1) else { continue }
            if String(cString: namePointer) == column {
                return true
            }
        }
        return false
    }

    private func replaceRoles(_ roles: [Role], projectID: UUID) throws {
        let deleteSQL = "DELETE FROM roles WHERE project_id = ?;"
        let deleteStmt = try database.prepareStatement(deleteSQL)
        bindText(projectID.uuidString, statement: deleteStmt, index: 1)
        guard sqlite3_step(deleteStmt) == SQLITE_DONE else {
            sqlite3_finalize(deleteStmt)
            throw SQLiteDatabaseError.execute(message: "Failed to delete roles")
        }
        sqlite3_finalize(deleteStmt)

        guard !roles.isEmpty else { return }
        let insertSQL = "INSERT INTO roles (id, project_id, name) VALUES (?, ?, ?);"
        for role in roles {
            let stmt = try database.prepareStatement(insertSQL)
            bindText(role.id.uuidString, statement: stmt, index: 1)
            bindText(projectID.uuidString, statement: stmt, index: 2)
            bindText(role.name, statement: stmt, index: 3)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                sqlite3_finalize(stmt)
                throw SQLiteDatabaseError.execute(message: "Failed to insert role")
            }
            sqlite3_finalize(stmt)
        }
    }

    private func replaceSessions(_ sessions: [ProjectSession], projectID: UUID) throws {
        let deleteSQL = "DELETE FROM sessions WHERE project_id = ?;"
        let stmt = try database.prepareStatement(deleteSQL)
        bindText(projectID.uuidString, statement: stmt, index: 1)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            sqlite3_finalize(stmt)
            throw SQLiteDatabaseError.execute(message: "Failed to clear sessions")
        }
        sqlite3_finalize(stmt)

        guard !sessions.isEmpty else { return }
        for session in sessions {
            try insertSession(session, projectID: projectID)
        }
    }

    private func insertSession(_ session: ProjectSession, projectID: UUID) throws {
        let sql = """
        INSERT INTO sessions (
            id, project_id, type, date, updated_at,
            audition_due_date_override, scene_count_override, submitted_headshot_id_override, slate_selections_override_json,
            role_name, notes, callback_notes, parking_info,
            is_archived, is_favorite,
            primary_orientation, smart_fill_enabled,
            slate_prompt, slate_prompt_mode, slate_prompt_override, slate_prompt_inputs_hash, slate_prompt_updated_at, last_custom_slate_prompt,
            sides_file_name, breakdown_file_name, breakdown_notes,
            location_json, contact_json, pip_slate_session_json,
            in_person_address_json, in_person_address_raw_paste, casting_phone, rep_phone,
            checklist_progress_json, unlocked_badges_json
        ) VALUES (
            ?, ?, ?, ?, ?,
            ?, ?, ?, ?,
            ?, ?, ?, ?,
            ?, ?,
            ?, ?,
            ?, ?, ?, ?, ?, ?,
            ?, ?, ?,
            ?, ?, ?,
            ?, ?, ?, ?,
            ?, ?
        );
        """

        let statement = try database.prepareStatement(sql)
        defer { sqlite3_finalize(statement) }

        bindText(session.id.uuidString, statement: statement, index: 1)
        bindText(projectID.uuidString, statement: statement, index: 2)
        bindText(session.type.rawValue, statement: statement, index: 3)
        sqlite3_bind_double(statement, 4, session.date.timeIntervalSince1970)
        sqlite3_bind_double(statement, 5, Date().timeIntervalSince1970)
        bindOptionalDouble(session.auditionDueDateOverride?.timeIntervalSince1970, statement: statement, index: 6)
        bindOptionalInt(session.sceneCountOverride, statement: statement, index: 7)
        bindOptionalText(session.submittedHeadshotIDOverride?.uuidString, statement: statement, index: 8)
        bindOptionalText(encodeJSON(session.slateSelectionsOverride), statement: statement, index: 9)
        bindOptionalText(session.roleName, statement: statement, index: 10)
        bindOptionalText(session.notes, statement: statement, index: 11)
        bindOptionalText(session.callbackNotes, statement: statement, index: 12)
        bindOptionalText(session.parkingInfo, statement: statement, index: 13)
        sqlite3_bind_int(statement, 14, session.isArchived ? 1 : 0)
        sqlite3_bind_int(statement, 15, session.isFavorite ? 1 : 0)
        bindOptionalText(session.primaryOrientation?.rawValue, statement: statement, index: 16)
        if let smartFillEnabled = session.smartFillEnabled {
            sqlite3_bind_int(statement, 17, smartFillEnabled ? 1 : 0)
        } else {
            sqlite3_bind_null(statement, 17)
        }
        bindOptionalText(session.slatePrompt, statement: statement, index: 18)
        bindOptionalText(session.slatePromptMode.rawValue, statement: statement, index: 19)
        bindOptionalText(session.slatePromptOverride, statement: statement, index: 20)
        bindOptionalText(session.slatePromptInputsHash, statement: statement, index: 21)
        bindOptionalDouble(session.slatePromptUpdatedAt?.timeIntervalSince1970, statement: statement, index: 22)
        bindOptionalText(session.lastCustomSlatePrompt, statement: statement, index: 23)
        bindOptionalText(session.sidesFileName, statement: statement, index: 24)
        bindOptionalText(session.breakdownFileName, statement: statement, index: 25)
        bindOptionalText(session.breakdownNotes, statement: statement, index: 26)
        bindOptionalText(encodeJSON(session.location), statement: statement, index: 27)
        bindOptionalText(encodeJSON(session.contact), statement: statement, index: 28)
        bindOptionalText(encodeJSON(session.pipSlateSession), statement: statement, index: 29)
        bindOptionalText(encodeJSON(session.inPersonAddress), statement: statement, index: 30)
        bindOptionalText(session.inPersonAddressRawPaste, statement: statement, index: 31)
        bindOptionalText(session.castingPhone, statement: statement, index: 32)
        bindOptionalText(session.repPhone, statement: statement, index: 33)
        bindOptionalText(encodeJSON(session.auditionChecklist), statement: statement, index: 34)
        bindOptionalText(encodeJSON(session.unlockedBadges), statement: statement, index: 35)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteDatabaseError.execute(message: "Failed to insert session")
        }

        // Insert takes & markers
        for take in session.takes {
            try insertTake(take, sessionID: session.id, projectID: projectID)
        }
    }

    private func insertTake(_ take: ProjectTake, sessionID: UUID, projectID: UUID) throws {
        let sql = """
        INSERT INTO takes (
            id, session_id, project_id,
            file_path, thumbnail_path,
            duration_seconds, created_at,
            scene_number, take_number, slate_number, slate_id,
            take_notes, rating, take_type, submitted_at,
            captured_orientation, override_smart_fill,
            smart_filled_file_path, edited_file_path,
            export_metadata_json, exported_from_take_ids_json,
            edit_metadata_json, smart_fill_settings_json,
            pip_slate_metadata_json, last_export_date
        ) VALUES (
            ?, ?, ?,
            ?, ?,
            ?, ?,
            ?, ?, ?, ?,
            ?, ?, ?, ?,
            ?, ?,
            ?, ?,
            ?, ?,
            ?, ?,
            ?, ?
        );
        """

        let stmt = try database.prepareStatement(sql)
        defer { sqlite3_finalize(stmt) }

        bindText(take.id.uuidString, statement: stmt, index: 1)
        bindText(sessionID.uuidString, statement: stmt, index: 2)
        bindText(projectID.uuidString, statement: stmt, index: 3)
        bindText(take.filePath, statement: stmt, index: 4)
        bindOptionalText(take.thumbnailPath, statement: stmt, index: 5)
        sqlite3_bind_double(stmt, 6, take.durationSeconds)
        sqlite3_bind_double(stmt, 7, take.createdAt.timeIntervalSince1970)
        sqlite3_bind_int(stmt, 8, Int32(take.sceneNumber))
        sqlite3_bind_int(stmt, 9, Int32(take.takeNumber))
        bindOptionalText(take.slateNumber, statement: stmt, index: 10)
        bindOptionalText(take.slateID, statement: stmt, index: 11)
        bindOptionalText(take.takeNotes, statement: stmt, index: 12)
        bindText(take.rating.rawValue, statement: stmt, index: 13)
        bindText(take.takeType.rawValue, statement: stmt, index: 14)
        bindDate(stmt, index: 15, date: take.submittedAt)
        bindOptionalText(take.capturedOrientation?.rawValue, statement: stmt, index: 16)
        bindOptionalText(take.overrideSmartFill?.rawValue, statement: stmt, index: 17)
        bindOptionalText(take.smartFilledFilePath, statement: stmt, index: 18)
        bindOptionalText(take.editedFilePath, statement: stmt, index: 19)
        bindOptionalText(encodeJSON(take.exportMetadata), statement: stmt, index: 20)
        bindOptionalText(encodeJSON(take.exportedFromTakeIDs), statement: stmt, index: 21)
        bindOptionalText(encodeJSON(take.editMetadata), statement: stmt, index: 22)
        bindOptionalText(encodeJSON(take.smartFillSettings), statement: stmt, index: 23)
        bindOptionalText(encodeJSON(take.pipSlateMetadata), statement: stmt, index: 24)
        bindDate(stmt, index: 25, date: take.lastExportDate)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SQLiteDatabaseError.execute(message: "Failed to insert take")
        }

    }

    // MARK: - Fetch helpers

    private func fetchRoles(projectID: UUID) throws -> [Role] {
        var roles: [Role] = []
        let sql = "SELECT id, name FROM roles WHERE project_id = ?;"
        let stmt = try database.prepareStatement(sql)
        defer { sqlite3_finalize(stmt) }
        bindText(projectID.uuidString, statement: stmt, index: 1)
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let idString = SQLiteValue.string(stmt, index: 0),
               let id = UUID(uuidString: idString),
               let name = SQLiteValue.string(stmt, index: 1) {
                roles.append(Role(id: id, name: name))
            }
        }
        return roles
    }

    private func fetchSessions(projectID: UUID) throws -> [ProjectSession] {
        var sessions: [ProjectSession] = []
        let sql = """
        SELECT id, type, date,
               audition_due_date_override, scene_count_override, submitted_headshot_id_override, slate_selections_override_json,
               role_name, notes, callback_notes, parking_info,
               is_archived, is_favorite, primary_orientation, smart_fill_enabled,
               slate_prompt, slate_prompt_mode, slate_prompt_override, slate_prompt_inputs_hash, slate_prompt_updated_at, last_custom_slate_prompt,
               sides_file_name, breakdown_file_name, breakdown_notes,
               location_json, contact_json, pip_slate_session_json,
               in_person_address_json, in_person_address_raw_paste, casting_phone, rep_phone,
               checklist_progress_json, unlocked_badges_json
        FROM sessions
        WHERE project_id = ?
        ORDER BY date DESC;
        """

        let stmt = try database.prepareStatement(sql)
        defer { sqlite3_finalize(stmt) }
        bindText(projectID.uuidString, statement: stmt, index: 1)

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard
                let idString = SQLiteValue.string(stmt, index: 0),
                let sessionID = UUID(uuidString: idString),
                let typeString = SQLiteValue.string(stmt, index: 1),
                let type = SessionType(rawValue: typeString)
            else { continue }

            let date = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))

            let auditionDueOverride: Date?
            if sqlite3_column_type(stmt, 3) == SQLITE_NULL {
                auditionDueOverride = nil
            } else {
                auditionDueOverride = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
            }
            let sceneCountOverride: Int?
            if sqlite3_column_type(stmt, 4) == SQLITE_NULL {
                sceneCountOverride = nil
            } else {
                sceneCountOverride = Int(sqlite3_column_int(stmt, 4))
            }
            let submittedHeadshotIDOverride = SQLiteValue.string(stmt, index: 5).flatMap(UUID.init(uuidString:))
            let slateSelectionsOverride: SlateSelections? = decodeJSON(SQLiteValue.string(stmt, index: 6))

            let roleName = SQLiteValue.string(stmt, index: 7)
            let notes = SQLiteValue.string(stmt, index: 8)
            let callbackNotes = SQLiteValue.string(stmt, index: 9)
            let parkingInfo = SQLiteValue.string(stmt, index: 10)
            let isArchived = SQLiteValue.bool(stmt, index: 11)
            let isFavorite = SQLiteValue.bool(stmt, index: 12)
            let primaryOrientation = SQLiteValue.string(stmt, index: 13).flatMap(VideoOrientation.init(rawValue:))
            let smartFillEnabled: Bool?
            if sqlite3_column_type(stmt, 14) == SQLITE_NULL {
                smartFillEnabled = nil
            } else {
                smartFillEnabled = sqlite3_column_int(stmt, 14) != 0
            }
            let slatePrompt = SQLiteValue.string(stmt, index: 15)
            let slatePromptMode = SQLiteValue.string(stmt, index: 16)
                .flatMap(SlatePromptMode.init(rawValue:)) ?? .auto
            let slatePromptOverride = SQLiteValue.string(stmt, index: 17)
            let slatePromptInputsHash = SQLiteValue.string(stmt, index: 18)
            let slatePromptUpdatedAt: Date?
            if sqlite3_column_type(stmt, 19) == SQLITE_NULL {
                slatePromptUpdatedAt = nil
            } else {
                slatePromptUpdatedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 19))
            }
            let lastCustomSlatePrompt = SQLiteValue.string(stmt, index: 20)
            let sidesFileName = SQLiteValue.string(stmt, index: 21)
            let breakdownFileName = SQLiteValue.string(stmt, index: 22)
            let breakdownNotes = SQLiteValue.string(stmt, index: 23)
            let location: LocationInfo? = decodeJSON(SQLiteValue.string(stmt, index: 24))
            let contact: Contact? = decodeJSON(SQLiteValue.string(stmt, index: 25))
            let pipSlateSession: SlatePIPSession? = decodeJSON(SQLiteValue.string(stmt, index: 26))
            let inPersonAddress: InPersonAddress? = decodeJSON(SQLiteValue.string(stmt, index: 27))
            let inPersonAddressRawPaste = SQLiteValue.string(stmt, index: 28)
            let castingPhone = SQLiteValue.string(stmt, index: 29)
            let repPhone = SQLiteValue.string(stmt, index: 30)
            let checklist: ChecklistProgress? = decodeJSON(SQLiteValue.string(stmt, index: 31))
            let unlockedBadges: [SessionBadge] = decodeJSON(SQLiteValue.string(stmt, index: 32)) ?? []

            let takes = try fetchTakes(sessionID: sessionID, projectID: projectID)

            var session = ProjectSession(
                id: sessionID,
                type: type,
                date: date,
                location: location,
                contact: contact,
                notes: notes,
                takes: takes,
                roleName: roleName,
                callbackNotes: callbackNotes,
                parkingInfo: parkingInfo,
                isFavorite: isFavorite,
                isArchived: isArchived,
                primaryOrientation: primaryOrientation,
                smartFillEnabled: smartFillEnabled,
                slatePrompt: slatePrompt,
                slatePromptMode: slatePromptMode,
                slatePromptOverride: slatePromptOverride,
                slatePromptInputsHash: slatePromptInputsHash,
                slatePromptUpdatedAt: slatePromptUpdatedAt,
                lastCustomSlatePrompt: lastCustomSlatePrompt,
                sidesFileName: sidesFileName,
                breakdownFileName: breakdownFileName,
                breakdownNotes: breakdownNotes,
                pipSlateSession: pipSlateSession
            )
            session.auditionChecklist = checklist
            session.unlockedBadges = unlockedBadges
            session.auditionDueDateOverride = auditionDueOverride
            session.sceneCountOverride = sceneCountOverride
            session.submittedHeadshotIDOverride = submittedHeadshotIDOverride
            session.slateSelectionsOverride = slateSelectionsOverride
            session.inPersonAddress = inPersonAddress
            session.inPersonAddressRawPaste = inPersonAddressRawPaste
            session.castingPhone = castingPhone
            session.repPhone = repPhone
            sessions.append(session)
        }

        return sessions
    }

    private func fetchTakes(sessionID: UUID, projectID: UUID) throws -> [ProjectTake] {
        var takes: [ProjectTake] = []
        let sql = """
        SELECT
            id, file_path, thumbnail_path,
            duration_seconds, created_at,
            scene_number, take_number, slate_number, slate_id,
            take_notes, rating, take_type, submitted_at,
            captured_orientation, override_smart_fill,
            smart_filled_file_path, edited_file_path,
            export_metadata_json, exported_from_take_ids_json,
            edit_metadata_json, smart_fill_settings_json,
            pip_slate_metadata_json, last_export_date
        FROM takes
        WHERE session_id = ?
        ORDER BY created_at ASC;
        """

        let stmt = try database.prepareStatement(sql)
        defer { sqlite3_finalize(stmt) }
        bindText(sessionID.uuidString, statement: stmt, index: 1)

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard
                let idString = SQLiteValue.string(stmt, index: 0),
                let takeID = UUID(uuidString: idString),
                let filePath = SQLiteValue.string(stmt, index: 1),
                let ratingRaw = SQLiteValue.string(stmt, index: 10),
                let rating = TakeRating(rawValue: ratingRaw),
                let takeTypeRaw = SQLiteValue.string(stmt, index: 11),
                let takeType = TakeType(rawValue: takeTypeRaw)
            else { continue }

            let thumbnailPath = SQLiteValue.string(stmt, index: 2)
            let duration = sqlite3_column_double(stmt, 3)
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
            let sceneNumber = Int(sqlite3_column_int(stmt, 5))
            let takeNumber = Int(sqlite3_column_int(stmt, 6))
            let slateNumber = SQLiteValue.string(stmt, index: 7)
            let slateID = SQLiteValue.string(stmt, index: 8)
            let takeNotes = SQLiteValue.string(stmt, index: 9)
            let submittedAt = ProjectsStoreSQLite.dateValue(stmt, index: 12)
            let capturedOrientation = SQLiteValue.string(stmt, index: 13).flatMap(VideoOrientation.init(rawValue:))
            let overrideSmartFill = SQLiteValue.string(stmt, index: 14).flatMap(TriState.init(rawValue:))
            let smartFilledFilePath = SQLiteValue.string(stmt, index: 15)
            let editedFilePath = SQLiteValue.string(stmt, index: 16)
            let exportMetadata: ExportMetadata? = decodeJSON(SQLiteValue.string(stmt, index: 17))
            let exportedIDs: [UUID] = decodeJSON(SQLiteValue.string(stmt, index: 18)) ?? []
            let editMetadata: TakeEditMetadata? = decodeJSON(SQLiteValue.string(stmt, index: 19))
            let smartFillSettings: SmartFillSettingsSnapshot? = decodeJSON(SQLiteValue.string(stmt, index: 20))
            let pipSlateMetadata: PIPSlateCompositeMetadata? = decodeJSON(SQLiteValue.string(stmt, index: 21))
            let lastExportDate = ProjectsStoreSQLite.dateValue(stmt, index: 22)
            let markers: [TakeVideoMarker] = []

            let take = ProjectTake(
                id: takeID,
                filePath: filePath,
                durationSeconds: duration,
                thumbnailPath: thumbnailPath,
                takeNotes: takeNotes,
                createdAt: createdAt,
                videoMarkers: markers,
                rating: rating,
                sceneNumber: sceneNumber,
                takeNumber: takeNumber,
                slateNumber: slateNumber,
                slateID: slateID,
                capturedOrientation: capturedOrientation,
                overrideSmartFill: overrideSmartFill,
                smartFilledFilePath: smartFilledFilePath,
                editedFilePath: editedFilePath,
                exportMetadata: exportMetadata,
                exportedFromTakeIDs: exportedIDs,
                lastExportDate: lastExportDate,
                submittedAt: submittedAt,
                takeType: takeType,
                editMetadata: editMetadata,
                smartFillSettings: smartFillSettings,
                pipSlateMetadata: pipSlateMetadata
            )

            takes.append(take)
        }

        return takes
    }

    // MARK: - Helpers

    private func encodeJSON<T: Encodable>(_ value: T?) -> String? {
        guard let value else { return nil }
        do {
            let data = try encoder.encode(value)
            return String(data: data, encoding: .utf8)
        } catch {
            print("SQLite encode error: \(error)")
            return nil
        }
    }

    private func decodeJSON<T: Decodable>(_ string: String?) -> T? {
        guard let string, let data = string.data(using: .utf8) else { return nil }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("SQLite decode error: \(error)")
            return nil
        }
    }

    private func bindDate(_ stmt: OpaquePointer, index: Int32, date: Date?) {
        if let date {
            sqlite3_bind_double(stmt, index, date.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    static func dateValue(_ stmt: OpaquePointer, index: Int32) -> Date? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
        return Date(timeIntervalSince1970: sqlite3_column_double(stmt, index))
    }

    private func bindText(_ value: String, statement: OpaquePointer, index: Int32) {
        _ = value.withCString { pointer in
            sqlite3_bind_text(statement, index, pointer, -1, SQLITE_TRANSIENT)
        }
    }

    private func bindOptionalText(_ value: String?, statement: OpaquePointer, index: Int32) {
        if let value {
            bindText(value, statement: statement, index: index)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func bindOptionalDouble(_ value: Double?, statement: OpaquePointer, index: Int32) {
        if let value {
            sqlite3_bind_double(statement, index, value)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func bindOptionalInt(_ value: Int?, statement: OpaquePointer, index: Int32) {
        if let value {
            sqlite3_bind_int(statement, index, Int32(value))
        } else {
            sqlite3_bind_null(statement, index)
        }
    }
}

// MARK: - Value helpers

private enum SQLiteValue {
    static func string(_ stmt: OpaquePointer, index: Int32) -> String? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
        guard let cString = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cString)
    }

    static func bool(_ stmt: OpaquePointer, index: Int32) -> Bool {
        sqlite3_column_int(stmt, index) != 0
    }
}

// MARK: - Row representations

private struct ProjectRow {
    let id: UUID
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let castingOffice: String?
    let castingDirector: Contact?
    let representation: Contact?
    let ccContacts: [Contact]
    let bccContacts: [Contact]
    let isFavorite: Bool
    let isArchived: Bool
    let isCompleted: Bool
    let sceneCount: Int
    let auditionDueDate: Date?
    let shootDate: Date?
    let projectType: String
    let genre: String
    let sidesFileName: String?
    let breakdownFileName: String?
    let submittedHeadshotID: UUID?
    let breakdownNotes: String?
    let slateSelections: SlateSelections
    let payDealTagsRaw: String?
    let payRateText: String?
    let payCraftVsMoney: Double?
    let payUnionStatusRaw: String?
    let payRoleTypeRaw: String?

    init(statement: OpaquePointer, decoder: JSONDecoder) throws {
        guard
            let idString = SQLiteValue.string(statement, index: 0),
            let id = UUID(uuidString: idString),
            let title = SQLiteValue.string(statement, index: 1)
        else {
            throw SQLiteDatabaseError.execute(message: "Invalid project row")
        }
        self.id = id
        self.title = title
        self.createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
        self.updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
        self.castingOffice = SQLiteValue.string(statement, index: 4)
        self.castingDirector = ProjectRow.decode(Contact.self, statement: statement, index: 5, decoder: decoder)
        self.representation = ProjectRow.decode(Contact.self, statement: statement, index: 6, decoder: decoder)
        self.ccContacts = ProjectRow.decode([Contact].self, statement: statement, index: 7, decoder: decoder) ?? []
        self.bccContacts = ProjectRow.decode([Contact].self, statement: statement, index: 8, decoder: decoder) ?? []
        self.isFavorite = SQLiteValue.bool(statement, index: 9)
        self.isArchived = SQLiteValue.bool(statement, index: 10)
        self.isCompleted = SQLiteValue.bool(statement, index: 11)
        self.sceneCount = Int(sqlite3_column_int(statement, 12))
        self.auditionDueDate = ProjectsStoreSQLite.dateValue(statement, index: 13)
        self.shootDate = ProjectsStoreSQLite.dateValue(statement, index: 14)
        self.projectType = SQLiteValue.string(statement, index: 15) ?? "Feature"
        self.genre = SQLiteValue.string(statement, index: 16) ?? ""
        self.sidesFileName = SQLiteValue.string(statement, index: 17)
        self.breakdownFileName = SQLiteValue.string(statement, index: 18)
        if let headshot = SQLiteValue.string(statement, index: 19) {
            self.submittedHeadshotID = UUID(uuidString: headshot)
        } else {
            self.submittedHeadshotID = nil
        }
        self.breakdownNotes = SQLiteValue.string(statement, index: 20)
        self.slateSelections = ProjectRow.decode(SlateSelections.self, statement: statement, index: 21, decoder: decoder) ?? SlateSelections()
        self.payDealTagsRaw = SQLiteValue.string(statement, index: 22)
        self.payRateText = SQLiteValue.string(statement, index: 23)
        self.payCraftVsMoney = sqlite3_column_type(statement, 24) == SQLITE_NULL ? nil : sqlite3_column_double(statement, 24)
        self.payUnionStatusRaw = SQLiteValue.string(statement, index: 25)
        self.payRoleTypeRaw = SQLiteValue.string(statement, index: 26)
    }

    func makeProject(roles: [Role], sessions: [ProjectSession]) -> Project {
        let project = Project(
            id: id,
            title: title,
            roles: roles,
            sessions: sessions,
            createdAt: createdAt,
            castingOffice: castingOffice,
            castingDirector: castingDirector,
            representation: representation,
            ccContacts: ccContacts,
            bccContacts: bccContacts,
            isFavorite: isFavorite,
            isArchived: isArchived,
            isCompleted: isCompleted,
            sceneCount: sceneCount,
            auditionDueDate: auditionDueDate,
            shootDate: shootDate,
            projectType: projectType,
            genre: genre,
            slateSelections: slateSelections,
            breakdownNotes: breakdownNotes,
            sidesFileName: sidesFileName,
            breakdownFileName: breakdownFileName,
            submittedHeadshotID: submittedHeadshotID,
            payDealTagsRaw: payDealTagsRaw,
            payRateText: payRateText,
            payCraftVsMoney: payCraftVsMoney,
            payUnionStatusRaw: payUnionStatusRaw,
            payRoleTypeRaw: payRoleTypeRaw
        )
        return project
    }

    private static func decode<T: Decodable>(_ type: T.Type = T.self, statement: OpaquePointer, index: Int32, decoder: JSONDecoder) -> T? {
        guard let string = SQLiteValue.string(statement, index: index), let data = string.data(using: .utf8) else {
            return nil
        }
        return try? decoder.decode(T.self, from: data)
    }
}
