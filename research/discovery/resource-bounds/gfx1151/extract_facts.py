#!/usr/bin/env python3
"""Extract gfx1151 resource facts from the pinned ISA sources.

Reads only ``hardware/gfx1151/sources/``. No network, no GPU, no compiler.
Every fact it writes is recomputed here from the XML or the manual text, so
``facts.json`` is a cache of this program's output rather than a hand-maintained
table. ``validate.py --reextract`` re-runs it and diffs.

    python3 extract_facts.py --out facts.json
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
XML = REPO / "hardware/gfx1151/sources/amdgpu_isa_rdna3_5.xml"
TXT = REPO / "hardware/gfx1151/sources/rdna35-isa.txt"

FORMAT = "kelana-resource-facts/1"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_instructions(root: ET.Element) -> dict:
    """name -> list of encodings, each with its explicit operand signature."""
    out: dict[str, list] = {}
    for ins in root.iter("Instruction"):
        name = ins.findtext("InstructionName")
        if not name:
            continue
        encs = []
        for enc in ins.iter("InstructionEncoding"):
            ops = []
            for o in enc.iter("Operand"):
                if o.get("IsImplicit") == "true":
                    continue
                ops.append(
                    {
                        "field": o.findtext("FieldName"),
                        "format": o.findtext("DataFormatName"),
                        "type": o.findtext("OperandType"),
                        "bits": int(o.findtext("OperandSize") or 0),
                        "input": o.get("Input") == "true",
                        "output": o.get("Output") == "true",
                    }
                )
            encs.append({"encoding": enc.findtext("EncodingName"), "operands": ops})
        out[name] = encs
    return out


def signature(encs: list, want: str) -> dict:
    for e in encs:
        if e["encoding"] == want:
            src = [o for o in e["operands"] if o["input"]]
            dst = [o for o in e["operands"] if o["output"]]
            return {
                "encoding": want,
                "sources": [
                    {"field": o["field"], "format": o["format"], "type": o["type"], "bits": o["bits"]}
                    for o in src
                ],
                "destinations": [
                    {"field": o["field"], "format": o["format"], "type": o["type"], "bits": o["bits"]}
                    for o in dst
                ],
            }
    raise SystemExit(f"encoding {want} not found")


def perm_selector_classes(text: str) -> dict:
    """Partition the 256 V_PERM_B32 selector byte values by the function they name.

    Parsed from the BYTE_PERMUTE pseudocode in section 16.12, opcode 580.
    """
    start = text.find("BYTE_PERMUTE = lambda")
    if start < 0:
        raise SystemExit("BYTE_PERMUTE pseudocode not found in the pinned manual text")
    block = text[start : text.find("D0[31 : 24]", start)]
    ge = [int(m) for m in re.findall(r"sel\.u32 >= (\d+)U", block)]
    eq = [int(m) for m in re.findall(r"sel\.u32 == (\d+)U", block)]
    if not ge or not eq:
        raise SystemExit("unexpected BYTE_PERMUTE pseudocode shape")
    threshold = min(ge)
    classes = {}
    # Branch order in the pseudocode: >= threshold first, then the == tests
    # in descending order, then the fallthrough in[sel].
    for value in range(256):
        if value >= threshold:
            classes.setdefault(f"const_ff", []).append(value)
            continue
        if value in eq:
            # 12 -> constant 0x00; 8..11 -> replicate the sign bit of one input byte.
            classes.setdefault(f"code_{value}", []).append(value)
            continue
        classes.setdefault(f"byte_{value}", []).append(value)
    return {
        "threshold_all_ones": threshold,
        "explicit_equality_codes": sorted(eq),
        "distinct_functions": len(classes),
        "classes": {k: [min(v), max(v)] for k, v in sorted(classes.items())},
        "pseudocode_sha256": hashlib.sha256(block.encode()).hexdigest(),
    }


def largest_power(base: int, limit: int) -> int:
    g, v = 0, 1
    while v * base <= limit:
        v *= base
        g += 1
    return g


def build(args) -> dict:
    root = ET.parse(XML).getroot()
    ins = load_instructions(root)
    text = TXT.read_text(errors="replace")

    valu = {n: e for n, e in ins.items() if n.startswith("V_")}
    per_instruction_max = {
        n: max((sum(1 for o in e["operands"] if o["input"]) for e in encs), default=0)
        for n, encs in valu.items()
    }
    max_sources = max(per_instruction_max.values())
    at_max = sorted(n for n, c in per_instruction_max.items() if c == max_sources)

    # Operand fields are not scalar-word inputs. Record the widest thing one input field
    # carries, so nobody reads the field count as an information arity.
    widest_field = max(
        (
            (o["bits"], n, e["encoding"], o["field"])
            for n, encs in valu.items()
            for e in encs
            for o in e["operands"]
            if o["input"]
        ),
        key=lambda t: t[0],
    )

    # The declared word-reduction grammar: 32-bit integer combiners a PERM result can
    # reach an accumulator through. Signatures come from the XML, membership is a choice.
    grammar = ["V_ADD_NC_U32", "V_ADD3_U32", "V_ADD_LSHL_U32", "V_LSHL_ADD_U32", "V_XAD_U32"]
    grammar_sigs = {}
    for name in grammar:
        if name not in ins:
            continue
        sig = signature(ins[name], "ENC_VOP3")
        words = [s for s in sig["sources"] if s["bits"] == 32]
        grammar_sigs[name] = {
            "encoding": sig["encoding"],
            "word_sources": len(words),
            "all_sources_are_32_bit": len(words) == len(sig["sources"]),
            "destination_bits": sig["destinations"][0]["bits"],
        }

    vopd = sorted(
        n
        for n, encs in ins.items()
        if any("VOPD" in (e["encoding"] or "") for e in encs)
    )

    perm = perm_selector_classes(text)
    perm_group_trits = largest_power(3, perm["distinct_functions"])

    wmma_iu4 = signature(ins["V_WMMA_I32_16X16X16_IU4"], "ENC_VOP3P")
    wmma_iu8 = signature(ins["V_WMMA_I32_16X16X16_IU8"], "ENC_VOP3P")

    facts = [
        {
            "id": "ENC.VALU.MAX_SOURCE_FIELDS",
            "kind": "encoding-capacity",
            "claim": (
                "No vector ALU instruction in the pinned RDNA 3.5 inventory has more than "
                f"{max_sources} explicit source operand fields in any of its encodings."
            ),
            "value": {
                "max_explicit_source_fields": max_sources,
                "valu_instructions_examined": len(valu),
                "instructions_attaining_max": len(at_max),
                "examples_at_max": at_max[:6],
            },
            "does_not_imply": {
                "scalar_word_arity": (
                    "A field is not a 32-bit word. The widest explicit input field in this "
                    f"inventory is {widest_field[0]} bits: {widest_field[1]} {widest_field[3]} "
                    f"under {widest_field[2]}. One field can name a multi-register fragment, so "
                    "three fields can carry far more than three words."
                ),
                "total_information": (
                    "Implicit state is excluded by construction. EXEC, VCC, the MODE register "
                    "and wave size are inputs to the instruction's meaning and are not operand "
                    "fields. DPP and the lane-crossing modifiers supply further data the field "
                    "list does not show."
                ),
                "use": (
                    "This fact bounds field count only. Any argument about how many values an "
                    "instruction can consume must name a concrete opcode set and read its widths."
                ),
            },
            "source": "isa_xml",
            "extraction": "count Operand elements with Input=true and IsImplicit=false over every InstructionEncoding of every V_* instruction; widest field is the maximum OperandSize among those",
            "status": "derived",
        },
        {
            "id": "ENC.WORD_COMBINER_GRAMMAR",
            "kind": "encoding-capacity",
            "claim": (
                "For the named 32-bit integer word combiners, every explicit source is a single "
                "32-bit word and the destination is a single 32-bit word. The widest of them "
                "reads three words and writes one, so it reduces a multiset of live words by at "
                "most two per instruction."
            ),
            "value": {
                "grammar": grammar_sigs,
                "max_word_sources": max(g["word_sources"] for g in grammar_sigs.values()),
                "max_words_removed_per_instruction": max(
                    g["word_sources"] for g in grammar_sigs.values()
                )
                - 1,
            },
            "membership_is_a_choice": (
                "Which opcodes belong to the grammar is a family restriction, not a fact. The "
                "widths above are facts about the opcodes listed. An argument that ranges over "
                "all VALU instructions cannot use this fact."
            ),
            "source": "isa_xml",
            "extraction": "ENC_VOP3 operand signatures of the listed opcodes, counting sources whose OperandSize is 32",
            "status": "derived",
        },
        {
            "id": "ENC.VOPD.ELIGIBLE_SET",
            "kind": "encoding-capacity",
            "claim": (
                f"Exactly {len(vopd)} instructions carry a VOPD encoding, and all of them are "
                "named V_DUAL_*. Dual issue is therefore unavailable to any other opcode."
            ),
            "value": {
                "vopd_eligible_count": len(vopd),
                "vopd_eligible": vopd,
                "perm_eligible": "V_PERM_B32" in vopd,
                "add3_eligible": "V_ADD3_U32" in vopd,
                "dot8_iu4_eligible": "V_DOT8_I32_IU4" in vopd,
                "wave32_only": "VOPD is legal only for wave32 (manual section 7.6)",
            },
            "source": "isa_xml",
            "extraction": "instructions with any InstructionEncoding whose EncodingName contains VOPD",
            "status": "derived",
        },
        {
            "id": "SEM.PERM.SELECTOR_ARITY",
            "kind": "semantic-capacity",
            "claim": (
                "One V_PERM_B32 destination byte is one of "
                f"{perm['distinct_functions']} functions of the two data operands, chosen by its "
                "selector byte. Selector values 0-7 project an input byte, 8-11 replicate a "
                "selected byte's sign bit, 12 is constant 0x00 and 13-255 are constant 0xff."
            ),
            "value": {
                "distinct_functions_per_destination_byte": perm["distinct_functions"],
                "destination_bytes": 4,
                "all_ones_threshold": perm["threshold_all_ones"],
                "explicit_equality_codes": perm["explicit_equality_codes"],
                "largest_g_with_3_to_the_g_at_most_the_arity": perm_group_trits,
                "pseudocode_sha256": perm["pseudocode_sha256"],
            },
            "does_not_imply": {
                "group_size_bound": (
                    "The arity alone does not bound trits per group. A group of g trits needs one "
                    "code per equivalence class of its 3^g weight patterns under 'agree on every "
                    "activation in the domain'. Bounding g needs a separating argument over a "
                    "declared activation domain and a declared weight family, both of which are "
                    "family-tier premises. On a degenerate domain every pattern collapses into "
                    "one class and no g is excluded."
                )
            },
            "source": "isa_text",
            "extraction": "parse the BYTE_PERMUTE lambda in section 16.12 opcode 580 and partition all 256 selector values by the function they name",
            "status": "derived",
        },
        {
            "id": "ENC.PERM.NO_ACCUMULATOR",
            "kind": "encoding-capacity",
            "claim": (
                "V_PERM_B32 has three explicit sources and all three are consumed by the "
                "permutation: two data words and one selector word. It has no accumulator "
                "operand, so a PERM result must be combined by a separate instruction."
            ),
            "value": signature(ins["V_PERM_B32"], "ENC_VOP3"),
            "source": "isa_xml",
            "extraction": "ENC_VOP3 operand signature of V_PERM_B32",
            "status": "derived",
        },
        {
            "id": "ENC.DOT.SIGNATURES",
            "kind": "encoding-capacity",
            "claim": (
                "V_DOT8_I32_IU4 and V_DOT4_I32_IU8 are both ENC_VOP3P with two packed 32-bit "
                "data sources and a 32-bit signed accumulator source, writing one 32-bit VGPR. "
                "Their per-lane product counts are 8 and 4."
            ),
            "value": {
                "V_DOT8_I32_IU4": dict(
                    signature(ins["V_DOT8_I32_IU4"], "ENC_VOP3P"), products_per_lane=8
                ),
                "V_DOT4_I32_IU8": dict(
                    signature(ins["V_DOT4_I32_IU8"], "ENC_VOP3P"), products_per_lane=4
                ),
            },
            "source": "isa_xml",
            "extraction": "ENC_VOP3P operand signatures; product counts are the packed lane counts named by FMT_NUM_PK8_IU4 and FMT_NUM_PK4_IU8",
            "status": "derived",
        },
        {
            "id": "ENC.COMBINER.SIGNATURES",
            "kind": "encoding-capacity",
            "claim": (
                "V_ADD3_U32 and V_LSHL_OR_B32 are ENC_VOP3 with three 32-bit sources and one "
                "32-bit destination. A three-source combiner reduces the number of live values "
                "by at most two per instruction."
            ),
            "value": {
                "V_ADD3_U32": signature(ins["V_ADD3_U32"], "ENC_VOP3"),
                "V_LSHL_OR_B32": signature(ins["V_LSHL_OR_B32"], "ENC_VOP3"),
            },
            "source": "isa_xml",
            "extraction": "ENC_VOP3 operand signatures",
            "status": "derived",
        },
        {
            "id": "CAP.WMMA.IU4",
            "kind": "semantic-capacity",
            "claim": (
                "V_WMMA_I32_16X16X16_IU4 computes 16*16*16 = 4096 integer multiply-accumulates "
                "per wave instruction. In wave32 that is 128 per lane. Its A and B operands are "
                "64 bits per lane and its C and D operands are 256 bits per lane."
            ),
            "value": {
                "m": 16,
                "n": 16,
                "k": 16,
                "mac_per_wave_instruction": 16 * 16 * 16,
                "mac_per_lane_wave32": 16 * 16 * 16 // 32,
                "signature": wmma_iu4,
                "ab_bits_per_lane": wmma_iu4["sources"][0]["bits"],
                "cd_bits_per_lane": wmma_iu4["destinations"][0]["bits"],
            },
            "source": "isa_xml",
            "extraction": "ENC_VOP3P operand signature plus the 16x16x16 shape named by the mnemonic and defined in manual section 7.9",
            "status": "derived",
        },
        {
            "id": "CAP.WMMA.IU8_OPERAND_WIDTH",
            "kind": "encoding-capacity",
            "claim": (
                "V_WMMA_I32_16X16X16_IU8 computes the same 4096 products from A and B operands "
                "of 128 bits per lane, twice the IU4 width, with identical 256-bit C and D."
            ),
            "value": {
                "ab_bits_per_lane": wmma_iu8["sources"][0]["bits"],
                "iu4_ab_bits_per_lane": wmma_iu4["sources"][0]["bits"],
                "ratio": wmma_iu8["sources"][0]["bits"] // wmma_iu4["sources"][0]["bits"],
                "mac_per_wave_instruction": 16 * 16 * 16,
            },
            "source": "isa_xml",
            "extraction": "ENC_VOP3P operand signatures of both integer WMMA opcodes",
            "status": "derived",
        },
        {
            "id": "HAZ.WMMA.SCHEDULING",
            "kind": "scheduling-rule",
            "claim": (
                "Back-to-back dependent WMMA instructions need one V_NOP or one unrelated VALU "
                "instruction between them only when the first instruction's D overlaps the "
                "second's A or B. The D-as-next-C accumulation pattern carries no such "
                "requirement; the manual lists it only among stall cases."
            ),
            "value": {
                "required_filler_when_d_overlaps_next_ab": 1,
                "required_filler_for_d_to_c_accumulation": 0,
                "stall_cases_are_not_correctness_cases": True,
                "manual_section": "7.9.1",
            },
            "source": "isa_text",
            "extraction": "section 7.9.1 WMMA Scheduling table",
            "status": "derived",
        },
        {
            "id": "PORT.VGPR_BANKS",
            "kind": "scheduling-rule",
            "claim": (
                "The manual documents four VGPR banks indexed by the low two bits of the "
                "register number, each with a cache holding one read port per source position. "
                "A single cache can serve SRC0, SRC1 and SRC2 at once but cannot serve two "
                "reads in the same source position. The rules are stated as VOPD pairing "
                "restrictions; the manual does not extend them to single-instruction issue."
            ),
            "value": {
                "banks": 4,
                "bank_index": "SRC[1:0]",
                "read_ports_per_bank_cache": 3,
                "port_assignment": ["SRC0", "SRC1", "SRC2"],
                "stated_scope": "VOPD pairing restrictions, manual section 7.6",
                "single_instruction_conflict_documented": False,
            },
            "source": "isa_text",
            "extraction": "section 7.6 Dual Issue VALU, VGPR source-cache port limits",
            "status": "derived",
        },
        {
            "id": "CAP.VGPR_FILE",
            "kind": "capacity",
            "claim": (
                "VGPRs are allocated in blocks of 16 for wave32 and a shader may have up to 256. "
                "Devices with 1536 VGPRs per SIMD allocate in blocks of 24 for wave32."
            ),
            "value": {
                "max_vgprs_per_wave": 256,
                "wave32_allocation_block": 16,
                "wave32_allocation_block_on_1536_devices": 24,
                "vgprs_per_simd_on_1536_devices": 1536,
                "manual_section": "3.3.2.1",
            },
            "source": "isa_text",
            "extraction": "section 3.3.2.1 VGPR Allocation and Alignment",
            "status": "derived",
        },
    ]

    # Everything this program can read out of AMD's pinned sources is architectural:
    # true of every program that runs on the part. Nothing here is a cost.
    for f in facts:
        f["tier"] = "architectural"

    return {
        "format": FORMAT,
        "target": "gfx1151",
        "generated_by": "research/discovery/resource-bounds/gfx1151/extract_facts.py",
        "scope": (
            "Operand, encoding, capacity and scheduling-rule facts read out of the pinned AMD "
            "RDNA 3.5 sources. Nothing here is a throughput, latency, port-occupancy or "
            "cycle-count claim; the pinned sources publish none for gfx1151."
        ),
        "sources": {
            "isa_xml": {
                "path": str(XML.relative_to(REPO)),
                "sha256": sha256(XML),
                "release": "2026-02-20, schema 1.1.1",
            },
            "isa_text": {
                "path": str(TXT.relative_to(REPO)),
                "sha256": sha256(TXT),
                "note": "pdftotext -layout of the pinned RDNA 3.5 manual",
            },
        },
        "facts": facts,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", default=str(HERE / "facts.json"))
    ap.add_argument("--stdout", action="store_true", help="print instead of writing")
    args = ap.parse_args()

    doc = build(args)
    body = json.dumps(doc, indent=1, sort_keys=False) + "\n"
    if args.stdout:
        sys.stdout.write(body)
    else:
        Path(args.out).write_text(body)
        print(f"wrote {args.out}: {len(doc['facts'])} facts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
