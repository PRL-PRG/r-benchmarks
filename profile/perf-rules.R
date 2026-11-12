# Reading a recording's frames, and the frame classification: which C symbol belongs to which category, and the
# walk that applies it. Shared by `categories.Rmd`, which is about these rules,
# and `categories-timeR.Rmd`, which needs the identical fold to compare against
# timeR -- if the two drifted, the comparison would measure the drift.

# One cfun each, so perf resolves these exactly; on the timeR side they are
# individual bins carved back out of the aggregate that contains them.
DISPATCH_PRIMITIVES <- c("UseMethod", "NextMethod", "standardGeneric")
DISPATCH_SYMS <- c("do_usemethod", "do_nextmethod", "do_standardGeneric")

# A frame in the interpreter's own object whose symbol has this shape is R
# primitive code. `R_do_` picks up the handful of entries exported as C API
# (`R_do_set_class`, `R_do_data_class`).
PRIMITIVE_SYM <- "^(do_|R_do_)"

# The ALTREP dispatch layer: `ALTREAL_ELT`, `ALTVEC_DATAPTR`, `ALTREP_LENGTH`
# and friends, real functions in altrep.c. This is where an ALTREP vector's
# elements are produced -- a compact sequence materialises here -- so it is
# primitive work with no other home, wherever it was called from.
#
# Deliberately *not* the generic accessors around it. `REAL_ELT` and `DATAPTR`
# are `ALTREP(x) ? ALT... : ...` dispatchers and `REAL0` is explicitly the
# non-ALTREP path (`STDVEC_DATAPTR`); all of them are `INLINE_FUN` in
# Rinlinedfuns.h and exist as frames only because this build uses `-fno-inline`
# so that `perf --call-graph fp` can unwind. In a stock build they are part of
# their caller, so leaving them unclassified -- letting the walk charge them to
# whoever called them -- is what reproduces a stock build's attribution.
ALTREP_SYM <- "^ALT"

timer_category_rules <- function() {
  tribble(
    ~category, ~sym,

    ## --- interpreter phases -----------------------------------------------
    # timeR.c:613 opens TR_Startup in timeR_init_early(); main.c:1281 closes it
    # once setup_Rmainloop() is done
    "other", "setup_Rmainloop",
    "other", "Rf_initialize_R",
    "other", "Rf_mainloop",
    "other", "main",
    "other", "run_Rmainloop",              # main.c:1264

    ## --- memory.c ---------------------------------------------------------
    "mem-alloc", "Rf_cons",                    # memory.c:2488
    "mem-alloc", "CONS_NR",                    # memory.c:2521
    "mem-alloc", "Rf_allocVector3",     # memory.c:2700
    "mem-alloc", "Rf_allocList",          # memory.c:3017
    "mem-alloc", "Rf_allocLang",          # memory.c:3029
    "mem-alloc", "Rf_allocS4Object",        # memory.c:3041
    "mem-alloc", "R_allocObject",       # memory.c:3051
    "mem-gc", "R_gc_internal",        # memory.c:3219

    ## --- duplicate.c ------------------------------------------------------
    "mem-duplicate", "Rf_duplicate",          # duplicate.c:136
    "mem-duplicate", "Rf_shallow_duplicate",  # duplicate.c:157
    # The worker both of the above are wrappers around -- duplicate.c:109 says
    # so: "The original duplicate() function is now duplicate1()". At -O2 the
    # wrapper is inlined and the samples land here instead, so a build that
    # keeps its frames (`-fno-inline`) reports `Rf_duplicate` while a release
    # build reports `duplicate1` and matched no rule at all. Naming both is what
    # makes the category mean the same thing on either build.
    "mem-duplicate", "duplicate1",            # duplicate.c:115

    ## --- envir.c ----------------------------------------------------------
    "lookup", "R_findVarInFrame",    # envir.c:1099
    "lookup", "R_findVar",             # envir.c:1227
    "lookup", "Rf_findVar1",           # envir.c:1327
    "lookup", "findVar1mode",          # envir.c:1371
    "lookup", "Rf_findFun3",           # envir.c:1594

    ## --- eval.c -----------------------------------------------------------
    "call", "make_applyClosure_env",     # eval.c:2307
    "call", "Rf_evalList",            # eval.c:3645
    "interpreter", "bcEval",                   # eval.c:7539
    "interpreter", "bcEval_loop",
    # timeR has no timer on the AST evaluator at all, so this category is a
    # perf-only one and reports an exact zero on the timeR side
    "interpreter", "Rf_eval",
    "call", "R_execClosure",      # eval.c:2329, BEGIN_RFUNC_TIMER

    ## --- names.c ----------------------------------------------------------
    "primitives", "do_internal",         # names.c:1366

    ## --- dotcode.c --------------------------------------------------------
    "native-ffi", "do_External",     # dotcode.c:550
    "native-ffi", "R_doDotCall",          # dotcode.c:766
    "native-ffi", "do_dotcall",            # dotcode.c:1446
    # dotcode.c:1705 BEGIN_TIMER_ALTERNATIVES(Fort, dotFortranFull, dotCFull) --
    # both live in do_dotCode, so perf cannot tell .C from .Fortran apart
    "native-ffi", "do_dotCode",

    ## --- eval.c: the bytecode loop's own entry points ---------------------
    # None of these has a timeR timer and none is named `do_*`, so before they
    # were listed the walk fell through them to `bcEval_loop`. Each is mapped to
    # the region its *AST-path* counterpart already resolves to, so no sample
    # that was right stays wrong: only `bcEval` gives anything up. `How far the
    # walk has to reach` measures what each was worth and re-checks it.
    #
    # arithmetic: cmp_arith2 (eval.c:5020) returns R_binary(), cmp_arith1
    # (eval.c:5004) returns R_unary() -- neither ever calls do_arith, which is
    # what the AST path uses and what the shape test catches there.
    "primitives", "cmp_arith2",
    "primitives", "cmp_arith1",
    "primitives", "R_binary",
    "primitives", "R_unary",
    # cmp_relop (eval.c:4987) does end in do_relop_dflt, so relational operators
    # were never mis-charged; it is listed so a truncated unwind still lands.
    "primitives", "cmp_relop",
    # the subset/subassign opcodes' fast paths, which do the work themselves
    # rather than bailing to the `_dflt` function when they decline
    "primitives", "VECSUBSET_PTR",
    "primitives", "VECSUBASSIGN_PTR",
    "primitives", "MATSUBSET_PTR",
    "primitives", "MATSUBASSIGN_PTR",
    "primitives", "R_subset3_dflt",        # `$`; do_subset3 on the AST path
    # assignment: the AST path reaches Rf_defineVar through do_set, which the
    # shape test calls Primitive, so the bytecode path says the same
    "primitives", "Rf_defineVar",
    "primitives", "SET_BINDING_VALUE",
    # the bytecode's binding cache: getvar (eval.c:5811) -> findVarEX
    # (eval.c:5785) -> GET_BINDING_CELL_CACHE. A cache *miss* already falls
    # through to R_findVar, which is SymLookup; a hit is the same work.
    "lookup", "getvar",
    "lookup", "findVarEX",
    "lookup", "GET_BINDING_CELL_CACHE",
    # the inline closure call. setup_bcframe_call (eval.c:7375) does what
    # R_execClosure does on the AST path -- and calls make_applyClosure_env
    # itself, so argument matching already lands in `Match` and stays there,
    # being the deeper frame.
    "call", "setup_bcframe_call",
    "call", "finish_inline_closure_call",
    # NB deliberately absent: setup_bcframe_prom, finish_force_promise,
    # Rf_mkPROMISE. Forcing a promise has no named counterpart on the AST path
    # either (`forcePromise` carries no timer and no rule), so parity decides
    # nothing and both paths stay consistently silent about it.
  ) |>
    # the three dispatch primitives are `do_*` too, so they need a rule that
    # outranks the shape test rather than being folded into `Primitive`
    bind_rows(tibble(category = "dispatch", sym = DISPATCH_SYMS)) |>
    # a fixed timer nested inside a `do_*` body wins over the shape test, which
    # is what folds `.Internal`, `.Call`, `.External` and `.C` into their own
    # categories rather than into `Primitive`
    mutate(priority = 1L)
}

rules <- timer_category_rules()

#' Whichever object contributes the most frames is the interpreter itself.
interpreter_object <- function(frames) {
  frames |>
    filter(!dso %in% c("[unknown]", "inlined")) |>
    count(dso, sort = TRUE) |>
    slice_head(n = 1) |>
    pull(dso)
}

# A leaf in one of these is native linear algebra, wherever it was reached from.
# Not a region: recorded per sample, and splits `native-blas` out of whichever
# region the walk lands on.
NATIVE_MATH_DSO <-
  "libRblas|libRlapack|libblas|liblapack|libopenblas|libmkl|libgfortran|libquadmath"

# An R package's own shared object: `<lib>/<pkg>/libs/<pkg>.so`, in the R tree or
# in RBENCH_LIB_ROOT. No system library has `/libs/` in its path, and the
# interpreter itself is `bin/exec/R`.
PACKAGE_DSO <- "/libs/[^/]+\\.so"

#' Every frame, with the region it contributes and which rule said so. The three
#' rules are the branches of one `case_when`, so their priority is the order they
#' are written in and nothing else.
classify_frames <- function(frames, rules) {
  stopifnot(!anyDuplicated(rules$sym))
  interpreter_dso <- interpreter_object(frames)

  frames <- frames |>
    arrange(sample_id, frame_pos) |>
    mutate(dso_kind = case_when(
      dso %in% c("[unknown]", "inlined") ~ "unknown",
      dso == interpreter_dso ~ "interpreter",
      str_detect(dso, "ld-linux|/libc\\.so|/libm\\.so|/libpthread") ~ "syslib",
      .default = "native"
    ))

  frames |>
    left_join(rules, by = "sym") |>
    mutate(
      blas = str_detect(dso, NATIVE_MATH_DSO),
      pkg = str_detect(dso, PACKAGE_DSO),
      shape = dso_kind == "interpreter" &
        (str_detect(sym, PRIMITIVE_SYM) | str_detect(sym, ALTREP_SYM)),
      rule = case_when(blas ~ "0 BLAS object", pkg ~ "0 package object",
                       !is.na(category) ~ "1 symbol", shape ~ "2 symbol shape",
                       .default = NA_character_),
      category = case_when(
        blas ~ "native-blas",
        pkg ~ "native-ffi",
        !is.na(category) ~ category,
        shape ~ "primitives",
        .default = NA_character_
      )
    ) |>
    select(-priority, -blas, -pkg, -shape)
}

#' One row per stack frame of a recording, as `perf script` reported it.
read_perf_frames <- function(path) {
  read_csv(path, lazy = FALSE, progress = FALSE, col_types = cols(
    sample_id = col_integer(),
    timestamp = col_double(),
    frame_pos = col_integer(),
    sym = col_character(),
    dso = col_character()
  ))
}


# ---------------------------------------------------------------------------
# reading a recording: phase markers, and one row per sample
# ---------------------------------------------------------------------------
# Moved here from `categories.Rmd` when `perf-sweep.Rmd` needed the same walk.
# A second copy would have been a second thing to keep in step with the rules
# above, and the rules and the walk only mean anything together.

read_perf_marks <- function(path) {
  lines <- if (file.exists(path)) read_lines(path, progress = FALSE) else character()
  fields <- str_split_fixed(str_subset(lines, "^MARK\t"), "\t", 4)
  tibble(
    region = fields[, 2],
    begin = as.numeric(fields[, 3]),
    end = as.numeric(fields[, 4])
  )
}

#' Tag each sample with the harness phase its timestamp falls in.
#'
#' NA outside every phase, which is R's own startup before the first one and the
#' interpreter shutting down after the last -- so `region == "execute"` is the
#' benchmark kernel and nothing else. NA for every sample of a recording with no
#' markers. The phases are siblings, so their intervals are disjoint and the
#' assignment is a scan.
add_marked_region <- function(samples, marks) {
  region <- rep(NA_character_, nrow(samples))
  marks <- filter(marks, !is.na(begin), !is.na(end))
  for (i in seq_len(nrow(marks))) {
    inside <- samples$timestamp >= marks$begin[[i]] & samples$timestamp <= marks$end[[i]]
    region[inside] <- marks$region[[i]]
  }
  mutate(samples, region = region)
}

#' One row per sample: the innermost classified frame, and what it took to reach.
#'
#' `skipped` is how many frames the walk stepped over -- 0 means the rule named
#' the function that was executing. `phase` is which of `Startup` / `Repl` the
#' sample fell in; both are ancestors of everything, so they never win the
#' innermost race and are carried separately. `interp_frames` is how much of the
#' stack was R at all, which is what makes an unclassified sample diagnosable.
sample_regions <- function(frames) {
  innermost <- frames |>
    filter(!is.na(category)) |>
    arrange(sample_id, frame_pos) |>
    distinct(sample_id, .keep_all = TRUE) |>
    select(sample_id, category, rule, category_sym = sym,
           category_depth = frame_pos)

  phases <- frames |>
    filter(category %in% c("Startup", "Repl")) |>
    arrange(sample_id, frame_pos) |>
    distinct(sample_id, .keep_all = TRUE) |>
    select(sample_id, phase = category)

  frames |>
    distinct(sample_id, .keep_all = TRUE) |>   # sorted, so this is frame_pos 1
    select(sample_id, timestamp, region, leaf_sym = sym, leaf_dso = dso,
           leaf_kind = dso_kind) |>
    mutate(native_math = str_detect(leaf_dso, NATIVE_MATH_DSO)) |>
    left_join(count(frames, sample_id, name = "stack_depth"), by = "sample_id") |>
    left_join(count(filter(frames, dso_kind == "interpreter"), sample_id,
                    name = "interp_frames"), by = "sample_id") |>
    left_join(innermost, by = "sample_id") |>
    left_join(phases, by = "sample_id") |>
    mutate(interp_frames = coalesce(interp_frames, 0L),
           skipped = category_depth - 1L)
}

#' What the whole recording looked like: how much of it the markers claimed, how
#' much was R starting up, how well it unwound. About the recording rather than
#' the benchmark, which is why it is computed before the kernel cut.
summarise_run <- function(samples) {
  tibble(
    n_samples = nrow(samples),
    n_frames = sum(samples$stack_depth),
    mean_stack_depth = mean(samples$stack_depth),
    phase_resolved_pct = 100 * mean(!is.na(samples$phase)),
    startup_pct = 100 * mean(!is.na(samples$phase) & samples$phase == "Startup"),
    n_kernel_samples = sum(!is.na(samples$phase) & samples$phase == "Repl"),
    marked_pct = 100 * mean(!is.na(samples$region)),
    execute_pct = 100 * mean(!is.na(samples$region) & samples$region == "execute"),
    native_math_pct = 100 * mean(samples$native_math),
    unattributed_pct = 100 * mean(is.na(samples$category)),
    sampled_span_s = max(samples$timestamp) - min(samples$timestamp)
  )
}

#' Why a kernel sample carries no region at all -- read off the stack rather than
#' guessed. A sample with no R frame never reached the interpreter, one whose
#' frames are all unresolved was not unwound, and one with R frames and no match
#' is the case that means a missing rule.
unclassified_causes <- function(kernel) {
  kernel |>
    filter(is.na(category)) |>
    mutate(cause = case_when(
      interp_frames == 0 & leaf_kind == "unknown" ~ "unresolved stack",
      interp_frames == 0 & leaf_kind == "syslib" ~ "never entered R (libc / linker)",
      interp_frames == 0 ~ "never entered R (other object)",
      stack_depth <= 2 ~ "truncated unwind",
      .default = "R frames, no rule matched"
    )) |>
    count(cause, leaf_sym, leaf_dso, name = "samples")
}

