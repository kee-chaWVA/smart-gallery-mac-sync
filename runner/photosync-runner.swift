// Tiny launcher for sync.sh, so Full Disk Access can be granted to this one program
// instead of /bin/bash. launchd runs this; bash and osxphotos inherit its permission.
import Foundation

// This program lives in mac-sync/bin/, and sync.sh is one folder up.
let runnerURL = Bundle.main.executableURL!.resolvingSymlinksInPath()
let syncScript = runnerURL
    .deletingLastPathComponent()  // mac-sync/bin/
    .deletingLastPathComponent()  // mac-sync/
    .appendingPathComponent("sync.sh")

let process = Process()
process.executableURL = URL(fileURLWithPath: "/bin/bash")
process.arguments = [syncScript.path]

do {
    try process.run()
    process.waitUntilExit()
    exit(process.terminationStatus)
} catch {
    let message = "photosync-runner: could not start \(syncScript.path): \(error)\n"
    FileHandle.standardError.write(message.data(using: .utf8)!)
    exit(1)
}
