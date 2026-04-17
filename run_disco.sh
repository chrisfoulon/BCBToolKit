#!/usr/bin/env bash
# =============================================================================
# run_disco.sh — Disconnectome Maps Runner for BCBToolKit
# =============================================================================
#
# SYNOPSIS
#   Folder mode : run_disco.sh -l DIR   -o OUTDIR [options]
#   CSV mode    : run_disco.sh -l FILE  -o OUTDIR [options]
#   BIDS mode   : run_disco.sh -B ROOT            [options]
#
# DESCRIPTION
#   Runs the BCBToolKit structural disconnectome pipeline on one or more lesion
#   masks in MNI space. For each lesion, every tractography file (*.trk) in the
#   atlas is tested for overlap; the fraction of overlapping tracts is written
#   to a probabilistic disconnectome map.
#
#   This script can be called from any working directory. All tool and library
#   paths are resolved relative to this script's own location (the BCBToolKit
#   root). To override, set the environment variable BCBTOOLKIT_ROOT.
#
# INPUT MODES  (mutually exclusive — exactly one is required)
#
#   -l DIR    Folder mode.
#             All *.nii and *.nii.gz files directly inside DIR are processed.
#             Output stem = input filename stem.
#             Example: lesion_A.nii.gz  →  OUTDIR/lesion_A.nii.gz
#
#   -l FILE   CSV/TSV mode.
#             FILE is a plain-text list of lesion paths, one per line.
#             Accepted formats:
#               /path/to/lesion.nii.gz
#               participant_id<TAB>/path/to/lesion.nii.gz
#               participant_id,/path/to/lesion.nii.gz
#             Lines starting with '#' are treated as comments.
#             An optional header line is auto-detected and skipped
#             (first non-comment line whose first field contains no '.nii').
#             Relative paths are resolved from FILE's own directory.
#             Output stem = participant_id (if given) or input filename stem.
#
#   -B ROOT   BIDS mode.
#             Recursively discovers NIfTI files inside any anat/ sub-directory
#             of ROOT whose basename matches the pattern(s) given with -p.
#             Default pattern: *lesion*.nii.gz and *lesion*.nii
#             Outputs are routed in-place:
#               ROOT/…/<participant_id>/features/lesion/<participant_id>_les_SDC.nii.gz
#             participant_id is taken from the subject directory name (BIDS
#             standard), so extra BIDS entities in the filename are ignored.
#             The -o flag is ignored in this mode. Compatible with the EBRAINS
#             WP2 BIDS-like structure (nested center_id/dataset/participant_id)
#             as well as flat BIDS (participant_id directly under root).
#
# OPTIONS
#   -o OUTDIR   Output directory (required with -l; ignored with -B)
#   -t THR      Proportional threshold applied to the final map, value in [0,1]
#               Default: 0  (no thresholding — every connected tract is counted)
#   -n NCORES   Number of lesions processed in parallel
#               Default: nCPUs − 1, minimum 1
#   -T TRKDIR   Path to a directory of *.trk tractography atlas files
#               Default: <BCBToolKit_root>/Tools/extraFiles/tracks
#   -p PATTERN  Filename glob matched against files inside anat/ directories
#               in BIDS mode. May be repeated; files matching ANY pattern are
#               included (OR logic). Applies only with -B.
#               Default: "*lesion*.nii.gz"  "*lesion*.nii"
#               Example: -p "*space-MNI152NLin2009cAsym*lesion*mask.nii.gz"
#               Example: -p "*_lesion.nii.gz" -p "*_label-lesion_mask.nii.gz"
#   -w TMPDIR   Directory used for intermediate per-subject working files.
#               Default: $TMPDIR/bcb_disco_<PID>  (falls back to /tmp if
#               $TMPDIR is unset). Set this if the default location is on a
#               filesystem you cannot write to, or to control where scratch
#               data lands (e.g. a fast local scratch partition on a cluster).
#               The directory is created automatically and deleted on exit.
#   -d          Dry-run. Discover all inputs, print the execution plan, and
#               exit without running anything. Use this to verify path mappings
#               before a long batch job.
#
# REQUIREMENTS
#   • bash ≥ 4.3  (for mapfile / process substitution)
#   • Lesion masks must be registered to MNI space and at the same resolution
#     as the tractography atlas. The bundled 1 mm atlas uses the FSL MNI152
#     template (182×218×182 voxels). Masks produced by SPM-based pipelines are
#     commonly in the ICBM MNI152 template (181×217×181 voxels). This
#     one-voxel difference is detected automatically: the mask is resliced to
#     FSL space before processing and the disconnectome is resliced back
#     afterwards, so no manual intervention is required for this case.
#     Other resolution mismatches (e.g. 2 mm masks with a 1 mm atlas) are not
#     handled automatically and will cause track_vis to fail.
#
# EXAMPLES
#   ./run_disco.sh -l Lesions/ -o /tmp/results
#   ./run_disco.sh -l Lesions/ -o /tmp/results -T /data/HCP_tracks -t 0.05
#   ./run_disco.sh -l subjects.tsv -o /tmp/results -d   # dry run first
#   ./run_disco.sh -l subjects.tsv -o /tmp/results
#   ./run_disco.sh -B /data/Clinical_connectome -d
#   ./run_disco.sh -B /data/Clinical_connectome -T /data/HCP_tracks
#
# PARALLELISM
#   Subjects are parallelised with a FIFO bash job pool (no xargs). Each
#   subject's stdout/stderr is captured in OUTDIR/logs/<stem>.txt (folder/CSV
#   mode) or <participant_dir>/features/lesion/logs/<id>_les_SDC.txt (BIDS).
#   The script exits with code 1 if any subject failed.
# =============================================================================

set -uo pipefail

# ---------------------------------------------------------------------------
# 0. Locate BCBToolKit root
# ---------------------------------------------------------------------------
# BCBTOOLKIT_ROOT can be set externally (e.g. when the script is called via a
# symlink from a different location).
if [[ -n "${BCBTOOLKIT_ROOT:-}" ]]; then
    SCRIPT_DIR="$(cd "$BCBTOOLKIT_ROOT" && pwd)" \
        || { echo "Error: BCBTOOLKIT_ROOT does not exist: $BCBTOOLKIT_ROOT" >&2; exit 1; }
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# ---------------------------------------------------------------------------
# 1. Usage
# ---------------------------------------------------------------------------
usage() {
    sed -n '/^# SYNOPSIS/,/^# ====/{ /^# ====/d; s/^# \{0,1\}//; p }' \
        "${BASH_SOURCE[0]}" | head -60
    exit 1
}

# ---------------------------------------------------------------------------
# 2. Parse arguments
# ---------------------------------------------------------------------------
INPUT_ARG=""    # value of -l
BIDS_ROOT=""    # value of -B
OUTPUT_DIR=""   # value of -o
THRESHOLD=0
NCORES=""
TRACKS_DIR="$SCRIPT_DIR/Tools/extraFiles/tracks"
BIDS_PATTERNS=()  # value(s) of -p; empty = use built-in defaults
WORK_DIR_ARG=""   # value of -w; empty = use default
DRY_RUN=false

while getopts ":l:B:o:t:n:T:p:w:dh" opt; do
    case "$opt" in
        l) INPUT_ARG="$OPTARG" ;;
        B) BIDS_ROOT="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        t) THRESHOLD="$OPTARG" ;;
        n) NCORES="$OPTARG" ;;
        T) TRACKS_DIR="$OPTARG" ;;
        p) BIDS_PATTERNS+=("$OPTARG") ;;
        w) WORK_DIR_ARG="$OPTARG" ;;
        d) DRY_RUN=true ;;
        h) usage ;;
        :) echo "Error: -$OPTARG requires an argument." >&2; usage ;;
        *) echo "Error: unknown option -$OPTARG." >&2;      usage ;;
    esac
done

# Exactly one input mode must be given
if [[ -n "$INPUT_ARG" && -n "$BIDS_ROOT" ]]; then
    echo "Error: -l and -B are mutually exclusive." >&2; exit 1
fi
if [[ -z "$INPUT_ARG" && -z "$BIDS_ROOT" ]]; then
    echo "Error: one of -l or -B is required." >&2; usage
fi
if [[ -n "$INPUT_ARG" && -z "$OUTPUT_DIR" ]]; then
    echo "Error: -o OUTPUT_DIR is required when using -l." >&2; usage
fi

# ---------------------------------------------------------------------------
# 3. Resolve and validate common paths
# ---------------------------------------------------------------------------

# Resolve an existing directory to its absolute path, assigning the result
# directly into the named variable. Exits the MAIN script on failure.
# Using printf -v (not echo + $(...)) ensures exit 1 propagates correctly —
# command substitution $(...) only exits the subshell, not the parent.
resolve_dir() {
    local label="$1" path="$2" varname="$3"
    local resolved
    if ! resolved="$(cd "$path" 2>/dev/null && pwd)"; then
        echo "Error: $label not found: $path" >&2
        exit 1
    fi
    printf -v "$varname" '%s' "$resolved"
}

# Ensure output directory exists and resolve it the same way.
resolve_or_create_dir() {
    local label="$1" path="$2" varname="$3"
    if ! mkdir -p "$path" 2>/dev/null; then
        echo "Error: cannot create $label: $path" >&2
        exit 1
    fi
    resolve_dir "$label" "$path" "$varname"
}

resolve_dir "tracks folder" "$TRACKS_DIR" TRACKS_DIR

# Count tracks early so we can abort before any work starts
n_tracks=$(find "$TRACKS_DIR" -maxdepth 1 -name "*.trk" | wc -l)
[[ $n_tracks -eq 0 ]] && { echo "Error: no *.trk files in $TRACKS_DIR" >&2; exit 1; }

# Bundled tool paths (FSL subset + track_vis, all inside BCBToolKit)
BIN="$SCRIPT_DIR/Tools/binaries/bin"
LIB="$SCRIPT_DIR/Tools/libraries/lib"

# Temporary working directory for intermediate per-subject files.
# Prefer the caller-supplied -w path; otherwise use $TMPDIR (set by most
# cluster schedulers to a per-job scratch area) or fall back to /tmp.
if [[ -n "$WORK_DIR_ARG" ]]; then
    TMP="$WORK_DIR_ARG/bcb_disco_$$"
else
    TMP="${TMPDIR:-/tmp}/bcb_disco_$$"
fi

[[ -d "$BIN" ]] || { echo "Error: binaries not found at $BIN" >&2; exit 1; }

# Prepend bundled bin and lib so they take priority without clobbering PATH
export PATH="$BIN:$PATH"
export LD_LIBRARY_PATH="$LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# FSL environment (required by fslmaths / fslcpgeom / fslhd and wrappers)
export FSLDIR="$BIN/.."   # fslinfo/fslhd wrappers call ${FSLDIR}/bin/fslhd
export FSLOUTPUTTYPE="NIFTI_GZ"
export FSLLOCKDIR="" FSLMACHINELIST="" FSLMULTIFILEQUIT="TRUE" FSLREMOTECALL=""

# ---------------------------------------------------------------------------
# 4. Auto-detect number of cores
# ---------------------------------------------------------------------------
if [[ -z "$NCORES" ]]; then
    NCORES=$(getconf _NPROCESSORS_ONLN 2>/dev/null \
          || sysctl -n hw.ncpu      2>/dev/null \
          || echo 2)
    (( NCORES > 1 )) && NCORES=$(( NCORES - 1 )) || NCORES=1
fi

# ---------------------------------------------------------------------------
# 5. Input discovery functions
# ---------------------------------------------------------------------------
# All three functions emit lines of the form:
#   LESION_ABSOLUTE_PATH|OUTPUT_STEM_ABSOLUTE_PATH
# where OUTPUT_STEM has no .nii.gz extension.

# -- 5a. Folder mode ---------------------------------------------------------
discover_folder() {
    local dir="$1" outdir="$2"
    local lesion name stem
    while IFS= read -r lesion; do
        name="$(basename "$lesion")"
        stem="${name%.nii.gz}"; stem="${stem%.nii}"
        echo "$lesion|$outdir/$stem"
    done < <(find "$dir" -maxdepth 1 \( -name "*.nii" -o -name "*.nii.gz" \) \
             -type f | sort)
}

# -- 5b. CSV / TSV mode ------------------------------------------------------
# Accepts:
#   single-column  :  /path/to/lesion.nii.gz
#   two-column     :  participant_id<SEP>/path/to/lesion.nii.gz
# where SEP is tab or comma. Optional header auto-detected.
discover_csv() {
    local csv_file="$1" outdir="$2"
    local csv_dir line_num=0 header_checked=false

    csv_dir="$(cd "$(dirname "$csv_file")" && pwd)"

    while IFS=$'\t,' read -r col1 col2 _rest; do
        line_num=$(( line_num + 1 ))

        # Skip blank lines and comment lines
        [[ -z "${col1// /}" || "$col1" == \#* ]] && continue

        # Auto-detect header: first non-comment line where neither column
        # looks like a NIfTI path is treated as a header and skipped once.
        if [[ $header_checked == false ]]; then
            header_checked=true
            if [[ "$col1" != *.nii    && "$col1" != *.nii.gz &&
                  "${col2:-}" != *.nii && "${col2:-}" != *.nii.gz ]]; then
                continue   # skip header row
            fi
        fi

        # Assign participant_id and lesion path
        local participant_id="" lesion_path=""
        if [[ -n "$col2" ]]; then
            participant_id="$col1"
            lesion_path="$col2"
        else
            lesion_path="$col1"
        fi

        # Remove any surrounding whitespace from path
        lesion_path="${lesion_path#"${lesion_path%%[! ]*}"}"
        lesion_path="${lesion_path%"${lesion_path##*[! ]}"}"

        # Resolve relative paths against the CSV file's directory
        [[ "$lesion_path" != /* ]] && lesion_path="$csv_dir/$lesion_path"

        # Canonicalise (verifies file exists)
        local abs_lesion
        abs_lesion="$(cd "$(dirname "$lesion_path")" 2>/dev/null && pwd)/$(basename "$lesion_path")"
        if [[ ! -f "$abs_lesion" ]]; then
            echo "Warning: file not found at line $line_num: $lesion_path" >&2
            continue
        fi

        # Derive output stem from participant_id (if given) or filename
        local stem
        if [[ -n "$participant_id" ]]; then
            stem="$participant_id"
        else
            stem="$(basename "$abs_lesion")"
            stem="${stem%.nii.gz}"; stem="${stem%.nii}"
        fi

        echo "$abs_lesion|$outdir/$stem"
    done < "$csv_file"
}

# -- 5c. BIDS mode -----------------------------------------------------------
# Discovers NIfTI files under anat/ directories whose basenames match one or
# more glob patterns.  Patterns come from the global BIDS_PATTERNS array
# (populated by -p flags).  When the array is empty the built-in defaults are
# used:  "*lesion*.nii.gz"  and  "*lesion*.nii"
# These cover both the minimal BIDS convention:
#   <participant_id>_lesion.nii.gz
# and derivative pipelines that add BIDS entities, e.g.:
#   <participant_id>_space-MNI152NLin2009cAsym_label-lesion_mask.nii.gz
#
# participant_id is taken from the subject directory name (BIDS standard),
# not from the filename, so extra BIDS entities in the stem do not matter.
# Outputs to: ROOT/…/<participant_id>/features/lesion/<participant_id>_les_SDC
discover_bids() {
    local root="$1"
    local lesion anat_dir participant_dir participant_id out_stem

    # Build find -name conditions: one per pattern, joined with -o.
    # We must wrap the whole group in \( … \) so -type f applies to all.
    local -a name_conds=()
    if [[ ${#BIDS_PATTERNS[@]} -eq 0 ]]; then
        # Built-in defaults: any NIfTI whose name contains "lesion"
        name_conds=( -name "*lesion*.nii.gz" -o -name "*lesion*.nii" )
    else
        local first=true
        for pat in "${BIDS_PATTERNS[@]}"; do
            $first || name_conds+=( -o )
            name_conds+=( -name "$pat" )
            first=false
        done
    fi

    while IFS= read -r lesion; do
        anat_dir="$(dirname "$lesion")"
        participant_dir="$(dirname "$anat_dir")"

        # Derive participant_id from the subject directory name (BIDS standard).
        # This is robust to any extra BIDS entities in the filename.
        participant_id="$(basename "$participant_dir")"

        out_stem="$participant_dir/features/lesion/${participant_id}_les_SDC"

        echo "$lesion|$out_stem"
    done < <(find "$root" -path "*/anat/*" \( "${name_conds[@]}" \) \
                  -type f 2>/dev/null | sort)
}

# ---------------------------------------------------------------------------
# 6. Build the work list
# ---------------------------------------------------------------------------
declare -a INPUT_LESIONS=()   # parallel arrays: input NIfTI paths
declare -a OUTPUT_STEMS=()    # and their corresponding output stems

if [[ -n "$BIDS_ROOT" ]]; then
    # BIDS mode: resolve root, discover inputs, write outputs in-place
    resolve_dir "BIDS root" "$BIDS_ROOT" BIDS_ROOT
    while IFS='|' read -r lesion stem; do
        INPUT_LESIONS+=("$lesion")
        OUTPUT_STEMS+=("$stem")
    done < <(discover_bids "$BIDS_ROOT")

elif [[ -f "$INPUT_ARG" ]]; then
    # CSV mode: INPUT_ARG points to a file
    INPUT_FILE="$(cd "$(dirname "$INPUT_ARG")" && pwd)/$(basename "$INPUT_ARG")"
    resolve_or_create_dir "output directory" "$OUTPUT_DIR" OUTPUT_DIR
    while IFS='|' read -r lesion stem; do
        INPUT_LESIONS+=("$lesion")
        OUTPUT_STEMS+=("$stem")
    done < <(discover_csv "$INPUT_FILE" "$OUTPUT_DIR")

elif [[ -d "$INPUT_ARG" ]]; then
    # Folder mode
    LESIONS_DIR=""
    resolve_dir "lesions folder" "$INPUT_ARG" LESIONS_DIR
    resolve_or_create_dir "output directory" "$OUTPUT_DIR" OUTPUT_DIR
    [[ "$LESIONS_DIR" == "$OUTPUT_DIR" ]] && \
        { echo "Error: lesions and output directories must differ." >&2; exit 1; }
    while IFS='|' read -r lesion stem; do
        INPUT_LESIONS+=("$lesion")
        OUTPUT_STEMS+=("$stem")
    done < <(discover_folder "$LESIONS_DIR" "$OUTPUT_DIR")

else
    echo "Error: -l argument is neither an existing file nor directory: $INPUT_ARG" >&2
    exit 1
fi

if [[ ${#INPUT_LESIONS[@]} -eq 0 ]]; then
    echo "Error: no lesion files discovered. Check your input path." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 7. Print execution plan (always shown; -d exits here)
# ---------------------------------------------------------------------------
echo ""
echo "════════════════════════════════════════════════════════"
echo "  BCBToolKit — Disconnectome Maps"
echo "────────────────────────────────────────────────────────"
echo "  Subjects : ${#INPUT_LESIONS[@]}"
echo "  Tracks   : $n_tracks *.trk files"
echo "  Atlas    : $TRACKS_DIR"
echo "  Threshold: $THRESHOLD"
echo "  Jobs     : $NCORES parallel"
echo "  Temp dir : $TMP"
if [[ -n "$BIDS_ROOT" ]]; then
    if [[ ${#BIDS_PATTERNS[@]} -eq 0 ]]; then
        echo "  Patterns : *lesion*.nii.gz  *lesion*.nii  (defaults)"
    else
        echo "  Patterns : ${BIDS_PATTERNS[*]}"
    fi
fi
[[ $DRY_RUN == true ]] && echo "  Mode     : DRY RUN — nothing will be executed"
echo "────────────────────────────────────────────────────────"
printf "  %-50s  %s\n" "INPUT" "OUTPUT STEM"
echo "────────────────────────────────────────────────────────"
for i in "${!INPUT_LESIONS[@]}"; do
    # Truncate long paths for display only.
    # Note: ${string: -N} in bash returns EMPTY (not the full string) when
    # the string is shorter than N chars, so we must check length explicitly.
    # Also: do NOT use 'local' here — we are not inside a function.
    _disp_in="${INPUT_LESIONS[$i]}"
    _disp_out="${OUTPUT_STEMS[$i]}"
    [[ ${#_disp_in}  -gt 47 ]] && _show_in="…${_disp_in: -47}"  || _show_in="  $_disp_in"
    [[ ${#_disp_out} -gt 47 ]] && _show_out="…${_disp_out: -47}" || _show_out="  $_disp_out"
    printf "  %-50s  %s\n" "$_show_in" "$_show_out"
done
echo "════════════════════════════════════════════════════════"
echo ""

if [[ $DRY_RUN == true ]]; then
    echo "Dry run complete. Re-run without -d to execute."
    exit 0
fi

# ---------------------------------------------------------------------------
# 8. Per-lesion worker
# ---------------------------------------------------------------------------
# Called as a background subshell: run_one <lesion> <out_stem>
# All output goes to a log file next to the output.
run_one() {
    local lesion="$1"
    local out_stem="$2"
    local out_dir name log_dir log

    out_dir="$(dirname "$out_stem")"
    name="$(basename "$out_stem")"
    log_dir="$out_dir/logs"
    log="$log_dir/${name}.txt"

    # Per-subject temp directory inside the global TMP tree
    local subj_tmp="$TMP/$name"

    mkdir -p "$out_dir" "$log_dir" "$subj_tmp"

    # acc: accumulates the sum of binary tract masks across all tracts
    local acc="$subj_tmp/acc"

    # Detect the SPM/FSL 1-voxel MNI template mismatch (181×217×181 vs
    # 182×218×182). Read dims from the NIfTI header via the bundled fslhd.
    local les_d1 les_d2 les_d3
    read les_d1 les_d2 les_d3 <<< \
        "$("$BIN/fslhd" "$lesion" | awk '/^dim[123]/{print $2}' | tr '\n' ' ')"
    local needs_reslice=false
    if [[ "$les_d1" == "181" && "$les_d2" == "217" && "$les_d3" == "181" ]]; then
        needs_reslice=true
    fi

    (
        set -x

        # ------------------------------------------------------------------
        # If the lesion is in SPM MNI space (181×217×181), reslice it to
        # FSL MNI space (182×218×182) so track_vis can read it as an ROI.
        # nulldeform.mat is the identity matrix — no transformation is
        # applied, only the voxel grid is resampled to match MNI152.nii.gz.
        # ------------------------------------------------------------------
        local lesion_for_disco="$lesion"
        if [[ $needs_reslice == true ]]; then
            local resliced_lesion="$subj_tmp/lesion_resliced.nii.gz"
            echo "Note: lesion is 181x217x181 (SPM MNI); reslicing to 182x218x182 (FSL MNI) for track_vis."
            "$BIN/flirt" \
                -in      "$lesion" \
                -ref     "$SCRIPT_DIR/Tools/extraFiles/MNI152.nii.gz" \
                -out     "$resliced_lesion" \
                -applyxfm -init "$SCRIPT_DIR/Tools/extraFiles/nulldeform.mat" \
                -interp  nearestneighbour
            lesion_for_disco="$resliced_lesion"
        fi

        "$BIN/fslmaths" "$lesion_for_disco" -mul 0 "$acc"

        local num=0
        local tmp_mask="$subj_tmp/tmp_tracto"

        for t in "$TRACKS_DIR"/*.trk; do
            # Extract the subset of streamlines that pass through the lesion ROI.
            # -l 25 250 : keep only streamlines between 25 and 250 mm long
            # -nr       : do not render (headless, no display required)
            # -disable_log : suppress track_vis's own verbose log
            "$BIN/track_vis" "$t" -l 25 250 -roi "$lesion_for_disco" -ov "$tmp_mask" \
                -nr -disable_log

            # Binarise the tract mask and add to accumulator
            "$BIN/fslmaths" "$tmp_mask" -bin -add "$acc" "$acc"
            num=$(( num + 1 ))
        done

        # Divide by tract count → probabilistic disconnectome map in [0, 1]
        "$BIN/fslmaths" "$acc" -div "$num" "$out_stem"

        # Apply threshold (0 = keep all voxels with any disconnection signal)
        "$BIN/fslmaths" "$out_stem" -thr "$THRESHOLD" "$out_stem"

        # If the lesion was resliced, bring the disconnectome back to the
        # original SPM MNI space (181×217×181) using the original lesion as
        # the reference grid. Trilinear interpolation preserves the continuous
        # values of the probabilistic map.
        if [[ $needs_reslice == true ]]; then
            echo "Note: reslicing disconnectome back to original lesion space (181x217x181)."
            "$BIN/flirt" \
                -in      "$out_stem" \
                -ref     "$lesion" \
                -out     "$out_stem" \
                -applyxfm -init "$SCRIPT_DIR/Tools/extraFiles/nulldeform.mat" \
                -interp  trilinear
        fi

        # Copy spatial metadata (qform/sform) from the source lesion
        "$BIN/fslcpgeom" "$lesion" "$out_stem"

        # Clean up per-subject temp files
        rm -rf "$subj_tmp"

    ) >> "$log" 2>&1

    local rc=$?
    if [[ $rc -eq 0 ]]; then
        echo "  [done]  $name"
    else
        echo "  [FAIL]  $name  (see $log)"
    fi
    return $rc
}

# ---------------------------------------------------------------------------
# 9. Parallel FIFO job pool
# ---------------------------------------------------------------------------
# Launches up to NCORES background jobs. When the pool is full we wait for the
# oldest job to finish before launching the next one (FIFO order). This avoids
# the early-termination race condition in "xargs -I{} -P N".
mkdir -p "$TMP" || { echo "Error: cannot create temp directory: $TMP" >&2; exit 1; }
# Ensure the temp tree is removed on exit (normal, error, or Ctrl-C).
trap 'rm -rf "$TMP"' EXIT

declare -a PIDS=()
declare -i FAIL_COUNT=0

for i in "${!INPUT_LESIONS[@]}"; do
    run_one "${INPUT_LESIONS[$i]}" "${OUTPUT_STEMS[$i]}" &
    PIDS+=($!)

    # Pool is full: wait for the oldest job before launching the next
    if (( ${#PIDS[@]} >= NCORES )); then
        wait "${PIDS[0]}" || FAIL_COUNT+=1
        PIDS=("${PIDS[@]:1}")   # pop oldest PID
    fi
done

# Drain remaining jobs
for pid in "${PIDS[@]}"; do
    wait "$pid" || FAIL_COUNT+=1
done

# ---------------------------------------------------------------------------
# 10. Summary
# ---------------------------------------------------------------------------
echo ""
echo "════════════════════════════════════════════════════════"
if (( FAIL_COUNT == 0 )); then
    echo "  Completed successfully: ${#INPUT_LESIONS[@]} / ${#INPUT_LESIONS[@]} subjects"
else
    _ok=$(( ${#INPUT_LESIONS[@]} - FAIL_COUNT ))
    echo "  Completed: $_ok / ${#INPUT_LESIONS[@]} subjects"
    echo "  Failed   : $FAIL_COUNT subject(s) — check log files for details."
fi
echo "════════════════════════════════════════════════════════"
echo ""

(( FAIL_COUNT > 0 )) && exit 1 || exit 0
