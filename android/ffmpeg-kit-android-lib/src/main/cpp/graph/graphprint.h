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
