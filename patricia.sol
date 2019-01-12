pragma solidity >=0.5.0 <0.6.0;

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

    // TODO also return the proof
    function insert(bytes memory key, bytes memory value) public {
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

    function getNode(bytes32 hash) public view returns (uint, bytes32, bytes32, uint, bytes32, bytes32) {
        D.Node memory n = nodes[hash];
        return (
            n.children[0].label.length, n.children[0].label.data, n.children[0].node,
            n.children[1].label.length, n.children[1].label.data, n.children[1].node
        );
    }

    function getRootEdge() public view returns (uint, bytes32, bytes32) {
        return (rootEdge.label.length, rootEdge.label.data, rootEdge.node);
    }
    
    // Returns the Merkle-proof for the given key
    // Proof format should be:
    //  - uint branchMask - bitmask with high bits at the positions in the key
    //                    where we have branch nodes (bit in key denotes direction)
    //  - bytes32[] hashes - hashes of sibling edges
    function getProof(bytes memory key) public view returns (uint branchMask, bytes32[] memory _siblings) {
        D.Label memory k = D.Label(keccak256(key), 256);
        D.Edge memory e = rootEdge;
        bytes32[256] memory siblings;
        uint length;
        uint numSiblings;
        while (true) {
            (D.Label memory prefix, D.Label memory suffix) = Utils.splitCommonPrefix(k, e.label);
            require(prefix.length == e.label.length, "Prefix lenght mismatch label lenght");
            if (suffix.length == 0) {
                // Found it
                break;
            }
            length += prefix.length;
            branchMask |= uint(1) << (255 - length);
            length += 1;
            (uint head, D.Label memory tail) = Utils.chopFirstBit(suffix);
            siblings[numSiblings++] = edgeHash(nodes[e.node].children[1 - head]);
            e = nodes[e.node].children[head];
            k = tail;
        }
        if (numSiblings > 0)
        {
            _siblings = new bytes32[](numSiblings);
            for (uint i = 0; i < numSiblings; i++)
                _siblings[i] = siblings[i];
        }
    }

    function verifyProof(bytes32 rootHash, bytes memory key, bytes memory value, uint branchMask, bytes32[] memory siblings) public pure {
        D.Label memory k = D.Label(keccak256(key), 256);
        D.Edge memory e;
        e.node = keccak256(value);
        uint b = branchMask;
        for (uint i = 0; b != 0; i++) {
            uint bitSet = Utils.lowestBitSet(b);
            b &= ~(uint(1) << bitSet);
            (k, e.label) = Utils.splitAt(k, 255 - bitSet);
            uint bit;
            (bit, e.label) = Utils.chopFirstBit(e.label);
            bytes32[2] memory edgeHashes;
            edgeHashes[bit] = edgeHash(e);
            edgeHashes[1 - bit] = siblings[siblings.length - i - 1];
            e.node = keccak256(abi.encodePacked(edgeHashes));
        }
        e.label = k;
        require(rootHash == edgeHash(e), "Bad proof");
    }
    
    function insertAtNode(bytes32 nodeHash, D.Label memory key, bytes32 value) internal returns (bytes32) {
        require(key.length > 1, "Bad key");
        D.Node memory n = nodes[nodeHash];
        (uint256 head, D.Label memory tail) = Utils.chopFirstBit(key);
        n.children[head] = insertAtEdge(n.children[head], tail, value);
        return replaceNode(nodeHash, n);
    }
    
    function insertAtEdge(D.Edge memory e, D.Label memory key, bytes32 value) internal returns (D.Edge memory) {
        require(key.length >= e.label.length, "Key lenght mismatch label lenght");
        (D.Label memory prefix, D.Label memory suffix) = Utils.splitCommonPrefix(key, e.label);
        bytes32 newNodeHash;
        if (suffix.length == 0) {
            // Full match with the key, update operation
            newNodeHash = value;
        } else if (prefix.length >= e.label.length) {
            // Partial match, just follow the path
            newNodeHash = insertAtNode(e.node, suffix, value);
        } else {
            // Mismatch, so let us create a new branch node.
            (uint256 head, D.Label memory tail) = Utils.chopFirstBit(suffix);
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
        
    function edgeHash(D.Edge memory e) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(e.node, e.label.length, e.label.data));
    }
    
    // Returns the hash of the encoding of a node.
    function hash(D.Node memory n) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(edgeHash(n.children[0]), edgeHash(n.children[1])));
    }
}


contract PatriciaTreeTest is PatriciaTree {
    function test() public {
        //testInsert();
        testProofs();
    }

    function testInsert() internal {
        insert("one", "ONE");
        insert("two", "ONE");
        insert("three", "ONE");
        insert("four", "ONE");
        insert("five", "ONE");
        insert("six", "ONE");
        insert("seven", "ONE");
        // update
        insert("one", "TWO");
    }
    
    function testProofs() internal {
        insert("one", "ONE");
        (uint branchMask, bytes32[] memory siblings) = getProof("one");
        verifyProof(root, "one", "ONE", branchMask, siblings);
        insert("two", "TWO");
        (branchMask, siblings) = getProof("one");
        verifyProof(root, "one", "ONE", branchMask, siblings);
        (branchMask, siblings) = getProof("two");
        verifyProof(root, "two", "TWO", branchMask, siblings);
    }
}
