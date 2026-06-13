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
