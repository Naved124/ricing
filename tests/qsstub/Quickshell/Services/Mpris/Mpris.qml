// A stand-in for Quickshell's own type, so tests/test_shells_smoke.py can run
// the shells under PySide6. Only what the shells use; nothing really happens.

pragma Singleton
import QtQuick
import Quickshell
QtObject {
    property QtObject player: QtObject {
        property string identity: "Spotify"
        property string desktopEntry: "spotify"
        property bool isPlaying: true
        property int playbackState: 1
        property string trackTitle: "A very long song title that has to scroll past"
        property string trackArtist: "Someone"
        property string trackAlbum: "Somewhere"
        property string trackArtUrl: ""
        property real position: 30
        property real length: 200
        property bool positionSupported: true
        property bool lengthSupported: true
        property bool canPlay: true
        property bool canPause: true
        property bool canGoNext: true
        property bool canGoPrevious: true
        property bool canSeek: true
        property bool canControl: true
        property real volume: 1
        function togglePlaying() { isPlaying = !isPlaying; }
        function play() {} function pause() {} function next() {} function previous() {}
        function seek(o) {}
    }
    property QsObjectModel players: QsObjectModel { values: [player] }
}
