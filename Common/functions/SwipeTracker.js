.pragma library

// Based on GNOME Shell's swipeTracker.js. Progress is expressed in pages and
// velocity in pages per millisecond, so the same constants work for any size
// of screen or launchpad grid.
var cancelArea = 0.5;
var velocityThreshold = 0.001;
var minimumDuration = 100;
var maximumDuration = 400;
var durationMultiplier = 3;

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value));
}

function cancelled(progress, velocity) {
    if (progress === 0)
        return true;
    if (Math.abs(velocity) < velocityThreshold)
        return Math.abs(progress) < cancelArea;
    return velocity * progress < 0;
}

function target(start, progress, velocity) {
    if (cancelled(progress, velocity))
        return start;
    return start + (progress > 0 ? 1 : -1);
}

function snapDuration(progress, destination, velocity) {
    const speed = Math.max(Math.abs(velocity), velocityThreshold);
    return clamp(Math.abs((progress - destination) / speed * durationMultiplier), minimumDuration,
                 maximumDuration);
}
