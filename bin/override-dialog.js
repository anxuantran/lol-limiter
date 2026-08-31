// Shows a native macOS alert with a real multi-line text field (an NSTextView
// inside an NSAlert accessory view) — unlike AppleScript's `display dialog`,
// Return inserts a newline here instead of submitting the dialog.
//
// Usage: osascript -l JavaScript override-dialog.js "<passage text>"
// Prints "OVERRIDE:<typed text>" or "CANCELLED" to stdout.

ObjC.import('Cocoa')

function run(argv) {
  var passage = argv[0] || ""

  // Force to the front — osascript isn't a normal foreground app, so
  // without this the alert can open behind other windows, unnoticed. This
  // is the standard JXA idiom for it (equivalent to AppleScript's
  // `tell me to activate`), not the raw NSRunningApplication/NSApplication
  // calls used before — those left the window frontmost but not key,
  // which is why it couldn't take keyboard focus.
  var se = Application.currentApplication()
  se.includeStandardAdditions = true
  se.activate()

  var alert = $.NSAlert.alloc.init
  alert.messageText = "Type the passage below exactly to unlock one more game"
  alert.informativeText = passage
  alert.addButtonWithTitle("Override")
  alert.addButtonWithTitle("Cancel")

  var scrollView = $.NSScrollView.alloc.initWithFrame($.NSMakeRect(0, 0, 440, 200))
  var textView = $.NSTextView.alloc.initWithFrame($.NSMakeRect(0, 0, 440, 200))
  textView.editable = true
  textView.font = $.NSFont.systemFontOfSize(13)
  // Exact-match text is compared byte-for-byte downstream, so turn off every
  // substitution that could silently swap a typed character for a lookalike.
  textView.automaticQuoteSubstitutionEnabled = false
  textView.automaticDashSubstitutionEnabled = false
  textView.automaticSpellingCorrectionEnabled = false
  textView.automaticTextReplacementEnabled = false
  textView.continuousSpellCheckingEnabled = false
  scrollView.documentView = textView
  scrollView.hasVerticalScroller = true
  scrollView.borderType = $.NSBezelBorder

  alert.accessoryView = scrollView
  // makeFirstResponder is an imperative "focus this now"; the
  // initialFirstResponder property this replaced is only a hint honored
  // when a window becomes key on its own, which doesn't reliably apply to
  // an accessory view wired up after the window already exists.
  alert.window.makeFirstResponder(textView)
  // macOS blocks background-launched processes from stealing keyboard
  // focus from whatever app you're actually using (activate() above is
  // best-effort and can be silently ignored) — that's a deliberate OS
  // security boundary, not something to fight around. What IS guaranteed:
  // a floating window stays visible on top of whatever else is on screen,
  // and a real click from you is always allowed to focus it. So this
  // floats above other windows and waits for you to click into it.
  alert.window.level = $.NSFloatingWindowLevel

  var response = alert.runModal
  var typed = ObjC.unwrap(textView.string)

  if (response === $.NSAlertFirstButtonReturn) {
    return "OVERRIDE:" + typed
  } else {
    return "CANCELLED"
  }
}
