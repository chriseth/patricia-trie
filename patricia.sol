pragma solidity ^0.4.0;

import {D} from "./data.sol";
import {Utils} from "./utils.sol";

contract PatriciaTree {
    // Mapping of hash of key to value
    mapping (bytes32 => bytes) values;

    // Particia tree nodes (hash to decoded contents)
    mapping (bytes32 => D.Node) nodes;
    // The current root hash, keccak256(node(path_M('')), path_M(''))
    bytes32 public root;
    D.Edge rootEdge;

    function getNode(bytes32 hash) constant returns (uint, bytes32, bytes32, uint, bytes32, bytes32) {
        var n = nodes[hash];
        return (
            n.children[0].label.length, n.children[0].label.data, n.children[0].node,
            n.children[1].label.length, n.children[1].label.data, n.children[1].node
        );
    }

    function getRootEdge() constant returns (uint, bytes32, bytes32) {
        return (rootEdge.label.length, rootEdge.label.data, rootEdge.node);
    }
    
    function edgeHash(D.Edge e) internal returns (bytes32) {
        return keccak256(e.node, e.label.length, e.label.data);
    }
    
    // Returns the hash of the encoding of a node.
    function hash(D.Node memory n) internal returns (bytes32) {
        // if (n.isLeaf)
        //     return keccak256(n.value);
        // else
            return keccak256(edgeHash(n.children[0]), edgeHash(n.children[1]));
    }
    
    // // Returns the Merkle-proof for the given key
    // // Proof format should be:
    // //  - uint8 branchMask - bitmask with high bits at the positions in the key
    // //                    where we have branch nodes (bit in key denotes direction)
    // //  - bytes32[] hashes - hashes of sibling edges
    // function getProof(bytes key) returns (uint8 branchMask, bytes32[] _siblings) {
    //     Label memory k = Label(keccak256(key), 256);
    //     Edge memory e = rootEdge;
    //     bytes32[256] siblings;
    //     uint length;
    //     uint numSiblings;
    //     while (k.length > 0) {
    //         var (prefix, suffix) = splitCommonPrefix(e.label, k);
    //         require(prefix.length == e.label.length);
    //         length += prefix.length + 1;
    //         branchMask |= 1 << (32 - length);
    //         var (head, tail) = chopFirstBit(suffix);
    //         siblings[numSiblings++] = edgeHash(nodes[e.node].children[1 - head]);
    //         e = nodes[e.node].children[head];
    //         k = tail;
    //     }
    //     _siblings = new bytes32[](numSiblings);
    //     for (uint i = 0; i < numSiblings; i++)
    //         _siblings[i] = siblings[i];
    // }

    // function verifyProof(bytes32 rootHash, bytes key, bytes value, uint8 branchMask, bytes32[] siblings) {
    //     Label memory k = Label(keccak256(key), 256);
    //     Edge memory e;
    //     e.node = keccak256(value);
    //     uint previousBranch = 32;
    //     for (uint i = 0; ; i++) {
    //         uint branch = 31 - lowestBitSet(branchMask);
    //         (k, e.label) = splitAt(k, branch);
    //         if (branchMask == 0)
    //             break;
    //         uint bit = bitSet(uint8(branch), k.length);
    //         bytes32[2] memory edgeHashes;
    //         edgeHashes[bit] = edgeHash(e);
    //         edgeHashes[1 - bit] = siblings[siblings.length - i - 1];
    //         e.node = keccak256(edgeHashes);
    //         branchMask &= uint8(~(uint(1) << branch));
    //         // TODO try to get rid of this
    //         previousBranch = branch;
    //     }
    //     require(rootHash == edgeHash(e));
    // }
    
    function insert(bytes key, bytes value) {
        D.Label memory k = D.Label(keccak256(key), 256);
        bytes32 valueHash = keccak256(value);
        values[valueHash] = value;
        // keys.push(key);
        D.Edge memory e;
        if (rootEdge.node == 0 && rootEdge.label.length == 0)
        {
            // Empty Trie
            e.label = k;
            e.node = valueHash;
        }
        else
        {
            e = insertAtEdge(rootEdge, k, valueHash);
        }
        root = edgeHash(e);
        rootEdge = e;
    }
    
    // TODO also return the proof (which is basically just the array of encodings of nodes)
    function insertAtNode(bytes32 nodeHash, D.Label key, bytes32 value) internal returns (bytes32) {
        require(key.length > 1);
        D.Node memory n = nodes[nodeHash];
        var (head, tail) = Utils.chopFirstBit(key);
        n.children[head] = insertAtEdge(n.children[head], tail, value);
        return replaceNode(nodeHash, n);
    }
    
    function insertAtEdge(D.Edge e, D.Label key, bytes32 value) internal returns (D.Edge) {
        require(key.length >= e.label.length);
        var (prefix, suffix) = Utils.splitCommonPrefix(key, e.label);
        bytes32 newNodeHash;
        if (prefix.length >= e.label.length) {
            // Full match, just follow the path
            newNodeHash = insertAtNode(e.node, suffix, value);
        } else {
            // Mismatch, so let us create a new branch node.
            var (head, tail) = Utils.chopFirstBit(suffix);
            D.Node memory branchNode;
            branchNode.children[head] = D.Edge(value, tail);
            branchNode.children[1 - head] = D.Edge(e.node, Utils.removePrefix(e.label, prefix.length + 1));
            newNodeHash = insertNode(branchNode);
        }
        return D.Edge(newNodeHash, prefix);
    }
    function insertNode(D.Node memory n) internal returns (bytes32 newHash) {
        bytes32 h = hash(n);
        nodes[h].children[0] = n.children[0];
        nodes[h].children[1] = n.children[1];
        return h;
    }
    function replaceNode(bytes32 oldHash, D.Node memory n) internal returns (bytes32 newHash) {
        delete nodes[oldHash];
        return insertNode(n);
    }
}
