#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
// @preconcurrency suppresses strict-concurrency errors for C globals (e.g. stdout)
// that predate Swift concurrency. Must appear before Foundation, which transitively
// imports Glibc on Linux and would otherwise trigger the check first.
@preconcurrency import Glibc
#endif
import Foundation

let isTTY = isatty(STDOUT_FILENO) != 0
func c(_ code: String) -> String { isTTY ? "\u{1B}[\(code)m" : "" }

let reset  = c("0");  let bold   = c("1");  let dim    = c("2")
let green  = c("32"); let yellow = c("33"); let red    = c("31")
let cyan   = c("36"); let gray   = c("90"); let blue   = c("34")

func ok(_ message: String) { print("\(green)✓\(reset) \(message)") }
func warn(_ message: String) { print("\(yellow)!\(reset) \(message)") }
func fail(_ message: String) { print("\(red)✗\(reset) \(message)") }
func info(_ message: String) { print("\(blue)i\(reset) \(message)") }
func skip(_ message: String) { print("\(gray)−\(reset) \(message)") }

/// Prompts the user to pick from a numbered list.
/// Falls back to selecting all items when not running in a TTY (e.g. piped input).
func selectInteractive<T>(prompt: String, items: [T], display: (T) -> String) -> [T] {
    guard isTTY else {
        return items
    }

    print("\n\(bold)\(prompt)\(reset)  \(gray)(comma-separated numbers, or enter for all)\(reset)\n")
    for (index, item) in items.enumerated() {
        print("  \(cyan)\(bold)\(index + 1)\(reset)  \(display(item))")
    }
    print()
    print("\(bold)>\(reset) ", terminator: "")
    fflush(stdout)

    let input = (readLine() ?? "").trimmingCharacters(in: .whitespaces)
    guard !input.isEmpty, input.lowercased() != "all" else {
        return items
    }

    let selected = input
        .split(separator: ",")
        .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        .filter { $0 >= 1 && $0 <= items.count }
        .map { items[$0 - 1] }

    return selected.isEmpty ? items : selected
}
