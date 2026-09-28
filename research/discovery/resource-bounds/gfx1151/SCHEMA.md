# JSON shapes

Three formats, deliberately small, so an independent checker can consume them without adopting this
directory's Python. Every numeric field is an integer, a decimal string or an expression string;
nothing depends on float parsing for a load-bearing value.

## `kelana-resource-facts/1`

Generated, never hand-edited. Regenerate with `extract_facts.py`.

```json
{
  "format": "kelana-resource-facts/1",
  "target": "gfx1151",
  "sources": { "isa_xml": {"path": "...", "sha256": "..."}, "isa_text": {...} },
  "facts": [
    {
      "id": "ENC.VALU.MAX_SOURCE_FIELDS",
      "tier": "architectural",
      "kind": "encoding-capacity | semantic-capacity | scheduling-rule | capacity",
      "claim": "prose",
      "value": { "max_explicit_source_fields": 3 },
      "does_not_imply": { "scalar_word_arity": "a field is not a word; widest input field here is 256 bits" },
      "source": "isa_xml",
      "extraction": "how the value was computed from the source",
      "status": "derived"
    }
  ]
}
```

`extraction` is the contract: it must describe an operation on the pinned source that another program
could repeat. Everything `extract_facts.py` emits is `tier: architectural`, because it reads only
AMD's sources and nothing it reads is a cost.

`does_not_imply` is optional and load-bearing where present. A fact that invites a wrong reading
carries the correction with it: `ENC.VALU.MAX_SOURCE_FIELDS` records that a field is not a word and
names the 256-bit counterexample; `SEM.PERM.SELECTOR_ARITY` records that an arity bounds no group
size without a separation premise. A checker should surface these next to any step citing the fact.

## `kelana-resource-profile/1`

The cost space and everything not derivable from a source.

```json
{
  "format": "kelana-resource-profile/1",
  "bridge": { "tiers": {...}, "inheritance_rule": "...", "lower_bound_rule": "..." },
  "service_slot_semantics": { "what_a_slot_count_is": "...", "what_it_is_not": [...] },
  "cost_space": { "unit": "issue slot", "normalization": { "geometry": {...} } },
  "assumptions": [
    { "id": "SLOT.UNIT_VALU", "tier": "family-restriction", "statement": "...",
      "support": "...", "contradicting_evidence": "...", "if_false": "...", "used_by": [...] }
  ],
  "parameters": [
    { "id": "sigma_W_iu4", "status": "unproved", "no_source_value": "...",
      "candidates": [ {"value": 16, "status": "structural hypothesis, unproved", "argument": "..."} ],
      "break_even_in_cases": {"perm-vs-iu4-wmma": 24} }
  ],
  "evidence_roles": { "achievability-upper-bound": "...", "achieved-rate": "...", "source-derived": "..." },
  "no_defensible_hardware_lower_bound": [ {"question": "...", "answer": "...", "consequence": "..."} ]
}
```

`if_false` is required on every assumption and must say what survives, not only what breaks. An
assumption whose failure invalidates a bound is a different object from one whose failure makes the
bound conservative, and the difference belongs in the file.

## `kelana-resource-case/1`

One worked comparison.

```json
{
  "format": "kelana-resource-case/2",
  "id": "perm-vs-iu4-wmma",
  "operation_model": "MODEL.PERM_OBSERVER",
  "comparison_boundary": { "region": "...", "excluded_on_the_perm_side": [...],
                            "excluded_on_the_wmma_side": [...], "output_contracts_differ": "..." },
  "premises": ["FACT:...", "ASSUME:..."],
  "quantities": [
    { "id": "combiner_word_sources", "expr": "3", "tier": "architectural",
      "from": "FACT:ENC.WORD_COMBINER_GRAMMAR.max_word_sources" },
    { "id": "perm_floor_required_accumulator", "expr": "min(req_k1, req_k2, req_k3, req_k64)",
      "tier": "family-restriction" }
  ],
  "derivation": [
    { "step": 1, "tier": "architectural", "direction": "capacity",
      "uses": ["FACT:SEM.PERM.SELECTOR_ARITY"], "depends_on": [], "argument": "...",
      "conclusion": "...", "check": "perm_selector_functions == 14",
      "explicitly_not_concluded": "..." }
  ],
  "claim": { "kind": "sufficient-condition-on-service-demand", "tier": "family-restriction",
             "inequality": "sigma_W_iu4 <= 24", "sufficiency_only": "...",
             "native_runtime_claim": "none. ...", "architectural_residue": "..." },
  "sensitivity": { "parameter": "sigma_W_iu4", "break_even": 24, "sweep": [...],
                   "alternate_thresholds": {...} },
  "observations": { "role": "achieved-rate", "load_bearing": false, "inputs": [...], "derived": [...] },
  "evidence": [ { "id": "MEAS.IU4_ACHIEVED", "role": "achievability-upper-bound",
                  "value": {...}, "source": {"path": "...", "sha256": "..."},
                  "what_it_proves": "...", "what_it_does_not_prove": "..." } ],
  "missing_premises_for_a_native_claim": [ {"id": "tau_V", "needed_for": "...", "would_come_from": "..."} ],
  "not_established": [ "..." ]
}
```

`depends_on` is required on every step and is how transitive provenance is carried. `tier` is required
on every quantity and every step. `explicitly_not_concluded` is optional and is the place to record a
neighbouring claim the step does **not** support, which is usually the one a reader will assume.

Changes from `kelana-resource-case/1`: `depends_on` and per-quantity `tier` added, `comparison_boundary`
added, and claims renamed from dominance to sufficient conditions. Version 1 documents are not accepted
by the current checker, because they cannot express transitive provenance.

### Expression language

`quantities[].expr`, `derivation[].check` and `observations` expressions are evaluated over
`fractions.Fraction`. Grammar: decimal and integer literals, names of earlier quantities, `+ - * /`,
unary minus, and `ceil`, `floor`, `min`, `max`, `log3_floor`. No attribute access, no indexing, no
comparison inside an expression. `check` is one expression, one relation from `== <= >= < >`, one
expression. Parsing anything else is an error, not a fallback.

### Rules a checker must enforce

1. Every `quantities[].from` that names a fact must equal the fact's value at that path. Fact ids
   contain dots, so resolve by longest matching id, not by first separator.
2. Every `derivation[].check` must hold in exact rationals.
3. Every `premises[]` entry must resolve to a declared fact or assumption.
4. **No step with `direction: lower-bound` may cite evidence whose `role` is `achieved-rate`.**
5. A quantity's `tier` may not be stronger than the weakest tier among the quantities its expression
   reads and the fact it traces to.
6. A step's `tier` may not be stronger than the weakest tier among **three** sources: the premises it
   cites, the quantities its `check` reads, and the steps in its `depends_on`. Ordering is
   `architectural > family-restriction > achieved-rate`. An empty `uses` does not make a step
   architectural. The claim's `tier` must equal what its steps and operation model inherit.
7. Nothing in `observations` may appear in any `derivation[].uses`.

Rules 4, 5 and 6 are the ones that matter. Rule 4 stops a measured regression from being written up as
an impossibility. Rules 5 and 6 stop a family assumption from being laundered into architecture by
dropping the citation that carried it — absence of a measurement is not unconditionality, and tier
tracks dependency rather than whether a number was measured.

`validate.py --self-test` runs three controls, each of which must be rejected: an achieved rate
cited by a lower-bound step, a family step relabelled architectural with `uses` emptied, and a family
quantity relabelled architectural while still reading family inputs.
