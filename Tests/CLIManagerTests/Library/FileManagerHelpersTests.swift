import Testing
import Foundation

@testable import cli_manager

/// Uses a class (not a struct) so `deinit` can remove the temporary directory after each test.
/// Swift Testing instantiates a fresh object per test method, giving full isolation.
final class FileManagerHelpersTests {

    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CLIManagerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - isDirectory

    @Test("Returns true for a path that is a directory")
    func isDirectoryReturnsTrueForDirectory() {
        #expect(isDirectory(tempDir) == true)
    }

    @Test("Returns false for a path that is a regular file")
    func isDirectoryReturnsFalseForRegularFile() throws {
        let file = tempDir.appendingPathComponent("file.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)
        #expect(isDirectory(file) == false)
    }

    @Test("Returns false for a path that does not exist on disk")
    func isDirectoryReturnsFalseForNonExistentPath() {
        #expect(isDirectory(tempDir.appendingPathComponent("ghost")) == false)
    }

    // MARK: - isSymlink

    @Test("Returns true for a path that is a symbolic link, regardless of whether the target is a file or directory")
    func isSymlinkReturnsTrueForSymlink() throws {
        let target = tempDir.appendingPathComponent("target.txt")
        let link   = tempDir.appendingPathComponent("link.txt")
        try "content".write(to: target, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        #expect(isSymlink(link) == true)
    }

    @Test("Returns false for a path that is a regular file (not a symlink)")
    func isSymlinkReturnsFalseForRegularFile() throws {
        let file = tempDir.appendingPathComponent("regular.txt")
        try "content".write(to: file, atomically: true, encoding: .utf8)
        #expect(isSymlink(file) == false)
    }

    @Test("Returns false for a path that does not exist on disk")
    func isSymlinkReturnsFalseForNonExistentPath() {
        #expect(isSymlink(tempDir.appendingPathComponent("ghost.txt")) == false)
    }
}
