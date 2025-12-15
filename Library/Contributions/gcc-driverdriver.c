/* Apple-originated file:  driver driver

Darwin driver program that handles -arch commands and invokes appropriate compiler driver.

Copyright (C) 2004, 2005 Free Software Foundation, Inc.  Modified 2025 by G. Steemson.

This file is an optional addendum to GCC.

GCC is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option) any later version.

GCC is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.  You should have
received a copy of the GNU General Public License along with GCC; see the file COPYING.  If not, it is available from the GNU
website at <http://www.gnu.org/>. */

#define DEBUG 1

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <mach-o/arch.h>
#ifndef CPU_TYPE_ARM  /* For whatever reason, this is commented out in the system headers prior to Leopard. */
# define CPU_TYPE_ARM ((cpu_type_t) 12)
#endif
#include <limits.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <regex.h>
#include "libiberty.h"
#include "filenames.h"
#include "stdbool.h"
/* Hack!  Pay the price for including darwin.h. */
typedef int tree;
typedef int rtx;
#define GTY(x) /* nothing */
#define USED_FOR_TARGET 1
#include "darwin.h"  /* For WORD_SWITCH_TAKES_ARG, and, at one time, SWITCH_TAKES_ARG. */
#ifndef SWITCH_TAKES_ARG
# define SWITCH_TAKES_ARG(CHAR) DEFAULT_SWITCH_TAKES_ARG(CHAR)
#endif
#include "gcc.h"     /* For DEFAULT_SWITCH_TAKES_ARG and DEFAULT_WORD_SWITCH_TAKES_ARG. */

/* Support at most 10 architectures at a time.  This is a historical limit. */
#define MAX_ARCHS 10

struct infile {
    const    char *name;
              int  index;
    struct infile *next;
};
struct name_map {
    const char *arch_name;
    const char *config_string;
};

/* Info about each subprocess.  Need one subprocess per arch, plus one more for 'lipo'. */
struct command {
    const char  *prog;
    const char **argv;
           int   pid;
} commands[MAX_ARCHS + 1];

/* Architecture names used by config.guess differ from those used by NXGetXXXX; this hand‐coded mapping connects them. */
struct name_map arch_config_map[] = {
    {"i386",   "i686"},
    {"ppc",    "powerpc"},
    {"ppc64",  "powerpc"},
    {"x86_64", "i686"},
    {"arm",    "arm"},  /* Note:  All supported ARM architectures must be listed here explicitly for error reporting to work. */
    {"armv4t", "arm"},
    {"armv5",  "arm"},
    {"xscale", "arm"},
    {"armv6",  "arm"},
    {"armv7",  "arm"},
    {NULL, NULL}
};

const    char  *progname;            /* This program's name. */
const    char  *driver_exec_prefix;  /* driver prefix. */
          int   prefix_len;          /* driver prefix length. */
         char  *curr_dir;            /* current working directory. */
const    char  *default_outfile    = "a.out";  /* Use if -o flag is absent. */
const    char  *archs[MAX_ARCHS];    /* Names of user-supplied architectures. */
static    int   num_archs;           /* "-arch"-option counter. */
struct infile  *in_files;
struct infile  *last_infile;
static    int   num_infiles;
const    char  *output_file        = NULL;  /* User-specified output file name. */
const    char **out_files;           /* Output file names for arch-specific driver */
static    int   num_outfiles;        /* invocation (input file names for 'lipo').  */
const    char **gcc_argv;            /* ARGV after processing, for the GCC driver. */
          int   gcc_argc;
const    char **archv;               /* A true entry i names the architecture gcc_argv[i] applies to; NULL (false) means "all". */
const    char **lipo_argv;           /* Argument list for 'lipo'. */
static    int   initial_argc;        /* Total number of arguments supplied by caller. */
static    int   greatest_status    = 0;
static    int   signal_count       = 0;
/* Flags for presence and/or absence of important command-line options: */
          int   compile_only_req   = 0;
          int   asm_output_req     = 0;
          int   capital_m_seen     = 0;
          int   preproc_output_req = 0;
          int   ima_is_used        = 0;  /* IMA… Input Module Aggregation?  Probably?  Hmmm. */
          int   dynamiclib_seen    = 0;
          int   verbose_flag       = 0;
          int   save_temps_seen    = 0;
          int   m32_seen           = 0;
          int   m64_seen           = 0;

/* Local function prototypes.  */
static const char *get_arch_name          (const char *);
static       char *get_driver_name        (const char *);
static       void  delete_out_files       (void);
static       char *basename_resuffix      (const char *, const char *);
static       void  initialize             (void);
static       void  final_cleanup          (void);
static        int  do_wait                (int, const char *);
static       void  do_lipo                (int, const char *);
static       void  do_compile             (int, const char **);
static       void  do_compile_separately  (void);
static       void  do_lipo_separately     (void);
static        int  filter_args_for_arch   (int, const char **, const char **, const char *);
static        int  flag_for_cpu           (int, const char **, int);
static        int  unflag_cpu             (const char **, int);
static       void  add_arch               (const char *);
static const char *resolve_symlink        (const char *, char *, int, int);
static const char *resolve_path_to_binary (const char *);
static        int  get_basename_len       (const char *);

/* Find the arch name for the given string.  If no string, get the local arch's name. */
static const char *
get_arch_name (const char *name) {
          NXArchInfo *a_info;
    const NXArchInfo *all_info;
          cpu_type_t  cputype;
    struct  name_map *map;
  
    if (name) {  /* Find config name based on arch name. */
        map = arch_config_map;
        while (map->arch_name) {
            /* If an explicit mapping is found, voila, we've finished. */
            if (!strcmp(map->arch_name, name)) return name;
            else map++;
        }
        /* radr://7148788  emit diagnostic if exact ARM arch is not explicitly handled. */
        a_info = (NXArchInfo *) NXGetArchInfoFromName(name);
        if (a_info && a_info->cputype == CPU_TYPE_ARM) a_info = NULL;
        if (!a_info) fatal("Invalid architecture name:  %s", name);
    } else {
        a_info = (NXArchInfo *) NXGetLocalArchInfo();
        if (!a_info) fatal("Unable to get local architecture name");
        if (m32_seen) a_info->cputype &= ~CPU_ARCH_ABI64;  /* Disable 64-bit ABI. */
        else if (m64_seen || sizeof(long) == 8) a_info->cputype |= CPU_ARCH_ABI64;
    }  
    /* Find first architecture that matches cputype: */
    all_info = NXGetAllArchInfos();
    if (!all_info) fatal("Unable to get list of architectures");
    cputype = a_info->cputype;
    while (all_info->name) {
        if (all_info->cputype == cputype) break;
        else all_info++;
    }
    return all_info->name;
} /* end get_arch_name() */

/* Find driver name based on arch name (which is required to be valid).  “PDN” is supplied via -D flag by the build script. */
static char *
get_driver_name (const char *arch_name) {
               char *driver_name;
    const      char *config_name = NULL;
                int  len;
    struct name_map *map         = arch_config_map;
                int  map_index   = 0;
    while (map[map_index].arch_name) {
        if (!strcmp(map[map_index].arch_name, arch_name)) {
            config_name = map[map_index].config_string;
            break;
        } else map_index++;
    }
    if (!config_name) fatal("Unable to guess config name for arch %s", arch_name);
    len = strlen(config_name) + strlen(PDN) + prefix_len + 1;
    driver_name = (char *) malloc(len * sizeof(char));
    driver_name[0] = '\0';
    if (driver_exec_prefix) strcpy(driver_name, driver_exec_prefix);
    strcat(driver_name, config_name);
    strcat(driver_name, PDN);
    if (resolve_path_to_binary(driver_name) == driver_name) {  /* no such binary exists */
        const char *maybe = NULL;
        if      (!strcmp(arch_name, "ppc"))  maybe = "powerpc64";
        else if (!strcmp(arch_name, "i386")) maybe = "x86_64";
        if (maybe) {
            driver_name[0] = '\0';        
            if (driver_exec_prefix) strcpy(driver_name, driver_exec_prefix);
            strcat(driver_name, maybe);
            strcat(driver_name, PDN);
            if (!strcmp(arch_name, "ppc")) maybe = "ppc64";  /* x86_64 is the same string for both Apple and `configure` */
        } else maybe = arch_name;
        if (resolve_path_to_binary(driver_name) == driver_name)  /* still, no such binary exists */
            fatal("Unable to locate compiler driver for architecture %s", maybe);
    }
    return driver_name;
} /* end get_driver_name() */

/* Delete all out_files. */
static void
delete_out_files (void) {
    const  char *temp;
    struct stat  st;
            int  i = 0;

    for (i = 0, temp = out_files[i]; temp && i < initial_argc * MAX_ARCHS; temp = out_files[++i])
        if (stat(temp, &st) >= 0 && S_ISREG(st.st_mode)) unlink(temp);
} /* end delete_out_files() */

/* Put fatal error message on stderr and exit. */
void
fatal (const char *msgid, ...) {
    va_list ap;

    va_start(ap, msgid);
     fprintf(stderr, "%s:  ", progname);
     vfprintf(stderr, msgid, ap);
    va_end(ap);
    fprintf(stderr, "\n");
    delete_out_files();
    exit(1);
} /* end fatal() */

/* Print error message and exit. */
static void
pfatal_pexecute (const char *errmsg, const char *msg_insert) {
    if (msg_insert) {
         int  stash = errno;
        char *msg   = (char *) malloc(strlen(errmsg) + strlen(msg_insert));  /* Space for null terminator taken from the "%s". */
        sprintf(msg, errmsg, msg_insert);
        errmsg = msg;
        free(msg);
        errno = stash;
    }
    fprintf(stderr, "%s:  %s:  %s\n", progname, errmsg, xstrerror(errno));
    delete_out_files();
    exit(1);
} /* end pfatal_pexecute() */

#ifdef DEBUG
static void
debug_command_line (int debug_argc, const char **debug_argv)
{
    int i;

    fprintf(stderr,"%s:  debug_command_line\n", progname);
    fprintf(stderr,"%s:  arg count = %d\n", progname, debug_argc);

    for (i = 0; debug_argv[i]; i++)
        fprintf (stderr,"%s:  arg [%d] %s\n", progname, i, debug_argv[i]);
} /* end debug_command_line() */
#endif

/* Cut the input file name down to its basename, replacing any file name suffix. */
static char *
basename_resuffix (const char *full_name, const char *new_suffix) {
    char *name;
    char *p;

    if (!full_name || !new_suffix) return NULL;

    /* Scan backwards for start of basename, then copy it out. */
    p = (char *)full_name + strlen(full_name);
    while (p != full_name && !IS_DIR_SEPARATOR(p[-1])) --p;
    name = (char *) malloc(strlen(p) + strlen(new_suffix) + 1);
    strcpy(name, p);

    p = name + strlen(name);
    while (p != name && *p != '.') --p;
    /* If start of name not reached then non-leading '.' was found; replace it with NULL. */
    if (p != name) *p = '\0';

    strcat(name, new_suffix);
    return name;
} /* end basename_resuffix() */

/* Initialization. */
static void
initialize (void) {
    int i;

    /* How many added arguments will the driver driver hand the compiler driver?                                                  *
     *                                                                                                                            *
     * Each "-arch" <arch> pair is replaced by a suitable "-mcpu=..." or similar.  That frees up one argument slot per "-arch".   *
     * As at most one "-m..." is supplied to each compiler driver, any "-arch" <arch> pair(s) after the first are removed from    *
     * the original command line, but additional slots being made available by either mechanism cannot be relied upon -- if no    *
     * archs were supplied, there aren't any.                                                                                     *
     *                                                                                                                            *
     * The driver driver may need to supply a temporary output file name.  "-o" <name> uses two extra slots.  Sometimes the       *
     * linker wants an extra "-Wl,-arch_multiple", and sometimes it wants to see "-final_output" "outputname".  Both at once will *
     * use three extra slots.  Ultimately we may need up to argc-plus-five argument slots, plus one more for the null terminator. */

    i = (initial_argc + 6) * sizeof(const char *);
    gcc_argv = (const char **) malloc(i);       if (!gcc_argv)  abort();
    archv    = (const char **) malloc(i);       if (!archv)     abort();
    for (i = 0; i < initial_argc + 6; i++) archv[i] = NULL;

    gcc_argc = 1;  /* The first slot, gcc_argv[0], is reserved for the driver name. */

    /* Each -arch generates three arguments to lipo:  "-arch" <arch> <filename>.  Five    *
     * more are used for "lipo" "-create" "-o" <output-filename> and the NULL terminator. */
    i = (MAX_ARCHS * 3 + 5) * sizeof(const char *);
    lipo_argv = (const char **) malloc(i);      if (!lipo_argv) abort();

    /* Need separate out_files for each arch (up to MAX_ARCHS), for each input file. */
    i = initial_argc * MAX_ARCHS * sizeof(const char *);
    out_files = (const char **) malloc(i);      if (!out_files) abort();

    num_archs   = 0;
    num_infiles = 0;
    in_files    = NULL;
    last_infile = NULL;

    for (i = 0; i <= MAX_ARCHS; i++) {
      commands[i].prog = NULL;
      commands[i].argv = NULL;
      commands[i].pid  = 0;
    }
} /* end initialize() */

/* Cleanup. */
static void
final_cleanup (void) {
    struct infile *next;

    free(gcc_argv);
    free(archv);
    free(lipo_argv);
    delete_out_files();
    free(out_files);
    for (next = in_files; num_infiles > 0 && next; num_infiles--) {
        next = in_files->next;
        free(in_files);
        in_files = next;
    }
} /* end final_cleanup() */

/* Wait for the process pid and return appropriate code.  */
static int
do_wait (int pid, const char *prog) {
    int status = 0;
    int ret    = 0;

    pid = pwait (pid, &status, 0);
    if (WIFSIGNALED(status)) {
        if (!signal_count && WEXITSTATUS(status) > greatest_status)
            greatest_status = WEXITSTATUS(status);
        ret = -1;
    } else if (WIFEXITED(status) && WEXITSTATUS(status) >= 1) {
        if (WEXITSTATUS(status) > greatest_status) greatest_status = WEXITSTATUS(status);
        signal_count++;
        ret = -1;
    }
    return ret;
} /* end do_wait() */

/* Invoke 'lipo' and combine and all output files.  */
static void
do_lipo (int start_outfile_index, const char *out_file) {
     int  i, j, pid;
    char *errmsg_fmt, *errmsg_arg;

    /* Populate lipo arguments.  */
    lipo_argv[0] = "lipo";
    lipo_argv[1] = "-create";
    lipo_argv[2] = "-o";
    lipo_argv[3] = out_file;

    /* The first 4 lipo arguments are set.  Now add all lipo inputs. */
    j = 4;
    for (i = 0; i < num_archs; i++) lipo_argv[j++] = out_files[start_outfile_index + i];
    lipo_argv[j] = NULL;  /* Add the null terminator. */

#ifdef DEBUG
    debug_command_line(j, lipo_argv);
#endif

    if (verbose_flag) {
        for (i = 0; lipo_argv[i]; i++) fprintf(stderr, "%s ", lipo_argv[i]);
        fprintf (stderr, "\n");
    }
    pid = pexecute(lipo_argv[0], (char *const *) lipo_argv, progname, NULL,
                                  &errmsg_fmt, &errmsg_arg, PEXECUTE_SEARCH | PEXECUTE_ONE);
    if (pid == -1) pfatal_pexecute(errmsg_fmt, errmsg_arg);

    do_wait(pid, lipo_argv[0]);
} /* end do_lipo() */

/* Invoke compiler for all architectures.  */
static void
do_compile (int this_argc, const char **this_argv) {
          char  *errmsg_fmt, *errmsg_arg;
           int   cmd_index = 0;
           int   local_argc;
    const char **one_arch_argv;
           int   one_arch_argc;

    while (cmd_index < num_archs) {
        int args_added = 0;

        this_argv[0] = get_driver_name(get_arch_name(archs[cmd_index]));

        /* Set up output file. */
        out_files[num_outfiles]  = make_temp_file(".out");
        this_argv[this_argc]     = "-o";
        this_argv[this_argc + 1] = out_files[num_outfiles];
        local_argc = this_argc + 2;
        num_outfiles++;

        /* Add CPU flag as the last option.  Add nothing else before removing it. */
        args_added = flag_for_cpu(cmd_index, this_argv, local_argc);
        local_argc += args_added;
        this_argv[local_argc] = NULL;

        one_arch_argv = (const char **) malloc((local_argc + 1) * sizeof(const char *));
        one_arch_argc = filter_args_for_arch(local_argc, this_argv, one_arch_argv,
                                             get_arch_name(archs[cmd_index]));

#ifdef DEBUG
        debug_command_line(one_arch_argc, one_arch_argv);
#endif

        commands[cmd_index].prog = one_arch_argv[0];
        commands[cmd_index].argv = one_arch_argv;
        commands[cmd_index].pid = pexecute(one_arch_argv[0], (char *const *) one_arch_argv,
                                           progname, NULL, &errmsg_fmt, &errmsg_arg,
                                           PEXECUTE_SEARCH | PEXECUTE_ONE);
        if (commands[cmd_index].pid == -1) pfatal_pexecute(errmsg_fmt, errmsg_arg);
        do_wait(commands[cmd_index].pid, commands[cmd_index].prog);
        fflush(stdout);

        /* Remove the CPU flag added to the end of this_argv. */
        if (args_added) local_argc -= unflag_cpu(this_argv, local_argc);
        cmd_index++;
        free(one_arch_argv);
    }
} /* end do_compile() */

/* Construct command line and invoke compiler driver for each input file separately. */
static void
do_compile_separately (void) {
    const    char **local_argv;
              int   i, local_argc;
    struct infile  *this_ifn;

    if (num_infiles == 1 || ima_is_used) abort();

    /* Total argv length in separate compiler invocation is:  (total number of original  *
     * arguments) - (total no. of input files) + (one input file) + "-o" + (output file) *
     * + (CPU-specific option) + NULL.                                                   */
    local_argv = (const char **) malloc((gcc_argc - num_infiles + 5) * sizeof(const char *));
    if (!local_argv) abort();

    for (this_ifn = in_files; this_ifn && this_ifn->name; this_ifn = this_ifn->next) {
        struct infile *ifn     = in_files;
                  int  go_back = 0;
                 bool  got_ifn = false;

        local_argc = 1;
        for (i = 1; i < gcc_argc; i++) {
            if (ifn && ifn->name && !strcmp(gcc_argv[i], ifn->name)) {
                /* This argument is the one with the input file.  */
                if (!strcmp(gcc_argv[i], this_ifn->name)) {
                    if (got_ifn)
                        fatal("file %s specified more than once on the command line", this_ifn->name);
                    /* If it is the current input file name, include it in the new args. */
                    local_argv[local_argc] = gcc_argv[i];
                    archv[local_argc] = archv[i];
                    local_argc++;
                    got_ifn = true;
                }
                ifn = ifn->next;
            } else {
                /* This argument is not an input file name; just copy it over. */
                local_argv[local_argc] = gcc_argv[i];
                archv[local_argc] = archv[i];
                local_argc++;
            }
        }
        do_compile (local_argc, local_argv);
    }
    free(local_argv);
} /* end do_compile_separately() */

/* Invoke 'lipo' on set of output files and create multiple fat binaries. */
static void
do_lipo_separately (void) {
              int  i;
    struct infile *ifn;

    for (i = 0, ifn = in_files; i < num_infiles && ifn && ifn->name; i++, ifn = ifn->next)
        do_lipo (i * num_archs, basename_resuffix(ifn->name, ".o"));
} /* end do_lipo_separately() */

/* Remove all architecture-specific options inapplicable to the current architecture. */
static int
filter_args_for_arch (int orig_argc, const char **orig_argv,
                                     const char **new_argv, const char *arch) {
    int new_argc = 0;
    int i;

    for (i = 0; i < orig_argc; i++)
        if (archv[i] == NULL || *archv[i] == '\0' || !strcmp(archv[i], arch))
            new_argv[new_argc++] = orig_argv[i];
    new_argv[new_argc] = NULL;
    return new_argc; 
} /* end filter_args_for_arch() */

/* Replace "-arch" <arch> option pair with appropriate "-mcpu=..." or "-march=...".  The *
 * index is into archs[].  Return exactly one option -- only one slot is allocated.      */
static int
flag_for_cpu (int index, const char **this_argv, int where) {
    int count = 1;

#ifdef DEBUG
    fprintf(stderr, "%s:  flag_for_cpu:  for %s\n", progname, archs[index]);
#endif

    if      (!strcmp (archs[index], "ppc601"))   this_argv[where] = "-mcpu=601";
    else if (!strcmp (archs[index], "ppc603"))   this_argv[where] = "-mcpu=603";
    else if (!strcmp (archs[index], "ppc604"))   this_argv[where] = "-mcpu=604";
    else if (!strcmp (archs[index], "ppc604e"))  this_argv[where] = "-mcpu=604e";
    else if (!strcmp (archs[index], "ppc750"))   this_argv[where] = "-mcpu=750";
    else if (!strcmp (archs[index], "ppc7400"))  this_argv[where] = "-mcpu=7400";
    else if (!strcmp (archs[index], "ppc7450"))  this_argv[where] = "-mcpu=7450";
    else if (!strcmp (archs[index], "ppc970"))   this_argv[where] = "-mcpu=970";
    else if (!strcmp (archs[index], "ppc64"))    this_argv[where] = "-m64";
    else if (!strcmp (archs[index], "i486"))     this_argv[where] = "-march=i486";
    else if (!strcmp (archs[index], "i586"))     this_argv[where] = "-march=i586";
    else if (!strcmp (archs[index], "i686"))     this_argv[where] = "-march=i686";
    else if (!strcmp (archs[index], "pentium"))  this_argv[where] = "-march=pentium";
    else if (!strcmp (archs[index], "pentium2")) this_argv[where] = "-march=pentium2";
    else if (!strcmp (archs[index], "pentpro"))  this_argv[where] = "-march=pentiumpro";
    else if (!strcmp (archs[index], "pentIIm3")) this_argv[where] = "-march=pentium2";
    else if (!strcmp (archs[index], "x86_64"))   this_argv[where] = "-m64";
    else if (!strcmp (archs[index], "arm"))      this_argv[where] = "-march=armv4t";
    else if (!strcmp (archs[index], "armv4t"))   this_argv[where] = "-march=armv4t";
    else if (!strcmp (archs[index], "armv5"))    this_argv[where] = "-march=armv5tej";
    else if (!strcmp (archs[index], "xscale"))   this_argv[where] = "-march=xscale";
    else if (!strcmp (archs[index], "armv6"))    this_argv[where] = "-march=armv6k";
    else if (!strcmp (archs[index], "armv7"))    this_argv[where] = "-march=armv7a";
    else count = 0;

    return count;
}

/* Remove the indicated option, which should be the terminal arch-specific CPU option *
 * added by flag_for_cpu.  Return the number of arguments removed.                    */
static int
unflag_cpu (const char **this_argv, int arch_index) {

#ifdef DEBUG
    fprintf(stderr, "%s:  Removing argument number %d\n", progname, arch_index);
#endif
    this_argv[arch_index] = '\0';
    if (this_argv[arch_index + 1]) fatal("unflag_cpu() called on nonterminal parameter");
#ifdef DEBUG
    debug_command_line(arch_index, this_argv);
#endif
    return 1;
} /* end unflag_cpu() */

/* Add an architecture to build for. */
void
add_arch (const char *new_arch) {
    int i;

    /* Ensure uniqueness. */
    for (i = 0; i < num_archs; i++) if (!strcmp(archs[i], new_arch)) return;
    if (num_archs == MAX_ARCHS) fatal("More than ten architectures requested simultaneously");
    else archs[num_archs++] = new_arch;
}

/******************************************************************************************/

/* Rewrite the command line as requested in the QA_OVERRIDE_GCC3_OPTIONS environment
   variable -- used for testing the compiler, working around bugs in the Apple build
   environment, etc.

   The override string is made up of a set of space-separated clauses.  The first letter
   of each clause describes what's to be done:
   +string       Append string to the command line as a new argument.  Multi-word strings
                 can be added with +x +y.
   s/x/y/        Substitute y for x in the command line.  "x" must be an entire argument,
                 and can be a regular expression as accepted by the POSIX regexp code.
                 "y" will be substituted as a single argument, and will not be subject to
                 regexp substitution or expansion.
   xoption       Removes argument matching "option".
   Xoption       Removes argument matching "option" and the following word.
   Ox            Removes all optimization flags and appends a single "-Ox".

   Here are some examples:
      O2
      s/precomp-trustfile=foo//
      +-fexplore-antartica
      +-fast
      s/-fsetvalue=* //
      x-fwritable-strings
      s/-O[0-2]/-Osize/
      x-v
      X-o +-o +foo.o

   Option substitutions are processed from left to right; matches and changes are
   cumulative.  An error in processing one element (such as trying to remove an element
   and successor when the match is at the end) causes the particular change to stop, but
   further changes will still be applied.

   Key details:
    * We always want to be able to adjust optimization levels for testing.
    * Adding options is a common task.
    * Substitution and deletion are less common.

   If the first character of the environment variable is #, changes are silent.  If not,
   diagnostics are written to stderr explaining what changes are being performed.
*/

     char **arg_array;
      int   arg_array_size  = 0;
      int   arg_count       = 0;
      int   confirm_changes = 1;
const int   ARG_ARRAY_INCREMENT_SIZE = 8;

#define FALSE 0

/* Routines for the argument array.  The argument array routines are responsible for *
 * allocation and deallocation of all objects in the array. */

/* Expand the array by a fixed increment. */

/* Initialize the array. */
void read_args (int argc, char **argv) {
    int i;

    arg_array_size = argc+10;
    arg_count = argc;
    arg_array = (char**) malloc(sizeof(char*)*arg_array_size);

    for (i = 0; i < argc; i++) {
        arg_array[i] = malloc(strlen(argv[i]) + 1);
        strcpy(arg_array[i], argv[i]);
    }
} /* end read_args() */

/* Insert the argument at (i.e., before) pos. */
void insert_arg(int pos, char *arg_to_insert) {
     int  i;
    char *newArg = malloc(strlen(arg_to_insert) + 1);

    strcpy(newArg, arg_to_insert);

    if (confirm_changes) fprintf(stderr, "### Adding argument %s at position %d\n", arg_to_insert, pos);

    if (arg_count == arg_array_size) {
        /* expand array */
        arg_array_size = arg_count + ARG_ARRAY_INCREMENT_SIZE;
        arg_array = (char**) realloc(arg_array, arg_array_size);
    }

    for (i = arg_count++; i > pos; i--) arg_array[i+1] = arg_array[i];
    arg_array[pos] = newArg;
} /* end insert_arg() */

void replace_arg (int pos, char *str) {
    char *newArg = malloc(strlen(str) + 1);

    strcpy(newArg, str);

    if (confirm_changes) fprintf (stderr, "### Replacing %s with %s\n", arg_array[pos], str);

    free (arg_array[pos]);
    arg_array[pos] = newArg;
} /* end replace_arg() */

void append_arg (char *str) {
    char *new_arg = malloc(strlen(str) + 1);

    strcpy(new_arg, str);

    if (confirm_changes) fprintf(stderr, "### Adding argument %s at end\n", str);

    if (arg_count == arg_array_size) {
      /* expand array */
      arg_array_size = arg_count + ARG_ARRAY_INCREMENT_SIZE;
      arg_array = (char**) realloc (arg_array, arg_array_size);
    }

    arg_array[arg_count++] = new_arg;
} /* end append_arg() */

void delete_arg(int pos) {
    int i;

    if (confirm_changes) fprintf(stderr, "### Deleting argument %s\n", arg_array[pos]);

    if (pos < arg_count) {
        free (arg_array[pos]);

        for (i = pos; i < arg_count; i++) arg_array[i] = arg_array[i+1];

        arg_count--;
    }
} /* end delete_arg() */

/* Changing optimization levels is a common testing pattern -- we've got a special option *
 * that searches for and replaces anything beginning with -O                              */
void replace_optimization_level (char *new_level) {
     int  i;
     int  optionFound = 0;
    char *new_opt     = malloc(strlen(new_level) + 3);

    sprintf(new_opt, "-O%s", new_level);

    for (i = 0; i < arg_count; i++) {
        if (strncmp(arg_array[i], "-O", 2) == 0) {
          replace_arg(i, new_opt);
          optionFound = 1;
          break;
        }
    }

    if (optionFound == 0) append_arg(new_opt);  /* No optimization level?  Add it! */

    free (new_opt);
} /* end replace_optimization_level() */

/* Returns a null-terminated string holding whatever was in the original string at that *
 * point.  This must be freed by the caller.                                            */
char *arg_string(char *str, int begin, int len) {
    char *new_str = malloc(len + 1);

    strncpy(new_str, &str[begin], len);
    new_str[len] = '\0';
    return new_str;
} /* end arg_string() */

/* Given a search-and-replace string of the form                                         *
 *    s/x/y/                                                                             *
 * do search and replace on the arg list.  Make sure to check that the string is sane -- *
 * that it has all the proper slashes that are necessary.  The search string can be a    *
 * regular expression, but the replace string must be a literal; the search must also be *
 * for a full argument, not for a chain of arguments.  The result will be treated as a   *
 * single argument.  Return true if success, false if failure.                           */
bool search_and_replace (char *str) {
      regex_t  regexp_search_struct;
          int  searchLen;
          int  replaceLen;
          int  i;
          int  err;
         char *searchStr;
         char *replaceStr;
         char *replacedStr;
    const int  ERRSIZ = 512;
         char  errbuf[ERRSIZ];

    if (str[0] != '/') return false;
    searchLen = strcspn (str + 1, "/\0");
    if (str[1 + searchLen] != '/') return false;
    replaceLen = strcspn(str + 1 + searchLen + 1, "/\0");
    if (str[1 + searchLen + 1 + replaceLen] != '/') return false;
    searchStr  = arg_string(str, 1, searchLen);
    replaceStr = arg_string(str, 1 + searchLen + 1, replaceLen);
    if ((err = regcomp(&regexp_search_struct, searchStr, REG_EXTENDED)) != 0) {
        regerror(err, &regexp_search_struct, errbuf, ERRSIZ);
        fprintf(stderr, "%s", errbuf);
        return false;
    }
    for (i = 0; i < arg_count; i++) {
        regmatch_t matches[5];
        if (regexec(&regexp_search_struct, arg_array[i], 5, matches, 0) == 0
                && matches[0].rm_eo - matches[0].rm_so == strlen(arg_array[i])) {
            replace_arg(i, replaceStr);  /* Success! Change the string. */
            break;
        }
    }
    regfree (&regexp_search_struct);
    free (searchStr);
    free (replaceStr);
    return true;
} /* end search_and_replace() */

/* Given a string, return the argument number where the first match occurs. */
int find_arg (char *str) {
    int i;
    int matchIndex = -1;

    for (i = 0; i < arg_count; i++)
        if (strcmp(arg_array[i], str) == 0) {
          matchIndex = i;
          break;
        }
    return matchIndex;
} /* end find_arg() */

void rewrite_command_line (char *override_options_line, int *argc, char ***argv){
    int line_pos = 0;

    read_args(*argc, *argv);
    if (override_options_line[0] == '#') {
        confirm_changes = 0;
        line_pos++;
    }
    if (confirm_changes) fprintf(stderr, "### QA_OVERRIDE_GCC3_OPTIONS:  %s\n", override_options_line);
    /* Loop through all commands in the string. */
    while (override_options_line[line_pos] != '\0') {
        char  first_char;
        char *searchStr;
        char *arg;
         int  search_index;
         int  arg_len;

        /* Any spaces in between options don't count. */
        if (override_options_line[line_pos] == ' ') {
            line_pos++;
            continue;
        }
        /* The first non-space character is the command. */
        first_char = override_options_line[line_pos];
        line_pos++;
        arg_len = strcspn(override_options_line + line_pos, " ");
        switch (first_char) {
          case '+':  /* Add an argument to the end of the arg list */
            arg = arg_string(override_options_line, line_pos, arg_len);
            append_arg(arg);
            free(arg);
            break;
          case 'O':  /* Remove any optimization arguments and change the optimization     *
                      * level to the specified value.  This is a separate command because *
                      * we often want to substitute our favorite optimization level for   *
                      * whatever the project normally wants.  As we probably care about   *
                      * this a lot (for things like testing file sizes at different       *
                      * optimization levels) we make a special rewrite clause.            */
            arg = arg_string(override_options_line, line_pos, arg_len);
            replace_optimization_level(arg);
            free(arg);
            break;
          case 'X':  /* Delete a matching argument and the argument following. */
            searchStr = arg_string(override_options_line, line_pos, arg_len);
            if ((search_index = find_arg(searchStr)) != -1)
                if (search_index >= arg_count - 1) {
                    if (confirm_changes) fprintf(stderr, "Not enough arguments to do X\n");
                } else {
                    delete_arg(search_index); /* Delete the matching argument */
                    delete_arg(search_index); /* Delete the following argument */
                }
            free(searchStr);
            break;
          case 's':  /* Search for the regexp passed in, and replace a matching argument *
                      * with the provided replacement string.                            */
            searchStr = arg_string(override_options_line, line_pos, arg_len);
            search_and_replace(searchStr);
            free(searchStr);
            break;
          case 'x':  /* Delete a matching argument */
            searchStr = arg_string(override_options_line, line_pos, arg_len);
            if ((search_index = find_arg(searchStr)) != -1) delete_arg(search_index);
            free(searchStr);
            break;
          default:
            fprintf(stderr, "### QA_OVERRIDE_GCC3_OPTIONS:  invalid string (pos %d)\n", line_pos);
            break;
        }
        line_pos += arg_len;
    }
    *argc = arg_count;
    *argv = arg_array;
} /* end rewrite_command_line() */

/******************************************************************************************/

/* Given a path to a file, potentially containing a directory name, return the length of *
 * the basename portion.                                                                 */
static int
get_basename_len (const char *prog) {
    int result = 0;
    const char *progend = prog + strlen(prog);
    const char *progname = progend;
    while (progname != prog && !IS_DIR_SEPARATOR(progname[-1])) --progname;
    return progend - progname;
} /* end get_basename_len() */

/* Return true iff the path names an executable file and not a directory. */
static bool
is_x_file (const char *path) {
    struct stat st;

    if (access(path, X_OK)) return false;
    if (stat(path, &st) == -1) return false;
    if (S_ISDIR(st.st_mode)) return false;
    return true;
} /* end is_x_file() */

/* Given the basename of an executable (e.g. "gcc"), search $PATH to find its parent directory, & return an absolute pathname. */
static const char *
resolve_path_to_binary (const char *filename) {
           char  path_buffer[2 * PATH_MAX + 1];
           char *PATH = getenv("PATH");
       unsigned  prefix_size;
    struct stat  st;
           char *colon = strchr(PATH, ':');

    if (PATH == 0) return filename;  /* PATH not set */

    do {
        colon = strchr(PATH, ':');
        prefix_size = colon ? colon - PATH : strlen(PATH);  /* If we didn't find a :, use the whole last chunk. */
    
        /* Form the full path. */
        memcpy(path_buffer, PATH, prefix_size);
        path_buffer[prefix_size] = '/';
        strcpy(path_buffer + prefix_size + 1, filename);
    
        /* Check to see if this file is executable, if so, return it. */
        if (is_x_file(path_buffer)) return strdup(path_buffer);
        PATH = colon ? colon + 1 : PATH + prefix_size;
    } while (PATH[0]);

    return filename;
} /* end resolve_path_to_binary() */

/* If prog is a symlink, we want to rewrite prog to an absolute location.  symlink_buffer holds the destination of the symlink. *
 * Glue these pieces together to form an absolute path.                                                                         */
static const char *
resolve_symlink (const char *prog, char *symlink_buffer, int argv_0_len, int prog_len) {
    /* If the link isn't to an absolute path, prefix it with the argv[0] directory. */
    if (!IS_ABSOLUTE_PATH(symlink_buffer)) {
        int prefix_len = argv_0_len - prog_len;
        memmove(symlink_buffer + prefix_len, symlink_buffer, PATH_MAX - prefix_len + 1);
        memcpy(symlink_buffer, prog, prefix_len);
    }
    return strdup(symlink_buffer);
} /* end resolve_symlink() */

/* Main entry point.  This is the gcc driver driver!  Interpret -arch flags from the list of input arguments.  Invoke the *
 * appropriate compiler driver(s).  'lipo' the results if more than one -arch is supplied.                                */
int
main (int argc, const char **argv) {
    size_t  i;
       int  l, pid, argv_0_len, prog_len;
      char *errmsg_fmt, *errmsg_arg;
      char *override_option_str = NULL;
      char  path_buffer[2 * PATH_MAX + 1];
       int  linklen;

    initial_argc = argc;
    argv_0_len   = strlen(argv[0]);
    /* Get the progname, required by pexecute() and program location: */
    prog_len     = get_basename_len(argv[0]);

    /* If argv[0] is all program name (no slashes), search $PATH for it. */
    if (prog_len == argv_0_len) {
#ifdef DEBUG
        progname = argv[0] + argv_0_len - prog_len;
        fprintf(stderr,"%s:  before PATH resolution, full progname = %s\n", argv[0] + argv_0_len - prog_len, argv[0]);
#endif
        argv[0]    = resolve_path_to_binary(argv[0]);
        prog_len   = get_basename_len(argv[0]);
        argv_0_len = strlen(argv[0]);
    }

    /* If argv[0] is a symbolic link, use the directory of the pointed-to file to find compiler components. */
    if ((linklen = readlink(argv[0], path_buffer, PATH_MAX)) != -1) {
        /* readlink succeeds if argv[0] is a symlink.  path_buffer now contains the file referenced. */
        path_buffer[linklen] = '\0';
#ifdef DEBUG
        progname = argv[0] + argv_0_len - prog_len;
        fprintf(stderr, "%s:  before symlink, full prog = %s target = %s\n",
                     progname, argv[0], path_buffer);
#endif
        argv[0] = resolve_symlink(argv[0], path_buffer, argv_0_len, prog_len);
        argv_0_len = strlen(argv[0]);

        /* Get the progname, required by pexecute () and program location.  */
        prog_len = get_basename_len(argv[0]);

#ifdef DEBUG
        progname = argv[0] + argv_0_len - prog_len;
        printf("%s:  ARGV[0] after symlink = %s\n", progname, argv[0]);
#endif
    }

    prefix_len = argv_0_len - prog_len;
    progname = argv[0] + prefix_len;
    curr_dir = (char *) malloc(sizeof(char) * (prefix_len + 1));
    strncpy(curr_dir, argv[0], prefix_len);
    curr_dir[prefix_len] = '\0';
    driver_exec_prefix = (argv[0], "/usr/bin", curr_dir);

#ifdef DEBUG
    fprintf(stderr, "%s:  full progname = %s\n", progname, argv[0]);
    fprintf(stderr, "%s:  progname = %s\n", progname, progname);
    fprintf(stderr, "%s:  driver_exec_prefix = %s\n", progname, driver_exec_prefix);
#endif

    /* Before we get too far, rewrite the command line with any requested overrides. */
    if ((override_option_str = getenv ("QA_OVERRIDE_GCC3_OPTIONS")) != NULL)
        rewrite_command_line(override_option_str, &argc, (char***)&argv);
    else /* quietly make command line editable */
        rewrite_command_line("#", &argc, (char***)&argv);

    int leftmost_m32 = find_arg("-m32"); int leftmost_m64 = find_arg("-m64");
    while (leftmost_m32 > -1 && leftmost_m64 > -1)
        if (leftmost_m32 < leftmost_m64) {
            delete_arg(leftmost_m32);
            leftmost_m32 = find_arg("-m32");
        } else {
            delete_arg(leftmost_m64);
            leftmost_m64 = find_arg("-m64");
        }

    initial_argc = argc;
    initialize;

    /* Process arguments.  Act appropriately when -arch, -c, -S, -E, -o encountered.  Find input file name. */
    for (i = 1; i < argc; i++) {
        if        (!strcmp(argv[i], "-arch")) {
            if (i + 1 >= argc) abort();
            add_arch(argv[i+1]);
            i++;
        } else if (!strcmp(argv[i], "-c")) {
            gcc_argv[gcc_argc++] = argv[i];
            compile_only_req = 1;
        } else if (!strcmp(argv[i], "-S")) {
            gcc_argv[gcc_argc++] = argv[i];
            asm_output_req = 1;
        } else if (!strcmp(argv[i], "-E")) {
            gcc_argv[gcc_argc++] = argv[i];
            preproc_output_req = 1;
        } else if (!strcmp(argv[i], "-MD") || !strcmp(argv[i], "-MMD")) {
            gcc_argv[gcc_argc++] = argv[i];
            capital_m_seen = 1;
        } else if (!strcmp(argv[i], "-m32")) {
            gcc_argv[gcc_argc++] = argv[i];
            m32_seen = 1;
        } else if (!strcmp(argv[i], "-m64")) {
            gcc_argv[gcc_argc++] = argv[i];
            m64_seen = 1;
        } else if (!strcmp(argv[i], "-dynamiclib")) {
            gcc_argv[gcc_argc++] = argv[i];
            dynamiclib_seen = 1;
        } else if (!strcmp(argv[i], "-v")) {
            gcc_argv[gcc_argc++] = argv[i];
            verbose_flag = 1;
        } else if (!strcmp(argv[i], "-o")) {
            if (i + 1 >= argc) fatal("argument to '-o' is missing");  
            output_file = argv[i+1];
            i++;
        } else if (   (!strcmp (argv[i], "-pass-exit-codes"))
                   || (!strcmp (argv[i], "-print-search-dirs"))
                   || (!strcmp (argv[i], "-print-libgcc-file-name"))
                   || (!strncmp(argv[i], "-print-file-name=", 17))
                   || (!strncmp(argv[i], "-print-prog-name=", 17))
                   || (!strcmp (argv[i], "-print-multi-lib"))
                   || (!strcmp (argv[i], "-print-multi-directory"))
                   || (!strcmp (argv[i], "-print-multi-os-directory"))
                   || (!strcmp (argv[i], "-ftarget-help"))
                   || (!strcmp (argv[i], "-fhelp"))
                   || (!strcmp (argv[i], "+e"))
                   || (!strncmp(argv[i], "-Wa,",4))
                   || (!strncmp(argv[i], "-Wp,",4))
                   || (!strncmp(argv[i], "-Wl,",4))
                   || (!strncmp(argv[i], "-l", 2))
                   || (!strncmp(argv[i], "-weak-l", 7))
                   || (!strncmp(argv[i], "-specs=", 7))
                   || (!strcmp (argv[i], "-ObjC"))
                   || (!strcmp (argv[i], "-fobjC"))
                   || (!strcmp (argv[i], "-ObjC++"))
                   || (!strcmp (argv[i], "-time"))
                   || (!strcmp (argv[i], "-###"))
                   || (!strcmp (argv[i], "-fconstant-cfstrings"))
                   || (!strcmp (argv[i], "-fno-constant-cfstrings"))
                   || (!strcmp (argv[i], "-static-libgcc"))
                   || (!strcmp (argv[i], "-shared-libgcc"))
                   || (!strcmp (argv[i], "-pipe"))
                  ) {
            gcc_argv[gcc_argc++] = argv[i];
        } else if (!strcmp(argv[i], "-save-temps") || !strcmp(argv[i], "--save-temps")) {
            gcc_argv[gcc_argc++] = argv[i];
            save_temps_seen = 1;
        }
        else if (   (!strcmp (argv[i], "-Xlinker"))
                 || (!strcmp (argv[i], "-Xassembler"))
                 || (!strcmp (argv[i], "-Xpreprocessor"))
                 || (!strcmp (argv[i], "-l"))
                 || (!strcmp (argv[i], "-weak_library"))
                 || (!strcmp (argv[i], "-weak_framework"))
                 || (!strcmp (argv[i], "-specs"))
                 || (!strcmp (argv[i], "-framework"))
                ) {
            gcc_argv[gcc_argc++] = argv[i];
            i++;
            gcc_argv[gcc_argc++] = argv[i];
        } else if (!strncmp(argv[i], "-Xarch_", 7)) {
            archv[gcc_argc] = get_arch_name(argv[i] + 7);
            i++;
            gcc_argv[gcc_argc++] = argv[i];
        } else if (argv[i][0] == '-' && argv[i][1] != 0) {
            const char *p = &argv[i][1];
            int c = *p;
            gcc_argv[gcc_argc++] = argv[i];  /* First copy this flag itself. */
            if (argv[i][1] == 'M') capital_m_seen = 1;
            /* Now copy this flag's arguments, if any, appropriately. */
            if ((SWITCH_TAKES_ARG(c) > (p[1] != 0)) || WORD_SWITCH_TAKES_ARG(p)) {
                int j      = 0;
                int n_args = WORD_SWITCH_TAKES_ARG(p);

                if (n_args == 0) {
                    /* Count only the option arguments in separate argv elements.  */
                    n_args = SWITCH_TAKES_ARG(c) - (p[1] != 0);
                }
                if (i + n_args >= argc) fatal("argument to “-%s” is missing", p);
                while (j < n_args) {
                    i++;
                    gcc_argv[gcc_argc++] = argv[i];
                    j++;
                }
            }
        } else {
            struct infile *ifn;

            gcc_argv[gcc_argc++] = argv[i];
            ifn = (struct infile *) malloc(sizeof(struct infile));
            ifn->name  = argv[i];
            ifn->index = i;
            ifn->next  = NULL;
            num_infiles++;
            if (last_infile) last_infile->next = ifn;
            else in_files = ifn;
            last_infile = ifn;
        }
    }
#if 0
    if (num_infiles == 0) fatal("no input files");
#endif
    if (num_archs == 0) add_arch(get_arch_name(NULL));
    if (num_archs > 1) {
        if (preproc_output_req || asm_output_req || save_temps_seen || capital_m_seen)
            fatal("-E, -S, -save-temps and -M options are not allowed with multiple -arch flags");
        /* If more than one input file is supplied but only one output filename is present then IMA will be used. */
        if (num_infiles > 1 && !compile_only_req) ima_is_used = 1;
        /* Linker wants to know this in case of multiple -arch. */
        if (!compile_only_req && !dynamiclib_seen) gcc_argv[gcc_argc++] = "-Wl,-arch_multiple";
        /* If only one input file is specified or IMA is used then expected output is one fat binary. */
        if (num_infiles == 1 || ima_is_used) {
            const char *out_file;
            /* Create output file name based on input filename, if required. */
            if (compile_only_req && !output_file && num_infiles == 1)
                out_file = basename_resuffix(in_files->name, ".o");
            else out_file = (output_file ? output_file : default_outfile);
            /* Linker wants to know name of output file using one extra arg.  */
            if (!compile_only_req) {
                char *oname = (char *) (output_file ? output_file : default_outfile);
                char *n =  malloc(sizeof(char) * (strlen(oname) + 5));
                strcpy(n, "-Wl,");
                strcat(n, oname);
                gcc_argv[gcc_argc++] = "-Wl,-final_output";
                gcc_argv[gcc_argc++] = n;
            }
            /* Compile file(s) for each arch and lipo 'em together.  */
            do_compile (gcc_argc, gcc_argv);
            /* Make fat binary by combining individual output files for each architecture using 'lipo'. */
            do_lipo (0, out_file);
        } else {
            /* Multiple input files and no IMA:  Need to generate multiple fat files.  */
            do_compile_separately();
            do_lipo_separately();
        }
    /* If no, or one, "-arch" <arch> pair is specified, invoke the appropriate compiler driver; fat build is not required. */
    } else {  /* num_archs == 1 */
               int   archc;
        const char **archv;
        /* Find compiler driver based on -arch <foo> and add approriate -m* argument. */
        gcc_argv[0] = get_driver_name(get_arch_name(archs[0]));
        gcc_argc    = gcc_argc + flag_for_cpu(0, gcc_argv, gcc_argc);
#ifdef DEBUG
        printf("%s:  invoking single driver name = %s\n", progname, gcc_argv[0]);
#endif
        if (output_file) {  /* Re insert output file name. */
            gcc_argv[gcc_argc++] = "-o";
            gcc_argv[gcc_argc++] = output_file;
        }
        gcc_argv[gcc_argc] = NULL;  /* Add the null terminator. */
        archv = (const char **) malloc((gcc_argc + 1) * sizeof(const char *));
        archc = filter_args_for_arch (gcc_argc, gcc_argv, archv, get_arch_name(archs[0]));
#ifdef DEBUG
        debug_command_line(archc, archv);
#endif
        pid = pexecute (archv[0], (char *const *)archv, progname, NULL, &errmsg_fmt, &errmsg_arg, PEXECUTE_SEARCH | PEXECUTE_ONE);
        if (pid == -1) pfatal_pexecute(errmsg_fmt, errmsg_arg);
        do_wait(pid, archv[0]);
    }
    final_cleanup();
    free(curr_dir);
    return greatest_status;
} /* end main() */
