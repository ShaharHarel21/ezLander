#!/usr/bin/env bash
#
# capture.sh - Capture a screenshot of the EzLander app window.
#
# Usage: ./capture.sh <output-path>
#
# Strategy:
#   1. Use Swift/CoreGraphics to find the EzLander window ID and capture with screencapture -l
#   2. Fall back to osascript bounds detection with screencapture -R
#   3. Final fallback: capture the entire screen
#

set -euo pipefail

OUTPUT="${1:-./screenshots/latest.png}"
OUTPUT_DIR="$(dirname "$OUTPUT")"
mkdir -p "$OUTPUT_DIR"

APP_NAME="EzLander"

# ---------------------------------------------------------------------------
# Approach 1: Use Swift to find window ID via CGWindowList
# ---------------------------------------------------------------------------
get_window_id() {
  swift -e '
import CoreGraphics
import Foundation

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

// First pass: look for the "ezLander Preview" titled window (preview mode)
for w in windows {
    let owner = w[kCGWindowOwnerName as String] as? String ?? ""
    let name = w[kCGWindowName as String] as? String ?? ""
    if owner == "EzLander" && name.contains("Preview") {
        if let id = w[kCGWindowNumber as String] as? Int {
            print(id)
            exit(0)
        }
    }
}

// Second pass: any EzLander window at layer 0 (normal windows)
for w in windows {
    let owner = w[kCGWindowOwnerName as String] as? String ?? ""
    let layer = w[kCGWindowLayer as String] as? Int ?? -1
    if owner == "EzLander" && layer == 0 {
        if let id = w[kCGWindowNumber as String] as? Int {
            print(id)
            exit(0)
        }
    }
}

// Third pass: any EzLander window
for w in windows {
    let owner = w[kCGWindowOwnerName as String] as? String ?? ""
    if owner == "EzLander" {
        if let id = w[kCGWindowNumber as String] as? Int {
            print(id)
            exit(0)
        }
    }
}

exit(1)
' 2>/dev/null
}

# ---------------------------------------------------------------------------
# Approach 2: Use Swift to get window bounds
# ---------------------------------------------------------------------------
get_window_bounds() {
  swift -e '
import CoreGraphics
import Foundation

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

for w in windows {
    let owner = w[kCGWindowOwnerName as String] as? String ?? ""
    if owner == "EzLander" {
        if let bounds = w[kCGWindowBounds as String] as? [String: Any],
           let x = bounds["X"] as? Int,
           let y = bounds["Y"] as? Int,
           let width = bounds["Width"] as? Int,
           let height = bounds["Height"] as? Int,
           width > 50 && height > 50 {
            print("\(x),\(y),\(width),\(height)")
            exit(0)
        }
    }
}

exit(1)
' 2>/dev/null
}

# ---------------------------------------------------------------------------
# Try Approach 1: screencapture -l <windowID>
# ---------------------------------------------------------------------------
WINDOW_ID=$(get_window_id 2>/dev/null || true)

if [[ -n "$WINDOW_ID" ]]; then
  screencapture -l "$WINDOW_ID" -x -o "$OUTPUT" 2>/dev/null
  if [[ -f "$OUTPUT" ]]; then
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Try Approach 2: screencapture -R x,y,w,h
# ---------------------------------------------------------------------------
BOUNDS=$(get_window_bounds 2>/dev/null || true)

if [[ -n "$BOUNDS" ]]; then
  screencapture -R "$BOUNDS" -x -o "$OUTPUT" 2>/dev/null
  if [[ -f "$OUTPUT" ]]; then
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Approach 3: Use osascript to get window position via System Events
# ---------------------------------------------------------------------------
OSASCRIPT_BOUNDS=$(osascript -e "
  tell application \"System Events\"
    if exists process \"${APP_NAME}\" then
      tell process \"${APP_NAME}\"
        if (count of windows) > 0 then
          set win to first window
          set {x, y} to position of win
          set {w, h} to size of win
          return (x as text) & \",\" & (y as text) & \",\" & (w as text) & \",\" & (h as text)
        end if
      end tell
    end if
  end tell
  return \"\"
" 2>/dev/null || true)

if [[ -n "$OSASCRIPT_BOUNDS" && "$OSASCRIPT_BOUNDS" != "" ]]; then
  screencapture -R "$OSASCRIPT_BOUNDS" -x -o "$OUTPUT" 2>/dev/null
  if [[ -f "$OUTPUT" ]]; then
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Final fallback: full-screen capture
# ---------------------------------------------------------------------------
echo "Warning: Could not find EzLander window. Capturing full screen." >&2
screencapture -x -o "$OUTPUT" 2>/dev/null

exit 0
