# Partitioned response tables for paid binary factors

The [half-orbit table](../binary-half-table/README.md) needs 128 live entries for each eight-sign response. That is optimal for **one** indexed read followed by a sign, but not for a consumer willing to make two or three reads. Splitting an eight-coordinate activation into adjacent subblocks gives a useful register-size versus lookup-work frontier without changing a single bit of either paid binary factor image. The `(4,4)` arm takes 16 entries total, at most eight live in one subtable, rather than 128; it reduces the table-build upper count from 141 to 26 additions per eight-input block. It doubles the indexed reads, row-reduction adds and sign selections. This is a candidate for a wave-register or small LDS lowering, not a measured native speedup.

For a subblock `h[0..b-1]` and packed signs `s_i`, set `a=s_0` and index relative signs `r_i=s_i/a`. One table contains the `2^(b-1)` values `T[r]=h_0+sum_{i>0}r_i h_i`. The response is `a*T[r]`. Sum subblock responses in each output row. Both paid factor planes are consumed in this coordinate: form the rank responses from packed V, then the output responses from packed U, and apply their existing scales in their original places. No individual factor weight or int4 intermediate is needed online. The sign bits remain the exact original packed image. Floating-point table construction and regrouping are not bit-identical to the selected FP32 order; the proof is over integers and reals.

## Exact restricted frontier

Let a consumer partition each original eight-input block into `m` disjoint contiguous groups of size at least two. Each group gets one table read and one optional unary sign, with no other activation-dependent arithmetic inside its response. Its table is built from that group's activations alone. For algebraically independent inputs, its `2^b` signed linear forms occur in opposite pairs. One stored entry can serve at most one such pair, so a group of size `b` needs at least `2^(b-1)` entries. This is an entry-count bound on this table/read grammar, not a bound on arbitrary packed instructions, shared multi-block tables or a native instruction count. Splitting a size `b+1` group and a size `b-1` group into two size `b` groups never increases `2^(b-1)` summed across the pair, by convexity. Balanced group sizes therefore minimize entries at fixed `m`.

Start each table at `h0-sum(h1...)`, double its `b-1` other inputs, and traverse reflected Gray masks with one addition per new entry. The explicit upper count is `2(b-1)+2^(b-1)-1` per group, where doubling is conservatively counted as an addition. Per eight-input block:

| Partition | Entries total | Largest subtable, int32 bytes | Explicit prep-add upper | Reads and signs | Relative sign bits used for indexes |
| --- | ---: | ---: | ---: | ---: | ---: |
| 8 | 128 | 512 | 141 | 1 | 7 |
| 4+4 | 16 | 32 | 26 | 2 | 6 |
| 3+3+2 | 10 | 16 | 17 | 3 | 5 |
| 2+2+2+2 | 8 | 8 | 12 | 4 | 4 |

The entry column is a lower bound attained by these tables; the prep column is **an achievable upper count**, not an optimum over generators. The row must still add the subblock responses. Table residency depends on how many tables a work unit builds at once. `Largest subtable` is the peak when tables are streamed one at a time; the total per original eight-input block is four bytes times `Entries total`. Arbitrary sign-pattern indices and table addressing are not free just because fewer relative sign bits are extracted.

For the frozen Qwen3-0.6B `.55` `mlp_up` image, the complete two-factor program has `K=1024`, rank `384`, `N=3072` and 176 original eight-input tables. The counts include both factors, every output row and the rank intermediate:

| Partition | Prep additions upper | Indexed reads | Sign selections | Row-reduction additions | Table entries across 176 blocks |
| --- | ---: | ---: | ---: | ---: | ---: |
| 8 | 24,816 | 196,608 | 196,608 | 193,152 | 22,528 |
| 4+4 | 4,576 | 393,216 | 393,216 | 389,760 | 2,816 |
| 3+3+2 | 2,992 | 589,824 | 589,824 | 586,368 | 1,760 |
| 2+2+2+2 | 2,112 | 786,432 | 786,432 | 782,976 | 1,408 |

The `(4,4)` switch saves **20,240 table-prep additions** but adds **196,608 indexed reads, 196,608 sign operations and 196,608 row additions**. In an additive cost model, if a prep addition costs `a` and the extra indexed read, sign and reduction together cost `b`, the split wins only when `b/a < 20,240/196,608 = 0.10295`. It loses if even the extra reduction alone costs as much as a prep addition. That rejects a scalar-operation-count speed claim. The reason to try it natively is different: each four-sign subtable has eight entries and can be held in registers or LDS without the 512-byte table and its irregular address span. The earlier [routed quartet](../binary-pair-map/README.md) counts 709,632 signed additions and 294,912 dynamic routes on this same image, with a very different register and synchronization bill. A GPU panel must compare all three with scale placement, rank write/read and output writes charged.

`measure.py` reads sixteen actual packed U/V images at layers 0, 7, 14 and 27. For every partition it builds the tables by Gray recurrence and compares every rank response and final output against independently unpacked signed matrix products on a fixed integer activation. All sixteen images and all four partitions agree exactly. The [CPU receipt](/path/to/workspace/data/kelana-subbit/binary-partition-table/images.json) keeps SHA-256 hashes for the script, each image, input, rank responses and outputs, with complete counts for all four shapes. Integer magnitudes in this panel fit int64. Run `OPENBLAS_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/binary-partition-table/measure.py` from the Kelana root.

Next measure the `(4,4)` register/LDS consumer and the `(8)` half-orbit control on the **same packed up-projection** at one and multiple rows, with both factor stages and scales timed. The relevant question is whether smaller tables remove enough indexed-read latency or register/LDS contention to pay for doubling the reads and additions. If not, use the full half-orbit or redesign the factor signs for a lower-entropy response family rather than splitting this frozen image further. No GPU, model loss, runtime executable or service state changed here.
