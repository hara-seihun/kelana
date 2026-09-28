# A live signed-sum coordinate system for residual dots

The first [table-free native reader](../quip-full-native-root/README.md) lost time to the hot table despite saving static data. The next exact question changes the *dynamic input representation*, not the model's codes or the target map. It does not introduce activation quantization.

For each transformed eight-vector z, prepare these **26 live values**:

```
A[a] = sum_{j=0..2} (-1)^bit_j(a) z_j,       a=0..7,
B[b] = sum_{j=0..2} (-1)^bit_j(b) z_(j+3),   b=0..7,
C[0] = z_6+z_7, C[1] = z_6-z_7,
Z[i] = z_i,                                i=0..7.
```

An integer/axis root uses only two selected Z values and a sign, exactly as before; zero code 127 returns zero. For a half-root byte c, let `n=bit_6(c)` and `m=(c&127) xor (127 if n else 0)`. Complementing all seven sign bits negates all eight half-root coefficients because the seventh-degree parity sign also changes. Thus m<64 has positive coordinate-6 sign. Set `a=m&7`, `b=(m>>3)&7`, and `p=parity(a) xor parity(b)`. Its complete residual dot is

```
g(c) dot z = (-1)^n/2 * (A[a]+B[b]+C[p]).
```

Every half root therefore selects three values and performs two additions plus sign/half scaling, rather than interpreting eight independent coefficient signs. Every original root byte is still valid; no index table or new model-specific field is needed.

[`wave_basis.py`](wave_basis.py) checks this equality against the independent integer coefficient formula for all 256 codes and all eight standard basis vectors, using exact rational arithmetic. Both sides are linear in z, so the 2,048 checks establish arbitrary-input correspondence for the declared finite byte family. [`wave-basis.json`](wave-basis.json) records the result. [`Kelana/E8RootWave.lean`](../../../Kelana/E8RootWave.lean) additionally proves the actual 8+8+2+8-value preparation and byte reader equal the direct root dot for every rational input: finite basis correspondence is combined with proved additivity, scaling and basis expansion. Neither proof alone asserts native lane placement or performance.

## Why this is a different native question

The 26 values fit a wave's lane coordinates in principle. A complete reader might prepare them cooperatively and use per-lane selections, avoiding a 128-value LDS lookup and hundreds of block-wide barriers. But dynamic lane-index support, preparation duplication across waves, sign handling, shuffle cost, convergence, VGPR use and both surrounding Hadamards must be realized and measured. Twenty-six semantic coordinates do not prove a free register transform.

The two signed triple families share elementary sums: each can be generated from four canonical signed sums and their negatives. The final pair uses two sums. Whether explicitly sharing these additions is cheaper than recomputing them depends on ISA placement and synchronization; this report does not add unlike operations into a speed prediction.

The prepared values are **input-dependent runtime state**, not a 26-float model dictionary. They must be regenerated for each distinct transformed input block or retained by a compatible producer for several consumers. On this image there are 128 input blocks per response and 128 output rows; reuse is real, but it must pay its communication cost. Original hot-table, direct-root and matched-scalar complete readers remain the controls. The [native wave study](../quip-wave-root-basis/README.md) now realizes this placement with unchanged model image and no expanded weights. It loses: batch-one event time **37.639 µs versus direct root 31.158 µs and hot table 22.519 µs**, with the same ordering at batch eight. Four waves duplicate the 18 signed sums and issue three unconditional shuffles per lane/group, including sparse codes. The wave body adds 260 bytes over direct root without reducing its 44 VGPRs or 4,608-byte LDS allocation. This implementation is therefore dominated by direct root on measured time and code, with identical model data and map. The exact encoding theorem survives; a different use would need to change its communication/producer boundary, not merely repeat this benchmark.
