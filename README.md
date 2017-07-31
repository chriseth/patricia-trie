## Verifying evm-based sidechain executions


Specific smart contract that can be used both off-chain and on-chain for verification.
Exactly the same code will run off- (for actually performing the computations) and on-chain
(for settling disputes). The on-chain code will be much faster because it has two
execution modes (mostly relevant to the underlying data storage):

1) direct:

The smart contract gets the full state (encoded in a certain way or just stored in
storage) plus the transaction as input. It updates the state thereby calculating

    (a) helper values for verification,
    (b) Merkle proofs for all reads and writes into the state and
    (c) the new root hash 

2) with helpers / witnesses:

as in 1, just that the helper values that are generated in 1(a) are also added to the input.
Those are used to speed up the computation like in the following example.
If this is run with ``_helper == 0``, it will produce a value to be found and a value for helper.
If that helper value is used in the next run, it will speed up the search. At the same time,
there is no value for ``_helper`` which can produce a different return value (wrong values
will only cause the transaction to be reverted).

    function findValue(uint[] a, uint x, uint _helper) returns (uint value, uint helper) {
      // a is sorted by increasing value
      for (uint i = _helper; i < a.length; i++) {
        if (array[i] >= x && (i == 0 || array[i-1] < x))
          return (array[i], i);
      }
      // it is important to detect an invalid value of _helper
      revert();
    }

3) with helpers plus merkle proofs for all state access

In all three variants, state access has to be performed by special functions:

 * ``readState(MerkleTree _state, bytes _key, bytes _merkleProofInput) returns (bytes _value, bytes _merkleProof)``
 * ``writeState(MerkleTree _state, bytes _key, bytes _value, bytes _merkleProofInput) returns (bytes _merkleProof)``
 
If run in the first mode, the input merkle proofs are empty. Instead they are generated and provided as return value.
``writeState`` updates the merkle tree in place.

If run in the second mode, the merkle proof can be provided as input. In this case, (for read) it already contains the
value to be read and is only verified against the state. The function just returns the same proof again.
For ``writeState``, the state is also updated in place, but it is assumed to consist only of the root hash anyway.

### More formal writeup (work in progress)

This technique allows to re-run and and in particular verify transactions such that the second run is much more
efficient than the first run. The use-case is to process transactions in a private chain and verify them on the
public chain only on demand and thus take load off the public chain. Since the second run will not generate
the full state, the operators of the private chain have to ensure data availability and can be punished if
they do not provide required data.

Let `f` be a fixed function taking three parameters and returning two values:

 - Let `f(s, x) = (s', y, w)` be the result of running `f` in full mode (`0`) on the current state `s` with input `x`, producing the new state `s'`, actual output `y` and witness `w`

We call `g` a verifier of `f` using the hash function `H` (think of `H` as returning the root of a Merkle tree for structured input), if for all `s` and `x` and `(s', y, w) = f(s, x)` it holds that `g(H(s), x, w) = (H(s'), y)`.

### Patricia-Merkle-Tree

The Patricia-Merkle-Tree encodes an arbitrary partial mapping `m: bits -> bits` as an authenticated data structure with
short proofs. Let `<.> -> bits256` be a hash function. We first transform `m` to `M` by `M(<k>) = v` for `m(k) = v`.

For a prefix `pref` of a key in `M` let `path_M(pref: bits)` be the longest bit string `b` such that `pref . b`
is a unique prefix of keys in `M`. If `pref` is not a prefix of a key in `M`, then `path_M(pref)` is the empty bit string.

We now define a partial function `node_M` that takes a prefix and returns the value of a node in the Patricia-Merkle-tree.
`<node(path_M('')) . path_M('')>` is called the root hash of `M` if `M` is non-empty. If it is empty, then
the root hash is the all-zero bitstring of 256 bits.

#### Definition

For an arbitrary prefix of a key in `M`, `node(pref)` is defined as follows:

    node_M(pref) =
      - M(pref)                                          if pref is a key in M
      - <node_M(pref . '0' . path_M(pref . '0'))> .        otherwise
        <node_M(pref . '1' . path_M(pref . '1'))> . 
        length(path_M(pref . '0')): uint8 . 
        length(path_M(pref . '1')): uint8 . 
        path_M(pref . '0')) [ padded to multiples of 8 bits ] . 
        path_M(pref . '1')) [ padded to multiples of 8 bits ]

#### Definition

A bit string `p` is called a *branch point* of `M` if it is a longest unique prefix
of a key in `M`, but not equal to a key.

#### Observation

For a branch point `p` of `M`, `node_M(p)` only contains recursive mentions
of `node_M` with branch points or keys of `M` as arguments.

For a key `k` of `M`, `node_M(k)` does not contain recursive mentions
of `node_M`.

From this it follows that if `p` is a prefix of a key in `M`, then `node_M(p . path_M(p))` does
not contains recursive mentions of `node_M` where the argument is not a prefix
of a key in `M`.
