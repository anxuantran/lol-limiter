// Shows a native macOS alert with a real multi-line text field (an NSTextView
// inside an NSAlert accessory view) — unlike AppleScript's `display dialog`,
// Return inserts a newline here instead of submitting the dialog.
//
// Usage: osascript -l JavaScript override-dialog.js "<passage text>"
// Prints "OVERRIDE:<typed text>" or "CANCELLED" to stdout.

ObjC.import('Cocoa')

function run(argv) {
  var passage = argv[0] || ""

  // Bare `osascript` defaults to NSApplicationActivationPolicyProhibited —
  // a tier that can draw windows but can NEVER become the key/active app,
  // not even from a real click. That's what was actually blocking keyboard
  // input, not focus-stealing prevention. Accessory is the same policy
  // override-countdown.js already uses for the menu bar item, and (unlike
  // Prohibited) it's allowed to become key.
  var app = $.NSApplication.sharedApplication
  app.setActivationPolicy($.NSApplicationActivationPolicyAccessory)

  // Best-effort foregrounding on top of that — may or may not be honored
  // depending on what else has focus, but doesn't hurt.
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
