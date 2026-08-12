#!/bin/bash

if [ -n "$R_SCRIPT_GETHELP" ]; then
    echo "r capture [video] [audio] - Low-latency MJPEG video capture with audio passthrough"
    exit 0
fi

usage() {
    cat <<'EOF'
Usage: r capture [OPTIONS] [VIDEO_DEVICE] [AUDIO_SOURCE]

Low-latency MJPEG video capture with PipeWire audio passthrough.

Arguments:
  VIDEO_DEVICE    V4L2 device path (e.g. /dev/video1)
  AUDIO_SOURCE    PipeWire source: the ID shown by --list, an object.serial,
                  or a node name (alsa_input.usb-...)

Options:
  -h, --help      Show this help message
  -l, --list      List available video and audio capture devices

If no arguments are given, autodetection is attempted by looking for
USB/HDMI capture devices (skipping built-in cameras). The audio source is
matched to the video device by USB serial, so both come from the same card.

Examples:
  r capture                         # autodetect both
  r capture /dev/video1             # specific video, autodetect audio
  r capture /dev/video1 71          # specific video and audio
EOF
    exit "${1:-0}"
}

# --- PipeWire helpers -------------------------------------------------------
#
# wpctl status shows each node's object.id, but pw-loopback -C (like pw-cat
# --target) wants an object.serial or a node.name. Handing it an object.id is
# not an error: it silently falls back to the *default* source, i.e. the
# built-in microphone. Everything below resolves a selection to a node.name
# before it reaches pw-loopback.

# object.ids of the Audio/Source nodes, in wpctl status order.
# Scoped to the top-level "Audio" section on purpose: the "Video" section has
# its own Sources list, and a sed '/Audio/,/Video/' range breaks apart as soon
# as a device is named something like "Guermok USB3 Video".
audio_source_ids() {
    wpctl status 2>/dev/null | awk '
        /^Audio$/   { section = "audio"; next }
        /^[A-Za-z]/ { section = "";      next }
        section != "audio" { next }
        /Sources:/  { in_sources = 1; next }
        /(Devices|Sinks|Filters|Streams):/ { in_sources = 0 }
        in_sources && /^[^0-9]*[0-9]+\./ {
            id = $0
            sub(/^[^0-9]*/, "", id)   # leading spaces, tree glyphs, default "*"
            sub(/\..*$/, "", id)
            print id
        }
    '
}

# node_prop <object.id> <property>
node_prop() {
    local prop="${2//./\\.}"
    wpctl inspect "$1" 2>/dev/null | sed -n "s/^[ *]*$prop = \"\(.*\)\"\$/\1/p" | head -1
}

source_label() {
    local desc
    desc=$(node_prop "$1" node.description)
    [ -n "$desc" ] || desc=$(node_prop "$1" node.name)
    printf '%s' "$desc"
}

# Map a user selector (object.id, object.serial or node.name) to the object.id
# of an actual Audio/Source. Fails if the selection isn't a capture source.
find_source_id() {
    local sel="$1" id
    for id in $(audio_source_ids); do
        if [ "$sel" = "$id" ] \
            || [ "$sel" = "$(node_prop "$id" object.serial)" ] \
            || [ "$sel" = "$(node_prop "$id" node.name)" ]; then
            printf '%s' "$id"
            return 0
        fi
    done
    return 1
}

video_devices() {
    local dev
    while IFS= read -r dev; do
        [ -e "$dev" ] || continue
        # Capture cards expose extra /dev/videoN nodes for metadata only;
        # a node with no pixel formats can't be played.
        v4l2-ctl -d "$dev" --list-formats 2>/dev/null | grep -q "^\s*\[0\]" || continue
        printf '%s\n' "$dev"
    done < <(printf '%s\n' /dev/video* | sort -V)
}

card_type() {
    v4l2-ctl -d "$1" --info 2>/dev/null | sed -n 's/^[[:space:]]*Card type[[:space:]]*:[[:space:]]*//p' | head -1
}

# --- Completion -------------------------------------------------------------

if [ -n "$R_SCRIPT_COMPLETE" ]; then
    case "$R_SCRIPT_COMPLETE_INDEX" in
        1) video_devices ;;
        2) audio_source_ids ;;
    esac
    exit 0
fi

# --- Listing ----------------------------------------------------------------

list_devices() {
    local dev id

    echo "Video devices:"
    if command -v v4l2-ctl &>/dev/null; then
        while IFS= read -r dev; do
            printf '  %-14s %s\n' "$dev" "$(card_type "$dev")"
            printf '    Formats: %s\n' \
                "$(v4l2-ctl -d "$dev" --list-formats 2>/dev/null | grep -oP "'\K[^']+" | tr '\n' ' ')"
        done < <(video_devices)
    else
        echo "  v4l2-ctl not found (install v4l-utils)"
    fi

    echo
    echo "Audio sources (PipeWire):"
    if command -v wpctl &>/dev/null; then
        for id in $(audio_source_ids); do
            printf '  %-5s %s%s\n' "$id" "$(source_label "$id")" \
                "$(wpctl get-volume "$id" 2>/dev/null | grep -q MUTED && echo '  [MUTED]')"
        done
    else
        echo "  wpctl not found (install wireplumber)"
    fi
}

# --- Autodetection ----------------------------------------------------------

autodetect_video() {
    local dev card
    while IFS= read -r dev; do
        card=$(card_type "$dev")
        echo "$card" | grep -qiE 'isp|integrated|webcam|laptop|facetime' && continue
        printf '%s' "$dev"
        return 0
    done < <(video_devices)
    return 1
}

# Match the audio source to the video device by USB identity rather than by
# name: the ALSA node name embeds the udev ID_SERIAL of the same USB device.
autodetect_audio() {
    local video_dev="$1" serial bus id dev_id bus_path

    serial=$(udevadm info -q property "$video_dev" 2>/dev/null | sed -n 's/^ID_SERIAL=//p')
    if [ -n "$serial" ]; then
        for id in $(audio_source_ids); do
            case "$(node_prop "$id" node.name)" in
                *"$serial"*) printf '%s' "$id"; return 0 ;;
            esac
        done
    fi

    # Fall back to the USB port path. The video and audio interfaces of one
    # device share everything but the trailing interface number.
    bus=$(udevadm info -q property "$video_dev" 2>/dev/null | sed -n 's/^ID_PATH=//p')
    bus="${bus%.*}"
    if [ -n "$bus" ]; then
        for id in $(audio_source_ids); do
            dev_id=$(node_prop "$id" device.id)
            [ -n "$dev_id" ] || continue
            bus_path=$(node_prop "$dev_id" device.bus-path)
            case "$bus_path" in
                "$bus".*|"$bus") printf '%s' "$id"; return 0 ;;
            esac
        done
    fi

    return 1
}

cleanup() {
    trap - EXIT INT TERM
    echo
    echo "Stopping capture..."
    [ -n "$mpv_pid" ] && kill "$mpv_pid" 2>/dev/null
    [ -n "$audio_pid" ] && kill "$audio_pid" 2>/dev/null
    [ -n "$unmuted_id" ] && wpctl set-mute "$unmuted_id" 1 2>/dev/null
    wait 2>/dev/null
    echo "Done."
}

# Parse options
case "${1:-}" in
    -h|--help) usage 0 ;;
    -l|--list) list_devices; exit 0 ;;
esac

# Check dependencies
for cmd in mpv v4l2-ctl pw-loopback wpctl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is not installed." >&2
        exit 1
    fi
done

video_device="${1:-}"
audio_sel="${2:-}"

# Autodetect video device
if [ -z "$video_device" ]; then
    video_device=$(autodetect_video)
    if [ -z "$video_device" ]; then
        echo "Error: Could not autodetect a capture video device." >&2
        echo "Run 'r capture --list' to see available devices, then specify manually." >&2
        exit 1
    fi
    echo "Autodetected video: $video_device ($(card_type "$video_device"))"
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

# Resolve audio source
audio_id=""
if [ -n "$audio_sel" ]; then
    audio_id=$(find_source_id "$audio_sel")
    if [ -z "$audio_id" ]; then
        echo "Error: '$audio_sel' is not a PipeWire audio source." >&2
        echo "Run 'r capture --list' to see available audio sources." >&2
        exit 1
    fi
else
    audio_id=$(autodetect_audio "$video_device")
    if [ -z "$audio_id" ]; then
        echo "Warning: Could not autodetect audio source. Running video only." >&2
        echo "Run 'r capture --list' to see available audio sources." >&2
    fi
fi

audio_node=""
if [ -n "$audio_id" ]; then
    audio_node=$(node_prop "$audio_id" node.name)
    if [ -z "$audio_node" ]; then
        echo "Error: Could not read node.name of PipeWire source $audio_id." >&2
        exit 1
    fi
fi

trap cleanup EXIT INT TERM

# A muted source records digital silence, so unmute it for the session and put
# it back the way it was on exit.
unmuted_id=""
if [ -n "$audio_id" ] && wpctl get-volume "$audio_id" 2>/dev/null | grep -q MUTED; then
    echo "Unmuting source $audio_id for this session (was muted -> silent capture)."
    wpctl set-mute "$audio_id" 0
    unmuted_id="$audio_id"
fi

# Check if device supports MJPEG, fall back to raw.
# v4l2 spells the fourcc "MJPG" and the description "Motion-JPEG" -- neither
# contains the string "mjpeg".
video_format=""
if v4l2-ctl -d "$video_device" --list-formats 2>/dev/null | grep -qiE 'mjpg|motion-jpeg'; then
    video_format="mjpeg"
fi

echo "Starting capture (Ctrl+C to stop)..."
if [ -n "$video_format" ]; then
    echo "  Video: $video_device (MJPEG, low-latency)"
else
    echo "  Video: $video_device (raw, low-latency)"
fi
[ -n "$audio_id" ] && echo "  Audio: $(source_label "$audio_id") [id $audio_id]"
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

# Start audio passthrough. pw-loopback links the source straight to the default
# sink; the old pw-record | pw-play pipe went through a WAV stream and two
# 100ms buffers.
audio_pid=""
if [ -n "$audio_node" ]; then
    pw-loopback -C "$audio_node" --latency "${CAPTURE_AUDIO_LATENCY:-20}" &
    audio_pid=$!
fi

# Wait for either process to exit
wait -n 2>/dev/null
