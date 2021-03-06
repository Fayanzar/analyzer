open MyCFG
open WitnessUtil
open Graphml
open Svcomp
open GobConfig

let write_file filename (module Task:Task) (module TaskResult:TaskResult): unit =
  let module Cfg = Task.Cfg in
  let loop_heads = find_loop_heads (module Cfg) Task.file in

  let module TaskResult = StackTaskResult (Cfg) (TaskResult) in
  let module N = TaskResult.Arg.Node in
  let module IsInteresting =
  struct
    (* type t = N.t *)
    let minwitness = get_bool "exp.minwitness"
    let is_interesting_real from_node edge to_node =
      (* TODO: don't duplicate this logic with write_node, write_edge *)
      (* startlines aren't currently interesting because broken, see below *)
      let from_cfgnode = N.cfgnode from_node in
      let to_cfgnode = N.cfgnode to_node in
      if TaskResult.is_violation to_node || TaskResult.is_sink to_node then
        true
      else if WitnessUtil.NH.mem loop_heads to_cfgnode then
        true
      else begin match edge with
        | Test _ -> true
        | _ -> false
      end || begin match to_cfgnode, TaskResult.invariant to_node with
          | Statement _, Some _ -> true
          | _, _ -> false
        end || begin match from_cfgnode, to_cfgnode with
          | _, FunctionEntry f -> true
          | Function f, _ -> false
          | _, _ -> false
        end
    let is_interesting from_node edge to_node =
      not minwitness || is_interesting_real from_node edge to_node
  end
  in
  let module Arg = TaskResult.Arg in
  let module Arg = MyARG.InterestingArg (Arg) (IsInteresting) in

  let module N = Arg.Node in
  let module GML = DeDupGraphMlWriter (N) (ArgNodeGraphMlWriter (N) (XmlGraphMlWriter)) in
  let module NH = Hashtbl.Make (N) in

  let main_entry = Arg.main_entry in

  let out = open_out filename in
  let g = GML.start out in

  GML.write_key g "graph" "witness-type" "string" None;
  GML.write_key g "graph" "sourcecodelang" "string" None;
  GML.write_key g "graph" "producer" "string" None;
  GML.write_key g "graph" "specification" "string" None;
  GML.write_key g "graph" "programfile" "string" None;
  GML.write_key g "graph" "programhash" "string" None;
  GML.write_key g "graph" "architecture" "string" None;
  GML.write_key g "graph" "creationtime" "string" None;
  GML.write_key g "node" "entry" "boolean" (Some "false");
  GML.write_key g "node" "sink" "boolean" (Some "false");
  GML.write_key g "node" "violation" "boolean" (Some "false");
  GML.write_key g "node" "invariant" "string" None;
  GML.write_key g "node" "invariant.scope" "string" None;
  GML.write_key g "edge" "assumption" "string" None;
  GML.write_key g "edge" "assumption.scope" "string" None;
  GML.write_key g "edge" "assumption.resultfunction" "string" None;
  GML.write_key g "edge" "control" "string" None;
  GML.write_key g "edge" "startline" "int" None;
  GML.write_key g "edge" "endline" "int" None;
  GML.write_key g "edge" "startoffset" "int" None;
  GML.write_key g "edge" "endoffset" "int" None;
  GML.write_key g "edge" "enterLoopHead" "boolean" (Some "false");
  GML.write_key g "edge" "enterFunction" "string" None;
  GML.write_key g "edge" "returnFromFunction" "string" None;
  GML.write_key g "edge" "threadId" "string" None;
  GML.write_key g "edge" "createThread" "string" None;

  GML.write_key g "node" "goblintNode" "string" None;
  GML.write_key g "edge" "goblintEdge" "string" None;
  GML.write_key g "edge" "goblintLine" "string" None;

  GML.write_metadata g "witness-type" (if TaskResult.result then "correctness_witness" else "violation_witness");
  GML.write_metadata g "sourcecodelang" "C";
  GML.write_metadata g "producer" (Printf.sprintf "Goblint (%s)" Version.goblint);
  GML.write_metadata g "specification" Task.specification;
  let programfile = (getLoc (N.cfgnode main_entry)).file in
  GML.write_metadata g "programfile" programfile;
  (* TODO: programhash *)
  (* TODO: architecture *)
  GML.write_metadata g "creationtime" (TimeUtil.iso8601_now ());

  let write_node ?(entry=false) node =
    let cfgnode = N.cfgnode node in
    GML.write_node g node (List.concat [
        begin if entry then
            [("entry", "true")]
          else
            []
        end;
        begin match cfgnode, TaskResult.invariant node with
          | Statement _, Some i ->
            [("invariant", i);
             ("invariant.scope", (getFun cfgnode).svar.vname)]
          | _ ->
            (* ignore entry and return invariants, variables of wrong scopes *)
            (* TODO: don't? fix scopes? *)
            []
        end;
        begin match cfgnode with
          | Statement s ->
            [("sourcecode", Pretty.sprint 80 (Basetype.CilStmt.pretty () s))] (* TODO: sourcecode not official? especially on node? *)
          | _ -> []
        end;
        (* violation actually only allowed in violation witness *)
        (* maybe should appear on from_node of entry edge instead *)
        begin if TaskResult.is_violation node then
            [("violation", "true")]
          else
            []
        end;
        begin if TaskResult.is_sink node then
            [("sink", "true")]
          else
            []
        end;
        [("goblintNode", match cfgnode with
           | Statement stmt  -> Printf.sprintf "s%d" stmt.sid
           | Function f      -> Printf.sprintf "ret%d%s" f.vid f.vname
           | FunctionEntry f -> Printf.sprintf "fun%d%s" f.vid f.vname
          )]
      ])
  in
  let write_edge from_node edge to_node =
    let from_cfgnode = N.cfgnode from_node in
    let to_cfgnode = N.cfgnode to_node in
    GML.write_edge g from_node to_node (List.concat [
        (* TODO: add back loc as argument with edge? *)
        (* begin if loc.line <> -1 then
               [("startline", string_of_int loc.line);
                ("endline", string_of_int loc.line)]
             else
               []
           end; *)
        begin let loc = getLoc from_cfgnode in
          (* exclude line numbers from sv-comp.c and unknown line numbers *)
          if loc.file = programfile && loc.line <> -1 then
            (* TODO: startline disabled because Ultimate doesn't like our line numbers for some reason *)
            (* [("startline", string_of_int loc.line)] *)
            [("goblintLine", string_of_int loc.line)]
          else
            []
        end;
        begin if WitnessUtil.NH.mem loop_heads to_cfgnode then
            [("enterLoopHead", "true")]
          else
            []
        end;
        begin match from_cfgnode, to_cfgnode with
          | _, FunctionEntry f ->
            [("enterFunction", f.vname)]
          | Function f, _ ->
            [("returnFromFunction", f.vname)]
          | _, _ -> []
        end;
        begin match edge with
          (* control actually only allowed in violation witness *)
          | Test (_, b) ->
            [("control", "condition-" ^ string_of_bool b)]
          (* enter and return on other side of nodes,
             more correct loc (startline) but had some scope problem? *)
          | Entry f ->
            [("enterFunction2", f.svar.vname)]
          | Ret (_, f) ->
            [("returnFromFunction2", f.svar.vname)]
          | _ -> []
        end;
        [("goblintEdge", Pretty.sprint 80 (pretty_edge () edge))]
      ])
  in

  (* DFS with BFS-like child ordering, just for nicer ordering of witness graph children *)
  let itered_nodes = NH.create 100 in
  let rec iter_node node =
    if not (NH.mem itered_nodes node) then begin
      NH.add itered_nodes node ();
      write_node node;
      let is_sink = TaskResult.is_violation node || TaskResult.is_sink node in
      if not is_sink then begin
        let edge_to_nodes =
          Arg.next node
          (* TODO: keep control (Test) edges to dead (sink) nodes for violation witness? *)
        in
        List.iter (fun (edge, to_node) ->
            write_node to_node;
            write_edge node edge to_node
          ) edge_to_nodes;
        List.iter (fun (edge, to_node) ->
            iter_node to_node
          ) edge_to_nodes
      end
    end
  in

  write_node ~entry:true main_entry;
  iter_node main_entry;

  GML.stop g;
  close_out_noerr out

open Analyses
module Result (Cfg : CfgBidir)
              (Spec : SpecHC)
              (EQSys : GlobConstrSys with module LVar = VarF (Spec.C)
                                  and module GVar = Basetype.Variables
                                  and module D = Spec.D
                                  and module G = Spec.G)
              (LHT : BatHashtbl.S with type key = EQSys.LVar.t)
              (GHT : BatHashtbl.S with type key = EQSys.GVar.t) = struct
  let write result_fold file lh gh local_xml liveness entrystates =
    let svcomp_unreach_call =
      let dead_verifier_error (l, n, f) v acc =
        match n with
        (* FunctionEntry isn't used for extern __VERIFIER_error... *)
        | FunctionEntry f when f.vname = Svcomp.verifier_error ->
          let is_dead = not (liveness n) in
          acc && is_dead
        | _ -> acc
      in
      result_fold dead_verifier_error local_xml true
    in
    Printf.printf "SV-COMP (unreach-call): %B\n" svcomp_unreach_call;

    let (witness_prev, witness_next) =
      let ask_local (lvar:EQSys.LVar.t) local =
        (* build a ctx for using the query system *)
        let rec ctx =
          { ask    = query
          ; node   = fst lvar
          ; control_context = Obj.repr (fun () -> snd lvar)
          ; context = (fun () -> snd lvar)
          ; edge    = MyCFG.Skip
          ; local  = local
          ; global = GHT.find gh
          ; presub = []
          ; postsub= []
          ; spawn  = (fun v d    -> failwith "Cannot \"spawn\" in witness context.")
          ; split  = (fun d e tv -> failwith "Cannot \"split\" in witness context.")
          ; sideg  = (fun v g    -> failwith "Cannot \"split\" in witness context.")
          ; assign = (fun ?name _ -> failwith "Cannot \"assign\" in witness context.")
          }
        and query x = Spec.query ctx x in
        Spec.query ctx
      in
      (* let ask (lvar:EQSys.LVar.t) = ask_local lvar (LHT.find lh lvar) in *)

      let prev = LHT.create 100 in
      let next = LHT.create 100 in
      LHT.iter (fun lvar local ->
          ignore (ask_local lvar local (Queries.IterPrevVars (fun (prev_node, prev_c_obj) edge ->
              let prev_lvar: LHT.key = (prev_node, Obj.obj prev_c_obj) in
              LHT.modify_def [] lvar (fun prevs -> (edge, prev_lvar) :: prevs) prev;
              LHT.modify_def [] prev_lvar (fun nexts -> (edge, lvar) :: nexts) next
            )))
        ) lh;

      ((fun n ->
          LHT.find_default prev n []), (* main entry is not in prev at all *)
      (fun n ->
          LHT.find_default next n [])) (* main return is not in next at all *)
    in

    let get: node * Spec.C.t -> Spec.D.t =
      fun nc -> LHT.find_default lh nc (Spec.D.bot ())
    in

    let module Arg =
    struct
      module Node =
      struct
        include EQSys.LVar

        let cfgnode = node

        let to_string (n, c) =
          (* copied from NodeCtxStackGraphMlWriter *)
          let c_tag = Spec.C.tag c in
          match n with
          | Statement stmt  -> Printf.sprintf "s%d(%d)" stmt.sid c_tag
          | Function f      -> Printf.sprintf "ret%d%s(%d)" f.vid f.vname c_tag
          | FunctionEntry f -> Printf.sprintf "fun%d%s(%d)" f.vid f.vname c_tag

        let move (n, c) to_n = (to_n, c)
        let is_live node = not (Spec.D.is_bot (get node))
      end

      let main_entry = WitnessUtil.find_main_entry entrystates
      let next = witness_next
    end
    in
    let module Arg =
    struct
      open MyARG
      module ArgIntra = UnCilTernaryIntra (UnCilLogicIntra (CfgIntra (Cfg)))
      include Intra (Arg.Node) (ArgIntra) (Arg)
    end
    in

    let find_invariant nc = Spec.D.invariant "" (get nc) in

    let module Task = struct
        let file = file
        let specification = Svcomp.unreach_call_specification

        module Cfg = Cfg
      end
    in

    if svcomp_unreach_call then (
      let module TaskResult =
      struct
        module Arg = Arg
        let result = true
        let invariant = find_invariant
        let is_violation _ = false
        let is_sink _ = false
      end
      in
      write_file "witness.graphml" (module Task) (module TaskResult)
    ) else (
      let is_violation = function
        | FunctionEntry f, _ when f.vname = Svcomp.verifier_error -> true
        | _, _ -> false
      in
      let is_sink =
        (* TODO: somehow move this to witnessUtil *)
        let non_sinks = LHT.create 100 in

        (* DFS *)
        let rec iter_node node =
          if not (LHT.mem non_sinks node) then (
            LHT.replace non_sinks node ();
            List.iter (fun (_, prev_node) ->
                iter_node prev_node
              ) (witness_prev node)
          )
        in

        LHT.iter (fun lvar _ ->
            if is_violation lvar then
              iter_node lvar
          ) lh;

        fun n ->
          not (LHT.mem non_sinks n)
      in
      let module TaskResult =
      struct
        module Arg = Arg
        let result = false
        let invariant _ = Invariant.none
        let is_violation = is_violation
        let is_sink = is_sink
      end
      in
      write_file "witness.graphml" (module Task) (module TaskResult)
    )
end
