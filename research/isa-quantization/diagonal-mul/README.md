# Carried radix labels for a gated sum

[Programme 12 canon, obligation 1029](https://lemma.ing/dev/programmes/12) owns the proof, generated Lean, complete replay and cost boundary at `canon/diagonal-mul/` on main commit `8eaa6fdacadbcd4ef704d7485ba0daae3c1623b4`.

Two already-live signed-ternary seven-channel radix-16 gate/up labels yield their diagonal bilinear sum via one low-32 multiply, constant add and signed nibble extraction. Lean proves all 49 cross-term bounds and the modulo-32 endpoint; 4,782,969 independent gate/up pairs pass C replay. The nonlinear field observer escapes the earlier rank-one lower bound for a product plus *affine-only* observation. This is a structural construction, not a model representation or a native speed result: packing separate scalar trits costs up to 24 shifts/adds, and two direct byte-dot4 operations are stronger when unpacked bytes are already present.

The next useful transfer test is a real quantized producer that already carries both labels for additional consumers, priced against its byte-dot and directly prepared output baselines at the complete observation boundary. Do not duplicate the proof or replay in Kelana; the programme main is the evidence owner.
