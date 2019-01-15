pragma solidity >=0.5.0 <0.6.0;

library D {
    struct Label {
        bytes32 data;
        uint length;
    }
    struct Edge {
        bytes32 node;
        Label label;
    }
    struct Node {
        Edge[2] children;
    }
}
