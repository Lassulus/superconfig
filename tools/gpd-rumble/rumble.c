#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <linux/input.h>
#include <sys/ioctl.h>

int main(int argc, char *argv[]) {
    int fd;
    struct ff_effect effect;
    struct input_event play, stop;
    int duration_ms = 500;
    int strength = 0xFFFF;
    const char *device = "/dev/input/event2";

    // Parse arguments
    if (argc > 1) {
        duration_ms = atoi(argv[1]);
    }
    if (argc > 2) {
        strength = (atoi(argv[2]) * 0xFFFF) / 100;
        if (strength > 0xFFFF) strength = 0xFFFF;
    }
    if (argc > 3) {
        device = argv[3];
    }

    // Open device
    fd = open(device, O_RDWR);
    if (fd < 0) {
        perror("Failed to open device");
        fprintf(stderr, "Usage: %s [duration_ms] [strength_percent] [device]\n", argv[0]);
        return 1;
    }

    // Setup rumble effect
    memset(&effect, 0, sizeof(effect));
    effect.type = FF_RUMBLE;
    effect.id = -1;
    effect.u.rumble.strong_magnitude = strength;
    effect.u.rumble.weak_magnitude = strength / 2;
    effect.replay.length = duration_ms;
    effect.replay.delay = 0;

    // Upload effect
    if (ioctl(fd, EVIOCSFF, &effect) < 0) {
        perror("Failed to upload effect");
        close(fd);
        return 1;
    }

    // Play effect
    memset(&play, 0, sizeof(play));
    play.type = EV_FF;
    play.code = effect.id;
    play.value = 1;

    if (write(fd, &play, sizeof(play)) < 0) {
        perror("Failed to play effect");
        ioctl(fd, EVIOCRMFF, effect.id);
        close(fd);
        return 1;
    }

    printf("Rumble playing for %d ms at %d%% strength\n", duration_ms, (strength * 100) / 0xFFFF);

    // Wait for effect to finish
    usleep(duration_ms * 1000);

    // Stop effect
    memset(&stop, 0, sizeof(stop));
    stop.type = EV_FF;
    stop.code = effect.id;
    stop.value = 0;
    write(fd, &stop, sizeof(stop));

    // Cleanup
    ioctl(fd, EVIOCRMFF, effect.id);
    close(fd);

    return 0;
}
