pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default speaker and microphone from PipeWire.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property bool ready: !!sink?.ready
    // the speaker goes past 100% (PipeWire amplifies in software); the mic doesn't
    readonly property real maxVolume: 1.5

    readonly property string icon: muted || volume <= 0.001 ? "volume-mute"
        : volume < 0.45 ? "volume-low" : "volume"

    function setVolume(v) {
        if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(root.maxVolume, v));
    }
    function setMicVolume(v) {
        if (source?.audio) source.audio.volume = Math.max(0, Math.min(1, v));
    }
    function toggleMute() {
        if (sink?.audio) sink.audio.muted = !sink.audio.muted;
    }
    function toggleMic() {
        if (source?.audio) source.audio.muted = !source.audio.muted;
    }

    // nodes must be tracked for their audio properties to be live
    PwObjectTracker {
        objects: [root.sink, root.source]
    }
}
