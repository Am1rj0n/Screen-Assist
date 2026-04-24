import Foundation
import CoreGraphics

let args = CommandLine.arguments

if args.contains("--help") || args.count < 2 {
    printUsage()
    exit(0)
}

let command = args[1]

switch command {
case "capture":
    await runCapture()
case "key":
    handleKey(args: Array(args.dropFirst(2)))
default:
    print("Unknown command: \(command)")
    printUsage()
    exit(1)
}

func printUsage() {
    print("""
    TerminalAssist (TA) - ScreenAssist CLI Tool
    
    Usage:
      TA capture [prompt]   Capture screen and analyze
      TA key set <key>      Set API key (stored in Keychain)
      TA --help             Show this help
    """)
}

func runCapture() async {
    print("🚀 Starting capture...")
    print("Note: In a full implementation, this would call the Core modules.")
}

func handleKey(args: [String]) {
    print("🔑 Handling key command...")
}
