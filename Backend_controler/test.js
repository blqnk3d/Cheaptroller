const gamepad = require('./gamepad.node');

// ----- Helper for digital DPad -----
const DPAD_MAP = { 
  10: "Up", 
  11: "Down", 
  12: "Left", 
  13: "Right" 
};

function pressDpad(idx, duration = 200) {
  const dir = DPAD_MAP[idx];
  if (!dir) {
    console.warn("Unknown DPad index:", idx);
    return;
  }

  console.log(`Pressing DPad ${dir}`);
  gamepad.pressButton(dir, true); // press
  setTimeout(() => {
    console.log(`Releasing DPad ${dir}`);
    gamepad.pressButton(dir, false); // release
  }, duration);
}

// ----- Test routine -----
function testDpadSequence() {
  const sequence = [12, 11, 13, 10]; // Left, Down, Right, Up
  let delay = 0;

  for (const idx of sequence) {
    setTimeout(() => pressDpad(idx), delay);
    delay += 500; // 500ms between presses
  }

  // End test
  setTimeout(() => {
    console.log("Digital DPad test complete");
  }, delay + 500);
}

// ----- Initialize gamepad and run test -----
try {
  gamepad.create();
  console.log("🎮 Gamepad initialized");
  testDpadSequence();
} catch (err) {
  console.error("❌ Failed to initialize gamepad:", err);
}
