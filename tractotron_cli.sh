#!/usr/bin/env bash
# =============================================================================
# tractotron_cli.sh — Tractotron: lesion–tract overlap analysis
# =============================================================================
#
# SYNOPSIS
#   tractotron_cli.sh -l LESIONS_DIR -t TRACTS_DIR -o OUTPUT_DIR [options]
#
# DESCRIPTION
#   For each lesion mask in LESIONS_DIR and each tract atlas NIfTI in
#   TRACTS_DIR, computes two measures of lesion–tract overlap and writes them
#   as TSV matrices to OUTPUT_DIR:
#
#     probability.tsv  — peak value of (tract_probability × lesion) per cell.
#                        Reflects the highest tract probability at the lesion
#                        site. Values are in [0, 1].
#
#     proportion.tsv   — fraction of the binarised tract volume occupied by the
#                        lesion: lesion_voxels_within_tract / tract_voxels.
#                        Values are in [0, 1].
#
#   Rows = lesions, columns = tracts.
#
# OPTIONS
#   -l LESIONS_DIR   Directory of lesion masks (*.nii / *.nii.gz)
#   -t TRACTS_DIR    Directory of tract atlas NIfTIs (*.nii / *.nii.gz)
#   -o OUTPUT_DIR    Where to write probability.tsv and proportion.tsv
#   -T THR           Threshold for binarising tract probability maps
#                    Default: 0.5
#   -w TMPDIR        Writable scratch space for intermediate files.
#                    Default: $TMPDIR/bcb_tractotron_<PID> (falls back to /tmp)
#                    Use this on servers where the BCBToolKit directory is
#                    read-only or on a slow filesystem.
#   -F               Force use of bundled FSL even if system FSL is detected.
#   -g               Emit GUI progress signals (echo "#" after each tract).
#                    Enable when this script is invoked from the BCBToolKit GUI.
#   -d               Dry run: print execution plan and exit without processing.
#   -h               Show this help.
#
# FSL DETECTION
#   1. System FSL is used when $FSLDIR is set and $FSLDIR/bin/fslmaths exists.
#   2. Falls back to the FSL subset bundled in the BCBToolKit distribution.
#   3. -F forces the bundled FSL regardless of system FSL availability.
#
# EXAMPLES
#   tractotron_cli.sh -l Lesions/ -t Tracts/ -o results/
#   tractotron_cli.sh -l Lesions/ -t Tracts/ -o results/ -T 0.25
#   tractotron_cli.sh -l Lesions/ -t Tracts/ -o /tmp/results -d
#   tractotron_cli.sh -l Lesions/ -t Tracts/ -o results/ -w /scratch/me -F
# =============================================================================

set -uo pipefail

# ---------------------------------------------------------------------------
# 0. Locate BCBToolKit root
# ---------------------------------------------------------------------------
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
        "${BASH_SOURCE[0]}" | head -70
    exit 1
}

# ---------------------------------------------------------------------------
# 2. Parse arguments
# ---------------------------------------------------------------------------
LESIONS_DIR=""
TRACTS_DIR=""
OUTPUT_DIR=""
TRACT_THR="0.5"
WORK_DIR_ARG=""
FORCE_BUNDLED=false
GUI_PROGRESS=false
DRY_RUN=false

while getopts ":l:t:o:T:w:Fgdh" opt; do
    case "$opt" in
        l) LESIONS_DIR="$OPTARG" ;;
        t) TRACTS_DIR="$OPTARG"  ;;
        o) OUTPUT_DIR="$OPTARG"  ;;
        T) TRACT_THR="$OPTARG"   ;;
        w) WORK_DIR_ARG="$OPTARG" ;;
        F) FORCE_BUNDLED=true    ;;
        g) GUI_PROGRESS=true     ;;
        d) DRY_RUN=true          ;;
        h) usage ;;
        :) echo "Error: -$OPTARG requires an argument." >&2; usage ;;
        *) echo "Error: unknown option -$OPTARG." >&2;      usage ;;
    esac
done

[[ -z "$LESIONS_DIR" ]] && { echo "Error: -l LESIONS_DIR is required." >&2; usage; }
[[ -z "$TRACTS_DIR"  ]] && { echo "Error: -t TRACTS_DIR is required."  >&2; usage; }
[[ -z "$OUTPUT_DIR"  ]] && { echo "Error: -o OUTPUT_DIR is required."  >&2; usage; }

# ---------------------------------------------------------------------------
# 3. Resolve and validate paths
# ---------------------------------------------------------------------------
resolve_dir() {
    local label="$1" path="$2" varname="$3"
    local resolved
    if ! resolved="$(cd "$path" 2>/dev/null && pwd)"; then
        echo "Error: $label not found: $path" >&2; exit 1
    fi
    printf -v "$varname" '%s' "$resolved"
}

resolve_or_create_dir() {
    local label="$1" path="$2" varname="$3"
    if ! mkdir -p "$path" 2>/dev/null; then
        echo "Error: cannot create $label: $path" >&2; exit 1
    fi
    resolve_dir "$label" "$path" "$varname"
}

resolve_dir           "lesions directory" "$LESIONS_DIR" LESIONS_DIR
resolve_dir           "tracts directory"  "$TRACTS_DIR"  TRACTS_DIR
resolve_or_create_dir "output directory"  "$OUTPUT_DIR"  OUTPUT_DIR

# Collect input files
declare -a LESIONS=()
while IFS= read -r f; do LESIONS+=("$f"); done \
    < <(find "$LESIONS_DIR" -maxdepth 1 \( -name "*.nii.gz" -o -name "*.nii" \) \
        -type f | sort)

declare -a TRACTS=()
while IFS= read -r f; do TRACTS+=("$f"); done \
    < <(find "$TRACTS_DIR"  -maxdepth 1 \( -name "*.nii.gz" -o -name "*.nii" \) \
        -type f | sort)

[[ ${#LESIONS[@]} -eq 0 ]] && { echo "Error: no NIfTI files in $LESIONS_DIR" >&2; exit 1; }
[[ ${#TRACTS[@]}  -eq 0 ]] && { echo "Error: no NIfTI files in $TRACTS_DIR"  >&2; exit 1; }

# ---------------------------------------------------------------------------
# 4. Temp directory path (created later, after dry-run check)
# ---------------------------------------------------------------------------
if [[ -n "$WORK_DIR_ARG" ]]; then
    TMP="$WORK_DIR_ARG/bcb_tractotron_$$"
else
    TMP="${TMPDIR:-/tmp}/bcb_tractotron_$$"
fi

# ---------------------------------------------------------------------------
# 5. Detect FSL
# ---------------------------------------------------------------------------
FSL_SOURCE=""
FSLMATHS=""
FSLSTATS=""

if [[ "$FORCE_BUNDLED" == false \
      && -n "${FSLDIR:-}" \
      && -x "${FSLDIR}/bin/fslmaths" ]]; then
    FSLMATHS="${FSLDIR}/bin/fslmaths"
    FSLSTATS="${FSLDIR}/bin/fslstats"
    FSL_SOURCE="system (${FSLDIR})"
    export FSLOUTPUTTYPE="${FSLOUTPUTTYPE:-NIFTI_GZ}"
else
    _BUNDLED_BIN="$SCRIPT_DIR/Tools/binaries/bin"
    _BUNDLED_LIB="$SCRIPT_DIR/Tools/libraries/lib"
    if [[ ! -x "$_BUNDLED_BIN/fslmaths" ]]; then
        echo "Error: FSL not found." >&2
        echo "  Set \$FSLDIR to use system FSL, or ensure bundled binaries" >&2
        echo "  are present at $_BUNDLED_BIN" >&2
        exit 1
    fi
    export PATH="$_BUNDLED_BIN:$PATH"
    export LD_LIBRARY_PATH="$_BUNDLED_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export FSLDIR="$_BUNDLED_BIN/.."
    export FSLOUTPUTTYPE="NIFTI_GZ"
    export FSLLOCKDIR="" FSLMACHINELIST="" FSLMULTIFILEQUIT="TRUE" FSLREMOTECALL=""
    FSLMATHS="$_BUNDLED_BIN/fslmaths"
    FSLSTATS="$_BUNDLED_BIN/fslstats"
    FSL_SOURCE="bundled ($_BUNDLED_BIN)"
fi

# ---------------------------------------------------------------------------
# 6. Execution plan (always printed; -d exits here)
# ---------------------------------------------------------------------------
echo ""
echo "════════════════════════════════════════════════════════"
echo "  BCBToolKit — Tractotron"
echo "────────────────────────────────────────────────────────"
printf "  %-10s %d files\n"   "Lesions :" "${#LESIONS[@]}"
printf "  %-10s %d files\n"   "Tracts  :" "${#TRACTS[@]}"
printf "  %-10s %s\n"         "FSL     :" "$FSL_SOURCE"
printf "  %-10s %s\n"         "Threshold:" "$TRACT_THR"
printf "  %-10s %s\n"         "Output  :" "$OUTPUT_DIR"
printf "  %-10s %s\n"         "Temp    :" "$TMP"
[[ $DRY_RUN == true ]] && echo "  Mode    : DRY RUN — nothing will be executed"
echo "════════════════════════════════════════════════════════"
echo ""

if [[ $DRY_RUN == true ]]; then
    echo "Dry run complete. Re-run without -d to execute."
    exit 0
fi

# ---------------------------------------------------------------------------
# 7. Setup: temp dir, log, trap
# ---------------------------------------------------------------------------
mkdir -p "$TMP/tracts" \
    || { echo "Error: cannot create temp directory: $TMP" >&2; exit 1; }
trap 'rm -rf "$TMP"' EXIT

LOG="$OUTPUT_DIR/tractotron.log"
: > "$LOG"

# ---------------------------------------------------------------------------
# 8. Pre-compute binarised tract masks (once, reused for every lesion)
# ---------------------------------------------------------------------------
echo "Pre-processing ${#TRACTS[@]} tract masks (threshold: ${TRACT_THR})..."
for tract in "${TRACTS[@]}"; do
    tract_bin="$TMP/tracts/$(basename "$tract")"
    "$FSLMATHS" "$tract" -thr "$TRACT_THR" -bin "$tract_bin" >> "$LOG" 2>&1 \
        || { echo "Error: failed to pre-process tract: $(basename "$tract") — see $LOG" >&2
             exit 1; }
done
echo "Done."
echo ""

# ---------------------------------------------------------------------------
# 9. Write TSV headers (tract names as column headers)
# ---------------------------------------------------------------------------
PROBA_OUT="$OUTPUT_DIR/probability.tsv"
PROP_OUT="$OUTPUT_DIR/proportion.tsv"

header=$'\t'
for tract in "${TRACTS[@]}"; do
    t_name=$(basename "$tract")
    t_name="${t_name%.nii.gz}"; t_name="${t_name%.nii}"
    header+="${t_name}"$'\t'
done
header="${header%$'\t'}"   # strip trailing tab for clean TSV
printf '%s\n' "$header" | tee "$PROBA_OUT" > "$PROP_OUT"

# ---------------------------------------------------------------------------
# 10. Main loop: one lesion at a time
# ---------------------------------------------------------------------------
OVERLAP="$TMP/overlap"
n_lesions=${#LESIONS[@]}
n_done=0
n_failed=0

for lesion in "${LESIONS[@]}"; do
    les_name=$(basename "$lesion")
    les_name="${les_name%.nii.gz}"; les_name="${les_name%.nii}"

    n_done=$(( n_done + 1 ))
    echo "  [$n_done/$n_lesions]  $les_name"

    # Accumulate both rows as strings; write once when all tracts are done.
    # This avoids any risk of partial writes if the script is interrupted.
    proba_row="$les_name"
    prop_row="$les_name"
    failed=false

    for tract in "${TRACTS[@]}"; do
        tract_bin="$TMP/tracts/$(basename "$tract")"

        # ---- Probability: max value of (tract_probability × lesion) ----
        if ! "$FSLMATHS" "$tract_bin" -mul "$lesion" "$OVERLAP" >> "$LOG" 2>&1; then
            echo "  [FAIL] fslmaths on $les_name × $(basename "$tract") — see $LOG" >&2
            failed=true; break
        fi

        max=$("$FSLSTATS" "$OVERLAP" -R 2>> "$LOG" | awk '{print $2}')
        proba_row+=$'\t'"$max"

        # ---- Proportion: lesion voxels inside tract / total tract voxels ----
        tract_vol=$("$FSLSTATS" "$tract_bin" -V 2>> "$LOG" | awk '{print $1}')
        les_trac_vol=$("$FSLSTATS" "$lesion" -k "$tract_bin" -V 2>> "$LOG" \
                       | awk '{print $1}')

        if [[ -z "$tract_vol" || "$tract_vol" =~ ^0(\.0*)?$ ]]; then
            prop_row+=$'\t'0.000000
        else
            prop=$(LC_ALL=C awk "BEGIN {printf \"%.6f\", $les_trac_vol / $tract_vol}")
            prop_row+=$'\t'"$prop"
        fi

        if [[ "$GUI_PROGRESS" == true ]]; then echo "#"; fi
    done

    if [[ "$failed" == true ]]; then
        n_failed=$(( n_failed + 1 ))
        continue
    fi

    printf '%s\n' "$proba_row" >> "$PROBA_OUT"
    printf '%s\n' "$prop_row"  >> "$PROP_OUT"
done

# ---------------------------------------------------------------------------
# 11. Summary
# ---------------------------------------------------------------------------
n_ok=$(( n_done - n_failed ))
echo ""
echo "════════════════════════════════════════════════════════"
if (( n_failed == 0 )); then
    echo "  Completed: $n_ok / $n_lesions lesion(s) × ${#TRACTS[@]} tract(s)"
else
    echo "  Completed: $n_ok / $n_lesions lesion(s)"
    echo "  Failed   : $n_failed lesion(s) — check $LOG"
fi
echo "  Results  : $PROBA_OUT"
echo "             $PROP_OUT"
echo "  Log      : $LOG"
echo "════════════════════════════════════════════════════════"
echo ""

(( n_failed > 0 )) && exit 1 || exit 0
