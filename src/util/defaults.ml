(** Default values for [GobConfig]-style configuration. *)

open Prelude
open Printf
open List

(* TODO: add consistency checking *)

(** Main categories of configuration variables. *)
type category = Std             (** Parsing input, includes, standard stuff, etc. *)
              | Analyses        (** Analyses                                      *)
              | Transformations (** Transformations                               *)
              | Experimental    (** Experimental features of analyses             *)
              | Debugging       (** Debugging, tracing, etc.                      *)

(** Description strings for categories. *)
let catDescription = function
  | Std             -> "Standard options for configuring input/output"
  | Analyses        -> "Options for analyses"
  | Transformations -> "Options for transformations"
  | Experimental    -> "Experimental features"
  | Debugging       -> "Debugging options"

(** A place to store registered variables *)
let registrar = ref []

(** A function to register a variable *)
let reg (c:category) (n:string) (def:string) (desc:string) =
  registrar := (c,(n,(desc,def))) :: !registrar;
  GobConfig.(build_config := true; set_auto n def; build_config := false)

(** find all associations in the list *)
let rec assoc_all k = function
  | [] -> []
  | (x1,x2)::xs when k=x1 -> x2 :: assoc_all k xs
  | _::xs -> assoc_all k xs

(** Prints out all registered options with descriptions and defaults for one category. *)
let printCategory ch k =
  let print_one (n,(desc,def)) =
    fprintf ch "%-4s%-30s%s\n%-34sDefault value: \"%s\"\n\n" "" n desc "" def
  in
  catDescription k |> fprintf ch "%s:\n";
  assoc_all k !registrar |> rev |> iter print_one

(** Prints out all registered options. *)
let printAllCategories ch =
  iter (printCategory ch) [Std;Analyses;Experimental;Debugging]

(* {4 category [Std]} *)
let _ = ()
      ; reg Std "outfile"         ""             "File to print output to."
      ; reg Std "includes"        "[]"           "List of directories to include."
      ; reg Std "kernel_includes" "[]"           "List of kernel directories to include."
      ; reg Std "custom_includes" "[]"           "List of custom directories to include."
      ; reg Std "custom_incl"     "''"           "Use custom includes"
      ; reg Std "custom_libc"     "false"        "Use goblints custom libc."
      ; reg Std "justcil"         "false"        "Just parse and output the CIL."
      ; reg Std "justcfg"         "false"        "Only output the CFG in cfg.dot ."
      ; reg Std "dopartial"       "false"        "Use Cil's partial evaluation & constant folding."
      ; reg Std "printstats"      "false"        "Outputs timing information."
      ; reg Std "gccwarn"         "false"        "Output warnings in GCC format."
      ; reg Std "verify"          "true"         "Verify that the solver reached a post-fixpoint. Beware that disabling this also disables output of warnings since post-processing of the results is done in the verification phase!"
      ; reg Std "mainfun"         "['main']"     "Sets the name of the main functions."
      ; reg Std "exitfun"         "[]"           "Sets the name of the cleanup functions."
      ; reg Std "otherfun"        "[]"           "Sets the name of other functions."
      ; reg Std "allglobs"        "false"        "Prints access information about all globals, not just races."
      ; reg Std "keepcpp"         "false"        "Keep the intermediate output of running the C preprocessor."
      ; reg Std "tempDir"         "''"           "Reuse temporary directory for preprocessed files."
      ; reg Std "cppflags"        "''"           "Pre-processing parameters."
      ; reg Std "kernel"          "false"        "For analyzing Linux Device Drivers."
      ; reg Std "dump_globs"      "false"        "Print out the global invariant."
      ; reg Std "result"          "'none'"       "Result style: none, indented, compact, fast_xml, json, mongo, or pretty."
      ; reg Std "warnstyle"       "'pretty'"     "Result style: legacy, pretty, or xml."
      ; reg Std "solver"          "'td3'"         "Picks the solver."
      ; reg Std "comparesolver"   "''"           "Picks another solver for comparison."
      ; reg Std "solverdiffs"     "false"        "Print out solver differences."
      ; reg Std "allfuns"         "false"        "Analyzes all the functions (not just beginning from main). This requires exp.earlyglobs!"
      ; reg Std "nonstatic"       "false"        "Analyzes all non-static functions."
      ; reg Std "colors"          "false"        "Colored output."
      ; reg Std "g2html"          "false"        "Run g2html.jar on the generated xml."
      ; reg Std "interact.out"    "'result'"     "The result directory in interactive mode."
      ; reg Std "interact.enabled" "false"       "Is interactive mode enabled."
      ; reg Std "interact.paused" "false"        "Start interactive in pause mode."
      ; reg Std "phases"          "[]"           "List of phases. Per-phase settings overwrite global ones."
      ; reg Std "save_run"        "''"           "Save the result of the solver, the current configuration and meta-data about the run to this directory (if set). The data can then be loaded (without solving again) to do post-processing like generating output in a different format or comparing results."
      ; reg Std "load_run"        "''"           "Load a saved run. See save_run."
      ; reg Std "compare_runs"    "[]"           "Load these saved runs and compare the results. Note that currently only two runs can be compared!"

(* {4 category [Analyses]} *)
let _ = ()
      ; reg Analyses "ana.activated"  "['expRelation','base','escape','mutex']"  "Lists of activated analyses in this phase."
      ; reg Analyses "ana.path_sens"  "['OSEK','OSEK2','mutex','malloc_null','uninit']"  "List of path-sensitive analyses"
      ; reg Analyses "ana.ctx_insens" "['OSEK2','stack_loc','stack_trace_set']"                      "List of context-insensitive analyses"
      ; reg Analyses "ana.warnings"        "false" "Print soundness warnings."
      ; reg Analyses "ana.cont.localclass" "false" "Analyzes classes defined in main Class."
      ; reg Analyses "ana.cont.class"      "''"    "Analyzes all the member functions of the class (CXX.json file required)."
      ; reg Analyses "ana.osek.oil"        "''"    "Oil file for the analyzed program"
      ; reg Analyses "ana.osek.defaults"   "true"  "Generate default definitions for TASK and ISR"
      (* ; reg Analyses "ana.osek.tramp"      "''"    "Resource-ID-headers for the analyzed program" *)
      ; reg Analyses "ana.osek.isrprefix"  "'function_of_'"    "Prefix added by the ISR macro"
      ; reg Analyses "ana.osek.taskprefix" "'function_of_'"    "Prefix added by the TASK macro"
      ; reg Analyses "ana.osek.isrsuffix"  "''"    "Suffix added by the ISR macro"
      ; reg Analyses "ana.osek.tasksuffix" "''"    "Suffix added by the TASK macro"
      ; reg Analyses "ana.osek.intrpts"    "false" "Enable constraints for interrupts."
      ; reg Analyses "ana.osek.check"      "false" "Check if (assumed) OSEK conventions are fullfilled."
      ; reg Analyses "ana.osek.names"      "[]"    "OSEK API function (re)names for the analysed program"
      ; reg Analyses "ana.osek.warnfiles"  "false" "Print all warning types to separate file"
      ; reg Analyses "ana.osek.safe_vars"  "[]"    "Suppress warnings on these vars"
      ; reg Analyses "ana.osek.safe_task"  "[]"    "Ignore accesses in these tasks"
      ; reg Analyses "ana.osek.safe_isr"   "[]"    "Ignore accesses in these isr"
      ; reg Analyses "ana.osek.flags"      "[]"    "List of global variables that are flags."
      ; reg Analyses "ana.osek.def_header" "true"  "Generate TASK/ISR macros with default structure"
      ; reg Analyses "ana.int.def_exc"      "true"  "Use IntDomain.DefExc: definite value/exclusion set."
      ; reg Analyses "ana.int.interval"    "false" "Use IntDomain.Interval32: int64 * int64) option."
      ; reg Analyses "ana.int.enums"       "false" "Use IntDomain.Enums: Inclusion/Exclusion sets. Go to top on arithmetic operations after ana.int.enums_max values. Joins on widen, i.e. precise integers as long as not derived from arithmetic expressions."
      ; reg Analyses "ana.int.enums_max"   "1"     "Maximum number of resulting elements of operations before going to top. Widening is still just the join, so this might increase the size by n^2!"
      ; reg Analyses "ana.int.cinterval"   "false" "Use IntDomain.CircInterval: Wrapped, Signedness agnostic intervals."
      ; reg Analyses "ana.int.cdebug"      "false" "Debugging output for wrapped interval analysis."
      ; reg Analyses "ana.int.cwiden"      "'basic'" "Widening variant to use for wrapped interval analysis ('basic', 'double')"
      ; reg Analyses "ana.int.cnarrow"     "'basic'" "Narrowing variant to use for wrapped interval analysis ('basic', 'half')"
      ; reg Analyses "ana.file.optimistic" "false" "Assume fopen never fails."
      ; reg Analyses "ana.spec.file"       ""      "Path to the specification file."
      ; reg Analyses "ana.pml.debug"       "true"  "Insert extra assertions into Promela code for debugging."
      ; reg Analyses "ana.arinc.assume_success" "true"    "Assume that all ARINC functions succeed (sets return code to NO_ERROR, otherwise invalidates it)."
      ; reg Analyses "ana.arinc.simplify"    "true" "Simplify the graph by merging functions consisting of the same edges and contracting call chains where functions just consist of another call."
      ; reg Analyses "ana.arinc.validate"    "true" "Validate the graph and output warnings for: call to functions without edges, multi-edge-calls for intermediate contexts, branching on unset return variables."
      ; reg Analyses "ana.arinc.export"    "true" "Generate dot graph and Promela for ARINC calls right after analysis. Result is saved in result/arinc.out either way."
      ; reg Analyses "ana.arinc.merge_globals" "false"  "Merge all global return code variables into one."
      ; reg Analyses "ana.opt.hashcons"        "true"  "Should we try to save memory and speed up equality by hashconsing?"
      ; reg Analyses "ana.opt.equal"       "true"  "First try physical equality (==) before {D,G,C}.equal (only done if hashcons is disabled since it basically does the same via its tags)."
      ; reg Analyses "ana.restart_count"   "1"     "How many times SLR4 is allowed to switch from restarting iteration to increasing iteration."
      ; reg Analyses "ana.mutex.disjoint_types" "true" "Do not propagate basic type writes to all struct fields"
      ; reg Analyses "ana.sv-comp"         "false" "SV-COMP mode"

(* {4 category [Transformations]} *)
let _ = ()
      ; reg Transformations "trans.activated" "[]"  "Lists of activated transformations in this phase. Transformations happen after analyses."

(* {4 category [Experimental]} *)
let _ = ()
      ; reg Experimental "exp.privatization"     "true"  "Use privatization?"
      ; reg Experimental "exp.cfgdot"            "false" "Output CFG to dot files"
      ; reg Experimental "exp.mincfg"            "false" "Try to minimize the number of CFG nodes."
      ; reg Experimental "exp.earlyglobs"        "false" "Side-effecting of globals right after initialization."
      ; reg Experimental "exp.failing-locks"     "false" "Takes the possible failing of locking operations into account."
      ; reg Experimental "exp.region-offsets"    "false" "Considers offsets for region accesses."
      ; reg Experimental "exp.unique"            "[]"    "For types that have only one value."
      ; reg Experimental "exp.forward"           "false" "Use implicit forward propagation instead of the demand driven approach."
      ; reg Experimental "exp.full-context"      "false" "Do not side-effect function entries. If partial contexts (or ana.ctx_insens) are used, this will fail!"
      ; reg Experimental "exp.addr-context"      "false" "Ignore non-address values in function contexts."
      ; reg Experimental "exp.no-int-context"    "false" "Ignore all integer values in function contexts."
      ; reg Experimental "exp.no-interval32-context" "false" "Ignore integer values of the Interval32 domain in function contexts."
      ; reg Experimental "exp.malloc-fail"       "false" "Consider the case where malloc fails."
      ; reg Experimental "exp.volatiles_are_top" "true"  "volatile and extern keywords set variables permanently to top"
      ; reg Experimental "exp.single-threaded"   "false" "Ensures analyses that no threads are created."
      ; reg Experimental "exp.globs_are_top"     "false" "Set globals permanently to top."
      ; reg Experimental "exp.unknown_funs_spawn" "true" "Should unknown function calls spawn reachable functions and switch to MT-mode?"
      ; reg Experimental "exp.precious_globs"    "[]"    "Global variables that should be handled flow-sensitively when using earlyglobs."
      ; reg Experimental "exp.list-type"         "false" "Use a special abstract value for lists."
      ; reg Experimental "exp.g2html_path"       "'.'"   "Location of the g2html.jar file."
      ; reg Experimental "exp.extraspecials"     "[]"    "List of functions that must be analyzed as unknown extern functions"
      ; reg Experimental "exp.ignored_threads"   "[]"    "Eliminate accesses in these threads"
      ; reg Experimental "exp.no-narrow"         "false" "Overwrite narrow a b = a"
      ; reg Experimental "exp.basic-blocks"      "false" "Only keep values for basic blocks instead of for every node. Should take longer but need less space."
      ; reg Experimental "exp.widen-context"     "false" "Do widening on contexts. Method depends on exp.full-context - costly if true."
      ; reg Experimental "exp.solver.td3.term"  "true" "Should the td3 solver use the phased/terminating strategy?"
      ; reg Experimental "exp.solver.td3.side_widen"  "'cycle'" "When to widen in side. never: never widen, always: always widen, cycle: widen if any called var gets destabilzed, cycle_self: widen if side-effected var gets destabilized"
      ; reg Experimental "exp.solver.td3.space" "false" "Should the td3 solver only keep values at widening points?"
      ; reg Experimental "exp.solver.td3.space_cache" "true" "Should the td3-space solver cache values?"
      ; reg Experimental "exp.solver.td3.space_restore" "true" "Should the td3-space solver restore values for non-widening-points? Needed for inspecting output!"
      ; reg Experimental "exp.fast_global_inits" "false" "Only generate 'a[0] = 0' for a zero-initialized array a[n]. This is only sound for our flat array domain! TODO change this once we use others!"
      ; reg Experimental "exp.uninit-ptr-safe"   "false" "Assume that uninitialized stack-allocated pointers may only point to variables not in the program or null."
      ; reg Experimental "exp.ptr-arith-safe"    "false" "Assume that pointer arithmetic only yields safe addresses."
      ; reg Experimental "exp.minwitness"        "false" "Try to minimize the witness"
      ; reg Experimental "exp.uncilwitness"      "false" "Try to undo CIL control flow transformations in witness"
      ; reg Experimental "exp.partition-arrays.enabled"  "false" "Employ the partitioning array domain. When this is on, make sure to enable the expRelation analysis as well."
      ; reg Experimental "exp.partition-arrays.keep-expr" "'first'" "When using the partitioning which expression should be used for partitioning ('first', 'last')"
      ; reg Experimental "exp.partition-arrays.partition-by-const-on-return" "false" "When using the partitioning should arrays be considered partitioned according to a constant if a var in the expression used for partitioning goes out of scope?"
      ; reg Experimental "exp.partition-arrays.smart-join" "false" "When using the partitioning should the join of two arrays partitioned according to different expressions be partitioned as well if possible? If keep-expr is 'last' this behavior is enabled regardless of the flag value. Caution: Not always advantageous."
      ; reg Experimental "exp.incremental.mode"  "'off'" "Use incremental analysis in the TD3 solver. Values: off (default), incremental (analyze based on data from a previous commit or fresh if there is none), complete (discard loaded data and start fresh)."
      ; reg Experimental "exp.incremental.stable" "true" "Reuse the stable set and selectively destabilize it."
      ; reg Experimental "exp.incremental.wpoint" "false" "Reuse the wpoint set."
      ; reg Experimental "exp.gcc_path"           "'/usr/bin/gcc-6'" "Location of gcc-6. Used to combine source files with cilly."

(* {4 category [Debugging]} *)
let _ = ()
      ; reg Debugging "dbg.debug"           "false" "Debug mode: for testing the analyzer itself."
      ; reg Debugging "dbg.verbose"         "false" "Prints some status information."
      ; reg Debugging "dbg.trace.context"   "false" "Also print the context of solver variables."
      ; reg Debugging "dbg.showtemps"       "false" "Shows CIL's temporary variables when printing the state."
      ; reg Debugging "dbg.uncalled"        "false" "Display uncalled functions."
      ; reg Debugging "dbg.dump"            ""      "Dumps the results to the given path"
      ; reg Debugging "dbg.cilout"          ""      "Where to dump cil output"
      ; reg Debugging "dbg.timeout"         "0"     "Maximal time for analysis. (0 -- no timeout)"
      ; reg Debugging "dbg.solver-signal"   "'sigint'" "Signal to interrupt the solver to print statistics. Can be sigint (Ctrl+C, default), sigtstp (Ctrl+Z), or sigquit (Ctrl+\\)."
      ; reg Debugging "dbg.solver-progress" "false" "Used for debugging. Prints out a symbol on solving a rhs."
      ; reg Debugging "dbg.print_dead_code" "false" "Print information about dead code"
      ; reg Debugging "dbg.slice.on"        "false" "Turn slicer on or off."
      ; reg Debugging "dbg.slice.n"         "10"    "How deep function stack do we analyze."
      ; reg Debugging "dbg.limit.widen"     "0"     "Limit for number of widenings per node (0 = no limit)."
      ; reg Debugging "dbg.earlywarn"       "false" "Output warnings already while solving (may lead to spurious warnings/asserts that would disappear after narrowing)."
      ; reg Debugging "dbg.warn_with_context" "false" "Keep warnings for different contexts apart (currently only done for asserts)."
      ; reg Debugging "dbg.regression"      "false" "Only output warnings for assertions that have an unexpected result (no comment, comment FAIL, comment UNKNOWN)"
      ; reg Debugging "dbg.test.domain"     "false" "Test domain properties"

let default_schema = "\
{ 'id'              : 'root'
, 'type'            : 'object'
, 'required'        : ['outfile', 'includes', 'kernel_includes', 'custom_includes', 'custom_incl', 'custom_libc', 'justcil', 'justcfg', 'dopartial', 'printstats', 'gccwarn', 'verify', 'mainfun', 'exitfun', 'otherfun', 'allglobs', 'keepcpp', 'tempDir', 'cppflags', 'kernel', 'dump_globs', 'result', 'warnstyle', 'solver', 'allfuns', 'nonstatic', 'colors', 'g2html']
, 'additionalProps' : false
, 'properties' :
  { 'ana' :
    { 'type'            : 'object'
    , 'additionalProps' : true
    , 'required'        : []
    }
  , 'trans'             : {}
  , 'phases'            : {}
  , 'exp' :
    { 'type'            : 'object'
    , 'additionalProps' : true
    , 'required'        : []
    }
  , 'dbg' :
    { 'type'            : 'object'
    , 'additionalProps' : true
    , 'required'        : []
    }
  , 'questions' :
    { 'file'            : ''
    }
  , 'outfile'         : {}
  , 'includes'        : {}
  , 'kernel_includes' : {}
  , 'custom_includes' : {}
  , 'custom_incl'     : {}
  , 'custom_libc'     : {}
  , 'justcil'         : {}
  , 'justcfg'         : {}
  , 'dopartial'       : {}
  , 'printstats'      : {}
  , 'gccwarn'         : {}
  , 'verify'        : {}
  , 'mainfun'         : {}
  , 'exitfun'         : {}
  , 'otherfun'        : {}
  , 'allglobs'        : {}
  , 'keepcpp'         : {}
  , 'tempDir'         :
    { 'type'            : 'string'
    }
  , 'cppflags'        : {}
  , 'kernel'          : {}
  , 'dump_globs'      : {}
  , 'result'          :
    { 'type'            : 'string'
    }
  , 'warnstyle'          :
    { 'type'            : 'string'
    }
  , 'solver'          : {}
  , 'comparesolver'   : {}
  , 'solverdiffs'     : {}
  , 'allfuns'         : {}
  , 'nonstatic'       : {}
  , 'colors'          : {}
  , 'g2html'          : {}
  , 'interact'        : {}
  , 'save_run'        : {}
  , 'load_run'        : {}
  , 'compare_runs'    : {}
  }
}"

let _ =
  let v = JsonParser.value JsonLexer.token @@ Lexing.from_string default_schema in
  GobConfig.addenum_sch v
