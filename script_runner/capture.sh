#!/bin/bash

if [ -n "$R_SCRIPT_GETHELP" ]; then
    echo "r capture [video] [audio] - Low-latency MJPEG video capture with audio passthrough"
    exit 0
fi

if [ -n "$R_SCRIPT_COMPLETE" ]; then
    case "$R_SCRIPT_COMPLETE_INDEX" in
        1) v4l2-ctl --list-devices 2>/dev/null | grep -oP '/dev/video\d+' ;;
        2) wpctl status 2>/dev/null | sed -n '/Audio/,/Video/p' | grep -oP '^\s+\K\d+(?=\.)' ;;
    esac
    exit 0
fi

usage() {
    cat <<'EOF'
Usage: r capture [OPTIONS] [VIDEO_DEVICE] [AUDIO_ID]

Low-latency MJPEG video capture with PipeWire audio passthrough.

Arguments:
  VIDEO_DEVICE    V4L2 device path (e.g. /dev/video0)
  AUDIO_ID        PipeWire source node ID (e.g. 69)

Options:
  -h, --help      Show this help message
  -l, --list      List available video and audio capture devices

If no arguments are given, autodetection is attempted by looking for
USB/HDMI capture devices (skipping built-in cameras).

Examples:
  r capture                         # autodetect both
  r capture /dev/video2             # specific video, autodetect audio
  r capture /dev/video2 69          # specific video and audio
EOF
    exit "${1:-0}"
}

list_devices() {
    echo "Video devices:"
    if command -v v4l2-ctl &>/dev/null; then
        v4l2-ctl --list-devices 2>/dev/null | while IFS= read -r line; do
            echo "  $line"
            # Show formats for each video device
            if [[ "$line" =~ /dev/video[0-9]+ ]]; then
                local dev="${BASH_REMATCH[0]}"
                local formats
                formats=$(v4l2-ctl -d "$dev" --list-formats 2>/dev/null | grep -oP "'\K[^']+")
                [ -n "$formats" ] && echo "    Formats: $(echo $formats | tr '\n' ' ')"
            fi
        done
    else
        echo "  v4l2-ctl not found (install v4l-utils)"
    fi

    echo
    echo "Audio sources (PipeWire):"
    if command -v wpctl &>/dev/null; then
        wpctl status 2>/dev/null | sed -n '/Audio/,/Video/{/Sources:/,/Filters:/{/Sources:\|Filters:/d;p}}' | while IFS= read -r line; do
            echo " $line"
        done
    else
        echo "  wpctl not found (install wireplumber)"
    fi
}

autodetect_video() {
    # Look for USB capture devices via v4l2, skip built-in cameras
    local device=""
    while IFS= read -r block; do
        # Skip known built-in devices
        if echo "$block" | head -1 | grep -qiE 'isp|integrated|webcam|laptop'; then
            continue
        fi
        # Get the first /dev/videoN from this block
        local dev
        dev=$(echo "$block" | grep -oP '/dev/video\d+' | head -1)
        if [ -n "$dev" ]; then
            device="$dev"
            break
        fi
    done < <(v4l2-ctl --list-devices 2>/dev/null | awk '/^[^ ]/{block=$0; next} {block=block"\n"$0} /^$/{print block; block=""} END{if(block) print block}')
    echo "$device"
}

autodetect_audio() {
    # Find a PipeWire audio source that matches the capture card name
    # First get the video device name for matching
    local video_name=""
    if [ -n "$1" ]; then
        video_name=$(v4l2-ctl --list-devices 2>/dev/null | grep -B1 "$1" | head -1 | sed 's/ (.*//' | xargs)
    fi

    local source_id=""
    if [ -n "$video_name" ]; then
        # Try to find audio source matching the video device name
        local keyword
        keyword=$(echo "$video_name" | awk '{print $1}')
        source_id=$(wpctl status 2>/dev/null | sed -n '/Audio/,/Video/{/Sources:/,/Filters:/{/Sources:\|Filters:/d;p}}' | grep -i "$keyword" | grep -oP '^\s+\K\d+' | head -1)
    fi

    # Fallback: pick first non-default audio source that looks like a capture device
    if [ -z "$source_id" ]; then
        source_id=$(wpctl status 2>/dev/null | sed -n '/Audio/,/Video/{/Sources:/,/Filters:/{/Sources:\|Filters:/d;p}}' | grep -viE 'microphone|mic|monitor' | grep -oP '^\s+\*?\s*\K\d+' | head -1)
    fi

    echo "$source_id"
}

cleanup() {
    echo
    echo "Stopping capture..."
    [ -n "$mpv_pid" ] && kill "$mpv_pid" 2>/dev/null
    [ -n "$audio_pid" ] && kill "$audio_pid" 2>/dev/null
    wait 2>/dev/null
    echo "Done."
}

# Parse options
case "${1:-}" in
    -h|--help) usage 0 ;;
    -l|--list) list_devices; exit 0 ;;
esac

# Check dependencies
for cmd in mpv v4l2-ctl pw-record pw-play wpctl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is not installed." >&2
        exit 1
    fi
done

video_device="${1:-}"
audio_id="${2:-}"

# Autodetect video device
if [ -z "$video_device" ]; then
    video_device=$(autodetect_video)
    if [ -z "$video_device" ]; then
        echo "Error: Could not autodetect a capture video device." >&2
        echo "Run 'r capture --list' to see available devices, then specify manually." >&2
        exit 1
    fi
    echo "Autodetected video: $video_device"
fi

# Validate video device
if [ ! -e "$video_device" ]; then
    echo "Error: Video device '$video_device' does not exist." >&2
    exit 1
fi

if [ ! -r "$video_device" ]; then
    echo "Error: No read permission on '$video_device'." >&2
    exit 1
fi

# Autodetect audio source
if [ -z "$audio_id" ]; then
    audio_id=$(autodetect_audio "$video_device")
    if [ -z "$audio_id" ]; then
        echo "Warning: Could not autodetect audio source. Running video only." >&2
        echo "Run 'r capture --list' to see available audio sources." >&2
    else
        echo "Autodetected audio: PipeWire source $audio_id"
    fi
fi

# Validate audio ID is numeric
if [ -n "$audio_id" ] && ! [[ "$audio_id" =~ ^[0-9]+$ ]]; then
    echo "Error: Audio ID must be a numeric PipeWire node ID, got '$audio_id'." >&2
    exit 1
fi

trap cleanup EXIT INT TERM

# Check if device supports MJPEG, fall back to raw
video_format=""
if v4l2-ctl -d "$video_device" --list-formats 2>/dev/null | grep -qi mjpeg; then
    video_format="mjpeg"
fi

echo "Starting capture (Ctrl+C to stop)..."
if [ -n "$video_format" ]; then
    echo "  Video: $video_device (MJPEG, low-latency)"
else
    echo "  Video: $video_device (raw, low-latency)"
fi
[ -n "$audio_id" ] && echo "  Audio: PipeWire source $audio_id"
echo

# Start video
mpv_opts=(
    --profile=low-latency
    --no-audio
    --untimed
    --no-cache
    --demuxer-lavf-analyzeduration=0
    --demuxer-lavf-probesize=32
    --vd-lavc-threads=1
    --video-latency-hacks=yes
    --opengl-glfinish=yes
    --opengl-swapinterval=0
)
if [ -n "$video_format" ]; then
    mpv_opts+=(--demuxer-lavf-o=input_format=mjpeg,fflags=+nobuffer+flush_packets,analyzeduration=0,probesize=32)
else
    mpv_opts+=(--demuxer-lavf-o=fflags=+nobuffer+flush_packets,analyzeduration=0,probesize=32)
fi
mpv "${mpv_opts[@]}" "av://v4l2:$video_device" &
mpv_pid=$!

# Start audio passthrough
audio_pid=""
if [ -n "$audio_id" ]; then
    pw-record --target "$audio_id" - | pw-play - &
    audio_pid=$!
fi

# Wait for either process to exit
wait -n 2>/dev/null
