import XCTest
import GRDB

struct PersistablePerson : DatabasePersistable {
    var name: String?
    
    static func databaseTableName() -> String {
        return "persons"
    }
    
    var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["name": name]
    }
}

struct PersistableCountry : DatabasePersistable {
    var isoCode: String
    var name: String
    
    static func databaseTableName() -> String {
        return "countries"
    }
    
    var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["isoCode": isoCode, "name": name]
    }
}

struct PersistableCustomizedCountry : DatabasePersistable {
    var isoCode: String
    var name: String
    let willInsert: Void -> Void
    let willUpdate: Void -> Void
    let willSave: Void -> Void
    let willDelete: Void -> Void
    let willExists: Void -> Void
    
    static func databaseTableName() -> String {
        return "countries"
    }
    
    var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["isoCode": isoCode, "name": name]
    }
    
    func insert(db: Database) throws {
        willInsert()
        try performInsert(db)
    }
    
    func update(db: Database) throws {
        willUpdate()
        try performUpdate(db)
    }
    
    func save(db: Database) throws {
        willSave()
        try performSave(db)
    }
    
    func delete(db: Database) throws {
        willDelete()
        try performDelete(db)
    }
    
    func exists(db: Database) -> Bool {
        willExists()
        return performExists(db)
    }
}

class DatabasePersistableTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("setUp") { db in
            try db.execute(
                "CREATE TABLE persons (" +
                    "id INTEGER PRIMARY KEY, " +
                    "name NOT NULL " +
                ")")
            try db.execute(
                "CREATE TABLE countries (" +
                    "isoCode TEXT NOT NULL PRIMARY KEY, " +
                    "name TEXT NOT NULL " +
                ")")
        }
        
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    func testInsertPersistablePerson() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = PersistablePerson(name: "Arthur")
                try person.insert(db)
                
                let rows = Row.fetchAll(db, "SELECT * FROM persons")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
            }
        }
    }
    
    func testSavePersistablePerson() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = PersistablePerson(name: "Arthur")
                try person.save(db)
                
                let rows = Row.fetchAll(db, "SELECT * FROM persons")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
            }
        }
    }
    
    func testInsertPersistableCountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let country = PersistableCountry(isoCode: "FR", name: "France")
                try country.insert(db)
                
                let rows = Row.fetchAll(db, "SELECT * FROM countries")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
                XCTAssertEqual(rows[0].value(named: "name") as String, "France")
            }
        }
    }
    
    func testUpdatePersistableCountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var country1 = PersistableCountry(isoCode: "FR", name: "France")
                try country1.insert(db)
                let country2 = PersistableCountry(isoCode: "US", name: "United States")
                try country2.insert(db)
                
                country1.name = "France Métropolitaine"
                try country1.update(db)
                
                let rows = Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
                XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
                XCTAssertEqual(rows[1].value(named: "isoCode") as String, "US")
                XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
            }
        }
    }
    
    func testSavePersistableCountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var country1 = PersistableCountry(isoCode: "FR", name: "France")
                try country1.save(db)
                
                var rows = Row.fetchAll(db, "SELECT * FROM countries")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
                XCTAssertEqual(rows[0].value(named: "name") as String, "France")
                
                let country2 = PersistableCountry(isoCode: "US", name: "United States")
                try country2.save(db)
                
                country1.name = "France Métropolitaine"
                try country1.save(db)
                
                rows = Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
                XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
                XCTAssertEqual(rows[1].value(named: "isoCode") as String, "US")
                XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
                
                try country1.delete(db)
                try country1.save(db)
                
                rows = Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
                XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
                XCTAssertEqual(rows[1].value(named: "isoCode") as String, "US")
                XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
            }
        }
    }
    
    func testDeletePersistableCountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let country1 = PersistableCountry(isoCode: "FR", name: "France")
                try country1.insert(db)
                let country2 = PersistableCountry(isoCode: "US", name: "United States")
                try country2.insert(db)
                
                try country1.delete(db)
                
                let rows = Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "isoCode") as String, "US")
                XCTAssertEqual(rows[0].value(named: "name") as String, "United States")
            }
        }
    }
    
    func testExistsPersistableCountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let country = PersistableCountry(isoCode: "FR", name: "France")
                try country.insert(db)
                XCTAssertTrue(country.exists(db))
                
                try country.delete(db)
                
                XCTAssertFalse(country.exists(db))
            }
        }
    }
    
    func testInsertPersistableCustomizedCountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var insertCount: Int = 0
                var updateCount: Int = 0
                var saveCount: Int = 0
                var deleteCount: Int = 0
                var existsCount: Int = 0
                let country = PersistableCustomizedCountry(
                    isoCode: "FR",
                    name: "France",
                    willInsert: { insertCount += 1 },
                    willUpdate: { updateCount += 1 },
                    willSave: { saveCount += 1 },
                    willDelete: { deleteCount += 1 },
                    willExists: { existsCount += 1 })
                try country.insert(db)
                
                XCTAssertEqual(insertCount, 1)
                XCTAssertEqual(updateCount, 0)
                XCTAssertEqual(saveCount, 0)
                XCTAssertEqual(deleteCount, 0)
                XCTAssertEqual(existsCount, 0)
                
                let rows = Row.fetchAll(db, "SELECT * FROM countries")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
                XCTAssertEqual(rows[0].value(named: "name") as String, "France")
            }
        }
    }
    
    func testUpdatePersistableCustomizedCountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var insertCount: Int = 0
                var updateCount: Int = 0
                var saveCount: Int = 0
                var deleteCount: Int = 0
                var existsCount: Int = 0
                var country1 = PersistableCustomizedCountry(
                    isoCode: "FR",
                    name: "France",
                    willInsert: { insertCount += 1 },
                    willUpdate: { updateCount += 1 },
                    willSave: { saveCount += 1 },
                    willDelete: { deleteCount += 1 },
                    willExists: { existsCount += 1 })
                try country1.insert(db)
                let country2 = PersistableCustomizedCountry(
                    isoCode: "US",
                    name: "United States",
                    willInsert: { },
                    willUpdate: { },
                    willSave: { },
                    willDelete: { },
                    willExists: { })
                try country2.insert(db)
                
                country1.name = "France Métropolitaine"
                try country1.update(db)
                
                XCTAssertEqual(insertCount, 1)
                XCTAssertEqual(updateCount, 1)
                XCTAssertEqual(saveCount, 0)
                XCTAssertEqual(deleteCount, 0)
                XCTAssertEqual(existsCount, 0)
                
                let rows = Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
                XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
                XCTAssertEqual(rows[1].value(named: "isoCode") as String, "US")
                XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
            }
        }
    }
    
    func testSavePersistableCustomizedCountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var insertCount: Int = 0
                var updateCount: Int = 0
                var saveCount: Int = 0
                var deleteCount: Int = 0
                var existsCount: Int = 0
                var country1 = PersistableCustomizedCountry(
                    isoCode: "FR",
                    name: "France",
                    willInsert: { insertCount += 1 },
                    willUpdate: { updateCount += 1 },
                    willSave: { saveCount += 1 },
                    willDelete: { deleteCount += 1 },
                    willExists: { existsCount += 1 })
                try country1.save(db)
                
                XCTAssertEqual(insertCount, 1)
                XCTAssertEqual(updateCount, 1)
                XCTAssertEqual(saveCount, 1)
                XCTAssertEqual(deleteCount, 0)
                XCTAssertEqual(existsCount, 0)
                
                var rows = Row.fetchAll(db, "SELECT * FROM countries")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
                XCTAssertEqual(rows[0].value(named: "name") as String, "France")
                
                let country2 = PersistableCustomizedCountry(
                    isoCode: "US",
                    name: "United States",
                    willInsert: { },
                    willUpdate: { },
                    willSave: { },
                    willDelete: { },
                    willExists: { })
                try country2.save(db)
                
                country1.name = "France Métropolitaine"
                try country1.save(db)
                
                XCTAssertEqual(insertCount, 1)
                XCTAssertEqual(updateCount, 2)
                XCTAssertEqual(saveCount, 2)
                XCTAssertEqual(deleteCount, 0)
                XCTAssertEqual(existsCount, 0)
                
                rows = Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
                XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
                XCTAssertEqual(rows[1].value(named: "isoCode") as String, "US")
                XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
                
                try country1.delete(db)
                try country1.save(db)
                
                XCTAssertEqual(insertCount, 2)
                XCTAssertEqual(updateCount, 3)
                XCTAssertEqual(saveCount, 3)
                XCTAssertEqual(deleteCount, 1)
                XCTAssertEqual(existsCount, 0)
                
                rows = Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
                XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
                XCTAssertEqual(rows[1].value(named: "isoCode") as String, "US")
                XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
            }
        }
    }
    
    func testDeletePersistableCustomizedCountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var insertCount: Int = 0
                var updateCount: Int = 0
                var saveCount: Int = 0
                var deleteCount: Int = 0
                var existsCount: Int = 0
                let country1 = PersistableCustomizedCountry(
                    isoCode: "FR",
                    name: "France",
                    willInsert: { insertCount += 1 },
                    willUpdate: { updateCount += 1 },
                    willSave: { saveCount += 1 },
                    willDelete: { deleteCount += 1 },
                    willExists: { existsCount += 1 })
                try country1.insert(db)
                let country2 = PersistableCustomizedCountry(
                    isoCode: "US",
                    name: "United States",
                    willInsert: { },
                    willUpdate: { },
                    willSave: { },
                    willDelete: { },
                    willExists: { })
                try country2.insert(db)
                
                try country1.delete(db)
                
                XCTAssertEqual(insertCount, 1)
                XCTAssertEqual(updateCount, 0)
                XCTAssertEqual(saveCount, 0)
                XCTAssertEqual(deleteCount, 1)
                XCTAssertEqual(existsCount, 0)
                
                let rows = Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "isoCode") as String, "US")
                XCTAssertEqual(rows[0].value(named: "name") as String, "United States")
            }
        }
    }
    
    func testExistsPersistableCustomizedCountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var insertCount: Int = 0
                var updateCount: Int = 0
                var saveCount: Int = 0
                var deleteCount: Int = 0
                var existsCount: Int = 0
                let country = PersistableCustomizedCountry(
                    isoCode: "FR",
                    name: "France",
                    willInsert: { insertCount += 1 },
                    willUpdate: { updateCount += 1 },
                    willSave: { saveCount += 1 },
                    willDelete: { deleteCount += 1 },
                    willExists: { existsCount += 1 })
                try country.insert(db)
                XCTAssertTrue(country.exists(db))
                
                XCTAssertEqual(insertCount, 1)
                XCTAssertEqual(updateCount, 0)
                XCTAssertEqual(saveCount, 0)
                XCTAssertEqual(deleteCount, 0)
                XCTAssertEqual(existsCount, 1)
                
                try country.delete(db)
                
                XCTAssertFalse(country.exists(db))
                XCTAssertEqual(insertCount, 1)
                XCTAssertEqual(updateCount, 0)
                XCTAssertEqual(saveCount, 0)
                XCTAssertEqual(deleteCount, 1)
                XCTAssertEqual(existsCount, 2)
            }
        }
    }
}