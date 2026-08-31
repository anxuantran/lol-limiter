// A menu bar item that counts down the override wait in real time.
// Purely cosmetic — it computes remaining time from wall-clock (start epoch
// + total seconds) on every tick rather than decrementing a counter, so it
// self-corrects if the Mac sleeps mid-countdown instead of drifting. The
// actual enforcement/unlock timing lives in lol-limiter.sh via state.json;
// this process only ever reads its own argv, never state.json.
//
// Usage: osascript -l JavaScript override-countdown.js <totalSeconds> <startEpoch>

ObjC.import('Cocoa')

function run(argv) {
  var totalSeconds = parseInt(argv[0], 10)
  var startEpoch = parseInt(argv[1], 10)
  if (!totalSeconds || !startEpoch) {
    return
  }

  var app = $.NSApplication.sharedApplication
  app.setActivationPolicy($.NSApplicationActivationPolicyAccessory)

  var statusBar = $.NSStatusBar.systemStatusBar
  var item = statusBar.statusItemWithLength($.NSVariableStatusItemLength)

  function remainingSeconds() {
    var now = Math.floor(Date.now() / 1000)
    return totalSeconds - (now - startEpoch)
  }

  function render(remaining) {
    var m = Math.floor(remaining / 60)
    var s = remaining % 60
    var ss = (s < 10 ? "0" : "") + s
    return "🔓 Override in " + m + ":" + ss
  }

  function tick() {
    var remaining = remainingSeconds()
    if (remaining <= 0) {
      statusBar.removeStatusItem(item)
      app.terminate(app)
      return
    }
    item.button.title = render(remaining)
  }

  tick()
  $.NSTimer.scheduledTimerWithTimeIntervalRepeatsBlock(1.0, true, tick)
  app.run()
}
