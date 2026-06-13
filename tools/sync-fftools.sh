#!/bin/bash

set -euo pipefail

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${BASEDIR}/src/ffmpeg/fftools"

TARGET_DIRS=(
  "${BASEDIR}/apple/src"
  "${BASEDIR}/linux/src"
  "${BASEDIR}/android/ffmpeg-kit-android-lib/src/main/cpp"
)

ROOT_FILES=(
  cmdutils.c
  cmdutils.h
  ffmpeg.c
  ffmpeg.h
  ffmpeg_dec.c
  ffmpeg_demux.c
  ffmpeg_enc.c
  ffmpeg_filter.c
  ffmpeg_hw.c
  ffmpeg_mux.c
  ffmpeg_mux.h
  ffmpeg_mux_init.c
  ffmpeg_opt.c
  ffmpeg_sched.c
  ffmpeg_sched.h
  ffmpeg_utils.h
  ffprobe.c
  fopen_utf8.h
  opt_common.c
  opt_common.h
  sync_queue.c
  sync_queue.h
  thread_queue.c
  thread_queue.h
)

TEXTFORMAT_FILES=(
  avtextformat.c
  avtextformat.h
  avtextwriters.h
  tf_compact.c
  tf_default.c
  tf_flat.c
  tf_ini.c
  tf_internal.h
  tf_json.c
  tf_mermaid.c
  tf_mermaid.h
  tf_xml.c
  tw_avio.c
  tw_buffer.c
  tw_stdout.c
)

rename_root_file() {
  local file="$1"
  echo "fftools_${file}"
}

rewrite_common_includes() {
  local file="$1"

  perl -0pi -e '
    s/#include "cmdutils\.h"/#include "fftools_cmdutils.h"/g;
    s/#include "ffmpeg\.h"/#include "fftools_ffmpeg.h"/g;
    s/#include "ffmpeg_dec\.c"/#include "fftools_ffmpeg_dec.c"/g;
    s/#include "ffmpeg_demux\.c"/#include "fftools_ffmpeg_demux.c"/g;
    s/#include "ffmpeg_enc\.c"/#include "fftools_ffmpeg_enc.c"/g;
    s/#include "ffmpeg_filter\.c"/#include "fftools_ffmpeg_filter.c"/g;
    s/#include "ffmpeg_hw\.c"/#include "fftools_ffmpeg_hw.c"/g;
    s/#include "ffmpeg_mux\.h"/#include "fftools_ffmpeg_mux.h"/g;
    s/#include "ffmpeg_mux\.c"/#include "fftools_ffmpeg_mux.c"/g;
    s/#include "ffmpeg_mux_init\.c"/#include "fftools_ffmpeg_mux_init.c"/g;
    s/#include "ffmpeg_opt\.c"/#include "fftools_ffmpeg_opt.c"/g;
    s/#include "ffmpeg_sched\.h"/#include "fftools_ffmpeg_sched.h"/g;
    s/#include "ffmpeg_utils\.h"/#include "fftools_ffmpeg_utils.h"/g;
    s/#include "fopen_utf8\.h"/#include "fftools_fopen_utf8.h"/g;
    s/#include "opt_common\.h"/#include "fftools_opt_common.h"/g;
    s/#include "sync_queue\.h"/#include "fftools_sync_queue.h"/g;
    s/#include "thread_queue\.h"/#include "fftools_thread_queue.h"/g;
  ' "$file"
}

patch_cmdutils_header() {
  local file="$1"

  perl -0pi -e '
    s/extern const char program_name\[\];/extern __thread char *program_name;/;
    s/extern const int program_birth_year;/extern __thread int program_birth_year;/;
    s/void show_help_default\(const char \*opt, const char \*arg\);/extern __thread void (*show_help_default_callback)(const char *opt, const char *arg);\nvoid ffmpeg_show_help_default(const char *opt, const char *arg);\nvoid ffprobe_show_help_default(const char *opt, const char *arg);/;
    s/#ifdef _WIN32\n#undef main \/\* We don.t want SDL to override our main\(\) \*\/\n#endif/#ifdef _WIN32\n#undef main \/\* We don.t want SDL to override our main() *\/\n#endif\n\n#define AV_LOG_STDERR    -16/s;
  ' "$file"
}

patch_cmdutils_source() {
  local file="$1"

  perl -0pi -e '
    s/#include "compat\/va_copy\.h"/#include <stdarg.h>\n#ifndef va_copy\n#define va_copy(dst, src) __va_copy(dst, src)\n#endif/s;
    s/(#include "fftools_opt_common\.h"\n)/$1\n__thread char *program_name = NULL;\n__thread int program_birth_year = 0;\n__thread void (*show_help_default_callback)(const char *opt, const char *arg) = NULL;\n/s;
  ' "$file"
}

patch_ffmpeg_header() {
  local file="$1"

  perl -0pi -e '
    s/\n#endif \/\* FFTOOLS_FFMPEG_H \*\//\nvoid set_report_callback(void (*callback)(int, float, float, int64_t, double, double, double));\nvoid cancel_operation(long id);\n\n#endif \/\* FFTOOLS_FFMPEG_H \*\//s;
  ' "$file"
}

patch_ffmpeg_source() {
  local file="$1"

  perl -0pi -e '
    s/const char program_name\[\] = "ffmpeg";\nconst int program_birth_year = 2000;\n//s;
    s/FILE \*vstats_file;\n/FILE *vstats_file;\nstatic void (*ffmpegkit_report_callback)(int, float, float, int64_t, double, double, double) = NULL;\n/s;
    s/static void print_report\(int is_last_report, int64_t timer_start, int64_t cur_time, int64_t pts\)\n\{\n/static void print_report(int is_last_report, int64_t timer_start, int64_t cur_time, int64_t pts)\n{\n    uint64_t report_frame_number = 0;\n    float report_fps = 0.0f;\n    float report_q = -1.0f;\n/s;
    s/fps = t > 1 \? frame_number \/ t : 0;\n/fps = t > 1 ? frame_number \/ t : 0;\n            report_frame_number = frame_number;\n            report_fps = fps;\n            report_q = q;\n/s;
    s/if \(print_stats \|\| is_last_report\) \{\n/if (ffmpegkit_report_callback && report_frame_number) {\n        ffmpegkit_report_callback((int)report_frame_number, report_fps, report_q, total_size,\n                                  pts == AV_NOPTS_VALUE ? 0.0 : (double)pts \/ 1000.0,\n                                  bitrate, speed);\n    }\n\n    if (print_stats || is_last_report) {\n/s;
    s/int main\(int argc, char \*\*argv\)\n\{\n/int ffmpeg_execute(int argc, char **argv)\n{\n    static char ffmpegkit_program_name[] = "ffmpeg";\n    program_name = ffmpegkit_program_name;\n    program_birth_year = 2000;\n    show_help_default_callback = ffmpeg_show_help_default;\n\n/s;
    s/int ffmpeg_execute\(int argc, char \*\*argv\)\n\{\n/int ffmpeg_execute(int argc, char **argv)\n{\n/s;
    s/\nint ffmpeg_execute\(int argc, char \*\*argv\)\n/\nvoid set_report_callback(void (*callback)(int, float, float, int64_t, double, double, double))\n{\n    ffmpegkit_report_callback = callback;\n}\n\nvoid cancel_operation(long id)\n{\n    (void)id;\n    sigterm_handler(SIGINT);\n}\n\nint ffmpeg_execute(int argc, char **argv)\n/s;
  ' "$file"
}

patch_ffprobe_source() {
  local file="$1"

  perl -0pi -e '
    s/const char program_name\[\] = "ffprobe";\nconst int program_birth_year = 2007;\n//s;
    s/void show_help_default\(const char \*opt, const char \*arg\)/void ffprobe_show_help_default(const char *opt, const char *arg)/g;
    s/int main\(int argc, char \*\*argv\)\n\{\n/int ffprobe_execute(int argc, char **argv)\n{\n    static char ffmpegkit_program_name[] = "ffprobe";\n    program_name = ffmpegkit_program_name;\n    program_birth_year = 2007;\n    show_help_default_callback = ffprobe_show_help_default;\n\n/s;
  ' "$file"
}

patch_ffmpeg_opt_source() {
  local file="$1"

  perl -0pi -e '
    s/void show_help_default\(const char \*opt, const char \*arg\)/void ffmpeg_show_help_default(const char *opt, const char *arg)/g;
  ' "$file"
}

patch_opt_common_source() {
  local file="$1"

  perl -0pi -e '
    s/show_help_default\(topic, par\);/if (show_help_default_callback)\n        show_help_default_callback(topic, par);\n    else\n        av_log(NULL, AV_LOG_ERROR, "No tool-specific help callback registered.\\n");/g;
  ' "$file"
}

patch_ffmpeg_dec_source() {
  local file="$1"

  perl -0pi -e '
    s/#include <stdbit\.h>/#include <limits.h>\n#include <stdint.h>\n#if __has_include(<stdbit.h>)\n#include <stdbit.h>\n#else\nstatic inline unsigned stdc_count_ones(uintptr_t value)\n{\n    return value ? __builtin_popcountll((unsigned long long)value) : 0;\n}\n\nstatic inline unsigned stdc_trailing_zeros(uintptr_t value)\n{\n    return value ? __builtin_ctzll((unsigned long long)value) : (unsigned)(sizeof(value) * CHAR_BIT);\n}\n#endif/s;
  ' "$file"
}

write_graphprint_stub() {
  local target="$1"

  cat > "${target}/graph/graphprint.h" <<'EOF'
/*
 * Minimal graphprint compatibility shim for ffmpeg-kit builds.
 */

#ifndef FFTOOLS_GRAPH_GRAPHPRINT_H
#define FFTOOLS_GRAPH_GRAPHPRINT_H

#include "fftools_ffmpeg.h"

int print_filtergraphs(FilterGraph **graphs, int nb_graphs, InputFile **ifiles, int nb_ifiles,
                       OutputFile **ofiles, int nb_ofiles);
int print_filtergraph(FilterGraph *fg, AVFilterGraph *graph);

#endif /* FFTOOLS_GRAPH_GRAPHPRINT_H */
EOF

  cat > "${target}/graph/graphprint.c" <<'EOF'
/*
 * Minimal graphprint compatibility shim for ffmpeg-kit builds.
 */

#include "graphprint.h"

int print_filtergraphs(FilterGraph **graphs, int nb_graphs, InputFile **ifiles, int nb_ifiles,
                       OutputFile **ofiles, int nb_ofiles)
{
    (void)graphs;
    (void)nb_graphs;
    (void)ifiles;
    (void)nb_ifiles;
    (void)ofiles;
    (void)nb_ofiles;
    return 0;
}

int print_filtergraph(FilterGraph *fg, AVFilterGraph *graph)
{
    (void)fg;
    (void)graph;
    return 0;
}
EOF
}

sync_target() {
  local target="$1"
  local source_file dest_file

  mkdir -p "${target}/graph" "${target}/textformat"

  for source_file in "${ROOT_FILES[@]}"; do
    dest_file="${target}/$(rename_root_file "${source_file}")"
    cp "${SOURCE_DIR}/${source_file}" "${dest_file}"
    rewrite_common_includes "${dest_file}"
  done

  write_graphprint_stub "${target}"

  for source_file in "${TEXTFORMAT_FILES[@]}"; do
    cp "${SOURCE_DIR}/textformat/${source_file}" "${target}/textformat/${source_file}"
  done

  patch_cmdutils_header "${target}/fftools_cmdutils.h"
  patch_cmdutils_source "${target}/fftools_cmdutils.c"
  patch_ffmpeg_dec_source "${target}/fftools_ffmpeg_dec.c"
  patch_ffmpeg_header "${target}/fftools_ffmpeg.h"
  patch_ffmpeg_source "${target}/fftools_ffmpeg.c"
  patch_ffmpeg_opt_source "${target}/fftools_ffmpeg_opt.c"
  patch_ffprobe_source "${target}/fftools_ffprobe.c"
  patch_opt_common_source "${target}/fftools_opt_common.c"
}

for target_dir in "${TARGET_DIRS[@]}"; do
  sync_target "${target_dir}"
done
