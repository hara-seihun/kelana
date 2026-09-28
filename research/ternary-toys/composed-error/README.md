# A conserved mode that local ternary rounding misses

A two-block gated residual toy exposes a concrete failure of local response fitting. Both locally selected ternary blocks conserve `x0 + x1` exactly, regardless of their scales. The teacher changes that sum. No amount of scale-only recovery can repair the selected codes. One downstream trit change, paired with a worse first-block scale, lowers composed train MSE from 0.78819 to 0.14191 at the same stored format. The held interpolation grid moves from 0.46674 to 0.09171.

Each block is `B_d(x) = x + d * ReLU(x0) * x1`, a two-coordinate residual gated product with exact shared gate and up producers. The teacher's down vectors are `(-0.75, 1.25)` and `(-0.25, 0.75)`. A candidate stores one common positive scale and two trits per block: `d = s * (t0, t1)`, where `s` is one of `0.5, 1, 1.5` and each trit is `-1, 0, 1`. Thus every compared image has four trits and two scale indices, eleven bits if the four trits are jointly packed into seven bits and the two indices into four bits. Gate/up operands, the scale table and residual operations are common to all candidates. Both images use the same two gated products and two residual additions. This is a quality result, not a compression or speedup claim against BF16.

The search completely evaluates all `27 * 27 = 729` paired images on a 12-point calibration grid. The witness teacher was selected by a train-only criterion from `6^4 = 1,296` rational teacher pairs. The separate 16-point grid interleaves the training coordinates and extends the first-coordinate range at both ends. MSE averages both coordinates and all points.

| Conversion | First down | Second down | Train MSE | Held MSE |
| --- | --- | --- | ---: | ---: |
| Independent teacher-input response, also sequential producer response | `1 * (-1, 1)` | `0.5 * (-1, 1)` | 0.78819 | 0.46674 |
| Same codes, best pairwise refit of the three allowed scales | `1 * (-1, 1)` | `0.5 * (-1, 1)` | 0.78819 | 0.46674 |
| Downstream code changed, first scale held at its local choice | `1 * (-1, 1)` | `0.5 * (0, 1)` | 0.59006 | 0.36586 |
| First scale changed, old downstream code | `1.5 * (-1, 1)` | `0.5 * (-1, 1)` | 1.92791 | 1.01241 |
| Exact joint optimum in the finite image family | `1.5 * (-1, 1)` | `0.5 * (0, 1)` | 0.14191 | 0.09171 |

The joint first-block response MSE against the teacher rises from 0.04557 to 0.22786. The joint change has to be accepted as a pair: changing only the first scale is harmful, and changing only the second code captures less than a third of the combined gain. On three train inputs, the stronger first block also crosses the second gate's ReLU boundary; the teacher first block never does. The observed benefit therefore includes actual nonlinear routing, not only cancellation in a fixed linear operator.

The stronger scale-only control fits the independently selected trits with *continuous* positive scales in `[0,3]`, using differential evolution rather than the three-scale grid. It gets train/held MSE 0.75280/0.44660. There is a proof that no scales, even outside this interval, can approach the joint image: each selected down vector is proportional to `(-1,1)`, hence both blocks preserve `x0+x1`. For any two-dimensional target `y` and a candidate constrained to preserve the input sum, squared error averaged over its two coordinates is at least `(sum(y)-sum(x))^2 / 4`. Averaging this bound over the grids gives 0.75128 train and 0.44574 held. The fitted continuous control is close to its absolute floor. The joint second trit becomes zero, freeing that sum mode, while the first scale increases to compensate the resulting route and amplitude changes.

## Reproduce

```sh
cd /path/to/workspace/projects/kelana
OPENBLAS_NUM_THREADS=1 python research/ternary-toys/composed-error/experiment.py \
  > research/ternary-toys/composed-error/results.json
```

The script requires NumPy and SciPy. It prints the teacher, actual codes/scales, train and held errors, gate-crossing counts and the invariant lower bound. To inspect another teacher without the discovery sweep, pass a JSON pair of down vectors, for example `'[[-0.75,1.25],[-0.25,0.75]]'`. The sweep selects solely from train error; held scores do not rank teachers. `results.json` is the compact result receipt.

## Transfer test

In Qwen's residual FFN, local GPTQ/reconstruction and scales are not the same as this two-coordinate fixed-producer toy. Before spending more full-model code-training steps, measure whether the existing ternary image's residual updates suppress output directions that BF16 repeatedly changes on **distinct train captures**, not just whether a matrix has large response MSE. For a small set of adjacent FFNs, identify such directions from the BF16 composed outputs, propose *paired* down trit changes and scale adjustments on the existing packed image, and accept against composed gold-token loss on a separate train check panel. Compare to equally budgeted scale-only recovery and the same trit proposals without coupled scales, then score the frozen test panel once. If there is no reproducible suppressed mode, or the paired move fails held loss, this toy mechanism does not transfer. The exact 729-image oracle prices offline search, not a practical full-model optimizer.
