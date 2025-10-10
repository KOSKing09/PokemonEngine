function CameraSystem(){

}/// scr_cam_shake.gml
/// Small camera shake helper: create → start → update.
/// USAGE:
///   shake = cam_shake_create();
///   cam_shake_start(shake, 8, 18, 24, 0.9); // amp, frames, freqHz-ish, decay [0..1]
///   var ofs = cam_shake_update(shake);  // returns {x, y}

function cam_shake_create(){
    return {
        amp      : 0,      // current amplitude (pixels)
        time     : 0,      // frames remaining
        base_amp : 0,      // starting amplitude (for decay)
        freq     : 24,     // oscillations per second-ish (frame-based)
        phase_x  : irandom_range(0, 100000),
        phase_y  : irandom_range(0, 100000),
        decay    : 0.9,    // per-frame decay multiplier (0..1)
        offx     : 0,
        offy     : 0
    };
}

function cam_shake_start(sh, amplitude, duration_frames, freq_hz, decay_mul){
    sh.amp      = max(0, amplitude);
    sh.base_amp = sh.amp;
    sh.time     = max(0, duration_frames);
    sh.freq     = max(0.001, freq_hz);
    sh.decay    = clamp(decay_mul, 0, 1);
    // randomize phases so X/Y don’t match
    sh.phase_x  = irandom_range(0, 100000);
    sh.phase_y  = irandom_range(0, 100000);
}

function cam_shake_update(sh){
    if (sh.time > 0){
        // advance phases (frame-based; if you use delta, multiply by delta seconds)
        sh.phase_x += sh.freq * 0.1047; // ~2π/60 ≈ 0.1047 per “hz” unit
        sh.phase_y += sh.freq * 0.1047 * 1.37;

        // decaying sine offsets in a rough circle/ellipse
        var ax = sh.amp * sin(sh.phase_x);
        var ay = sh.amp * cos(sh.phase_y);

        // small random jitter so repeated hits feel varied
        ax += random_range(-0.35, 0.35);
        ay += random_range(-0.35, 0.35);

        sh.offx = ax;
        sh.offy = ay;

        // decay + countdown
        sh.amp  *= sh.decay;
        sh.time -= 1;
        if (sh.time <= 0){ sh.offx = 0; sh.offy = 0; sh.amp = 0; }
    } else {
        sh.offx = 0; sh.offy = 0;
    }
    return { x: sh.offx, y: sh.offy };
}

