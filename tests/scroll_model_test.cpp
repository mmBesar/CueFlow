#include "../src/ScrollModel.h"

#include <cmath>
#include <cstdlib>
#include <iostream>
#include <string_view>

namespace {
int failures = 0;
void expect(bool condition, std::string_view message) {
    if (!condition) {
        std::cerr << "FAIL: " << message << '\n';
        ++failures;
    }
}
bool near(double a, double b, double epsilon = 1e-9) {
    return std::abs(a - b) <= epsilon;
}
}

int main() {
    ScrollModel model(100.0);
    expect(near(model.progress(), 0.0), "starts at the beginning");
    expect(!model.advance(1.0 / 60.0, 1000.0), "does not move while paused");

    model.setPlaying(true);
    expect(model.advance(1.0 / 60.0, 1000.0), "advances while playing");
    expect(near(model.progress(), 1.0 / 600.0), "movement is based on elapsed time, not tick count");

    // Equal elapsed time split into different frame rates produces the same place.
    ScrollModel sixtyHz(120.0), thirtyHz(120.0);
    sixtyHz.setPlaying(true);
    thirtyHz.setPlaying(true);
    for (int i = 0; i < 60; ++i) sixtyHz.advance(1.0 / 60.0, 600.0);
    for (int i = 0; i < 30; ++i) thirtyHz.advance(1.0 / 30.0, 600.0);
    expect(near(sixtyHz.progress(), thirtyHz.progress()), "frame-rate independent elapsed-time movement");
    expect(near(sixtyHz.progress(), 0.2), "120 px/s over 600 px moves 120 px in one second");

    model.reset();
    model.setProgress(0.5);
    expect(model.nudgePixels(20.0, 1000.0), "nudge changes progress");
    expect(near(model.progress(), 0.52), "nudge moves exactly the requested pixel amount");
    expect(near(model.offsetPixels(1000.0), 520.0), "progress maps back to pixel offset");

    model.setProgress(0.999);
    model.setSpeed(1000.0);
    model.setPlaying(true);
    model.advance(0.05, 1000.0);
    expect(near(model.progress(), 1.0), "progress clamps at the end");
    expect(!model.playing(), "playback stops at the end");

    model.setProgress(-1.0);
    expect(near(model.progress(), 0.0), "negative progress clamps to start");
    model.setProgress(4.0);
    expect(near(model.progress(), 1.0), "progress above end clamps to one");
    model.setProgress(std::nan(""));
    expect(near(model.progress(), 0.0), "non-finite progress is safely rejected");

    ScrollModel capped(100.0);
    capped.setPlaying(true);
    capped.advance(5.0, 1000.0);
    expect(near(capped.progress(), 0.005), "large elapsed time is capped to prevent suspend jumps");

    if (failures) {
        std::cerr << failures << " test(s) failed\n";
        return EXIT_FAILURE;
    }
    std::cout << "All ScrollModel tests passed.\n";
    return EXIT_SUCCESS;
}
