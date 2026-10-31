#!/bin/zsh
# The plugin against in-process MLXServeEngine: interpolations run on the signed bundle the way Gaea runs them
# (gaea-plugin-check: launch under the launch requirement, configure, prepare, run) and through rife-inproc with the
# lane configuration and request the worker uses. Each pair must decode to the same frames, byte for byte (ffmpeg's
# framemd5): the files differ only in the MP4's creation time, to the second. Each has (N − 1) × factor + 1 frames, in
# HEVC. The package writes on a 1/600 time base, so 96 and 192 fps land a little unevenly; Gaea retimes its output to the
# exact rate (GaeaVideo.retime), so the rate isn't checked here.
#
#   scripts/golden.sh <out-dir>     (after scripts/build-plugin.sh)
#
# Cases: Tests/Fixtures/clip.mp4 (128×96, 17 frames at 24 fps, with sound) at factors 2, 4 and 8, and clip360.mp4
# (640×360, 48 frames) at factor 2. Needs ffprobe for the frame counts.
set -uo pipefail
ROOT=${0:A:h:h}
cd $ROOT
OUT=${1:?out dir}; mkdir -p $OUT
B=$ROOT/dist/rife.gaeaplugin
F=$ROOT/Tests/Fixtures
MODELS=${CHECK_MODELS_ROOT:-$HOME/Library/Application Support/MLXEngine/Models}
SWIFTPM=(-c release --build-system swiftbuild)
xcrun swift build $SWIFTPM --product rife-inproc > /dev/null && xcrun swift build -c release --product gaea-plugin-check > /dev/null
INPROC=$(xcrun swift build $SWIFTPM --show-bin-path)/rife-inproc; CHECK=$(xcrun swift build -c release --show-bin-path)/gaea-plugin-check
LOG=$OUT/golden.log; : > $LOG
pass=0; fail=0
say() { print -r -- "$*" | tee -a $LOG }
say "# RIFE golden check $(date -u +%FT%TZ): $(python3 -c "import json; m=json.load(open('$B/Contents/Resources/manifest.json')); print(m['id'], m['version'])")"
probe() { ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=codec_name,nb_read_frames -of csv=p=0 $1 }
frames() { ffmpeg -v error -i $1 -map 0:v -f framemd5 - | grep -v '^#' | shasum -a 256 | cut -c1-16 }
outputs() { grep -o '"path":"[^"]*"' $1 | sed 's/"path":"//; s/"$//; s/\\\//\//g' | awk '!seen[$0]++' }

# case <name> <clip> <factor> <source frames> <source fps>
case_() {
  local name=$1 clip=$2 factor=$3 frames=$4 fps=$5
  $CHECK $B --operation video.interpolate --model rife-4.25 --lane fp32 --params "{\"factor\":$factor}" --input "video=$clip" \
    --models-root "$MODELS" --budget 64000000000 --timeout 900 --session $OUT/$name.gpp > $OUT/$name-gpp.log 2>&1
  local file=$(outputs $OUT/$name-gpp.log | head -1); [[ -f $file ]] && cp $file $OUT/$name-gpp.mp4
  $INPROC --video $clip --factor $factor --models-root "$MODELS" --out $OUT/$name-inproc.mp4 2>> $LOG | tail -1 > $OUT/$name-inproc.json
  say "      $name: over GPP $(grep -o 'ran in [0-9.]* s' $OUT/$name-gpp.log | head -1); in-process $(cat $OUT/$name-inproc.json)"
  local a=$(frames $OUT/$name-gpp.mp4 2>/dev/null) b=$(frames $OUT/$name-inproc.mp4 2>/dev/null)
  local got=$(probe $OUT/$name-gpp.mp4 2>/dev/null) want="hevc,$(( (frames - 1) * factor + 1 ))"
  if [[ -n $a && $a == $b && $got == $want ]]; then pass=$((pass+1)); say "PASS  $name: the same decoded frames, $got, framemd5 sha256 $a…"
  else fail=$((fail+1)); say "FAIL  $name: $a… / $b…, $got (want $want)"; fi
}

case_ x2 $F/clip.mp4 2 17 24
case_ x4 $F/clip.mp4 4 17 24
case_ x8 $F/clip.mp4 8 17 24
case_ x2-360p $F/clip360.mp4 2 48 24

for s in $OUT/*.gpp; do
  if python3 ${GAEA_SPEC_ROOT:-$ROOT/../gaea-mes-media-server}/tools/validate.py --transcript $s >> $LOG 2>&1; then pass=$((pass+1)); say "PASS  ${s:t} passes validate.py"
  else fail=$((fail+1)); say "FAIL  ${s:t} fails validate.py"; fi
done
say "== $pass passed, $fail failed"
exit $(( fail > 0 ))
