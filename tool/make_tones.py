"""Five candidate notification tones for RewireMind.

Each one differs in rhythm as much as in pitch -- recognition comes from the
rhythmic shape at least as much as the notes, which is why the candidates are
not five arrangements of the same figure.
"""
import math, struct, wave, os

SR = 44100
OUT = os.path.dirname(os.path.abspath(__file__))

# Equal temperament, A4 = 440.
def note(name):
    names = {'C':0,'C#':1,'D':2,'D#':3,'E':4,'F':5,'F#':6,
             'G':7,'G#':8,'A':9,'A#':10,'B':11}
    pitch, octave = name[:-1], int(name[-1])
    semis = names[pitch] + (octave - 4) * 12 - 9
    return 440.0 * (2 ** (semis / 12))


# Partial ratios and levels, per instrument voice.
VOICES = {
    # Tines: near-harmonic, slightly stretched. Warm.
    'kalimba':  [(1.000, 1.00), (2.004, 0.34), (3.012, 0.13), (4.02, 0.05)],
    # Marimba bars are undercut to tune the 4th partial. Woody, hollow.
    'marimba':  [(1.000, 1.00), (3.930, 0.30), (9.200, 0.07)],
    # Music box: bright, dense harmonics, very quick decay.
    'musicbox': [(1.000, 1.00), (2.000, 0.50), (3.000, 0.28),
                 (4.000, 0.18), (5.000, 0.10), (6.000, 0.06)],
    # Bell partials are genuinely inharmonic. Long bloom.
    'bell':     [(1.000, 1.00), (2.000, 0.42), (2.760, 0.48),
                 (4.070, 0.28), (5.430, 0.16), (6.800, 0.09)],
    # Glass/crotale: sparse and shimmering.
    'glass':    [(1.000, 1.00), (2.700, 0.30), (5.200, 0.14)],
}


def render(notes, voice, duration, path, attack=0.0025):
    """notes: list of (note name, start seconds, decay seconds, gain)."""
    partials = VOICES[voice]
    n = int(SR * duration)
    buf = [0.0] * n

    for name, start, decay, gain in notes:
        freq = note(name)
        s0 = int(start * SR)
        for i in range(s0, n):
            t = (i - s0) / SR
            env = (1.0 - math.exp(-t / attack)) * math.exp(-t / decay)
            if env < 1e-4:
                break
            sample = 0.0
            for ratio, level in partials:
                # Upper partials die away first, as on a real struck body.
                damp = math.exp(-t / (decay / (ratio ** 1.35)))
                sample += level * damp * math.sin(2 * math.pi * freq * ratio * t)
            buf[i] += gain * env * sample

    peak = max(abs(v) for v in buf) or 1.0
    fade = int(0.02 * SR)
    frames = bytearray()
    for i, v in enumerate(buf):
        v = v / peak * 0.82           # headroom so no device clips it
        if i > n - fade:
            v *= (n - i) / fade
        frames += struct.pack('<h', int(max(-1.0, min(1.0, v)) * 32767))

    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    return os.path.getsize(path)


CANDIDATES = [
    # A -- rising major arpeggio, two quick then one landing after a beat of
    # air. The gap is what makes it stick.
    ('a_ascent', 'kalimba', 1.05, [
        ('G5', 0.000, 0.42, 0.62),
        ('C6', 0.105, 0.46, 0.78),
        ('E6', 0.290, 0.85, 1.00),
    ]),

    # B -- two notes, a clean fifth apart. The shortest thing that can still be
    # a signature. Crisp and unfussy.
    ('b_leap', 'marimba', 0.70, [
        ('C6', 0.000, 0.30, 0.85),
        ('G6', 0.130, 0.55, 1.00),
    ]),

    # C -- four fast notes up a pentatonic scale. The most energetic option,
    # closest in character to Duolingo's.
    ('c_sprout', 'musicbox', 1.00, [
        ('D6', 0.000, 0.26, 0.70),
        ('F#6', 0.085, 0.26, 0.78),
        ('A6', 0.170, 0.30, 0.86),
        ('D7', 0.255, 0.62, 1.00),
    ]),

    # D -- one struck bell with an octave underneath it. Calm and unhurried;
    # the option that suits a tree on a hill.
    ('d_bell', 'bell', 1.60, [
        ('C5', 0.000, 1.10, 0.45),
        ('C6', 0.000, 1.20, 1.00),
    ]),

    # E -- rises, then settles back down. The falling last note reads as
    # "here you go" rather than "do this now".
    ('e_settle', 'glass', 1.30, [
        ('E6', 0.000, 0.40, 0.80),
        ('A6', 0.115, 0.40, 0.92),
        ('F#6', 0.300, 0.90, 1.00),
    ]),
]

for name, voice, duration, notes in CANDIDATES:
    path = os.path.join(OUT, 'tone_%s.wav' % name)
    size = render(notes, voice, duration, path)
    print('%-12s %-9s %.2fs  %5.1f KB' % (name, voice, duration, size / 1024))

# Usage:
#   python tool/make_tones.py
# Renders tone_*.wav beside this file. To adopt one:
#   1. ffmpeg -i tone_x.wav -c:a libvorbis -q:a 5 \
#        android/app/src/main/res/raw/rewiremind_chime.ogg
#   2. cp tone_x.wav ios/Runner/rewiremind_chime.wav
#   3. Set `sound:` in notification_service.dart and bump the channel to v2 --
#      Android freezes a channel's sound at creation and ignores later edits.
