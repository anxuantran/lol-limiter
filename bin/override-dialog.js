// Shows a native macOS alert with a real multi-line text field (an NSTextView
// inside an NSAlert accessory view) — unlike AppleScript's `display dialog`,
// Return inserts a newline here instead of submitting the dialog.
//
// Usage: osascript -l JavaScript override-dialog.js "<passage text>"
// Prints "OVERRIDE:<typed text>" or "CANCELLED" to stdout.

ObjC.import('Cocoa')

function run(argv) {
  var passage = argv[0] || ""

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
  alert.window.initialFirstResponder = textView

  var response = alert.runModal
  var typed = ObjC.unwrap(textView.string)

  if (response === $.NSAlertFirstButtonReturn) {
    return "OVERRIDE:" + typed
  } else {
    return "CANCELLED"
  }
}
