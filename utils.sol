pragma solidity ^0.4.0;

import {D} from "./data.sol";

library Utils {
    /// Returns a label containing the longest common prefix of `check` and `label`
    /// and a label consisting of the remaining part of `label`.
    function splitCommonPrefix(D.Label label, D.Label check) internal returns (D.Label prefix, D.Label labelSuffix) {
        return splitAt(label, commonPrefix(check, label));
    }
    /// Splits the label at the given position and returns prefix and suffix,
    /// i.e. prefix.length == pos and prefix.data . suffix.data == l.data.
    function splitAt(D.Label l, uint pos) internal returns (D.Label prefix, D.Label suffix) {
        require(pos <= l.length && pos <= 256);
        prefix.length = pos;
        if (pos == 0) {
            prefix.data = bytes32(0);
        } else {
            prefix.data = l.data & ~bytes32((uint(1) << (256 - pos)) - 1);
        }
        suffix.length = l.length - pos;
        suffix.data = l.data << pos;
    }
    /// Returns the length of the longest common prefix of the two labels.
    function commonPrefix(D.Label a, D.Label b) internal returns (uint prefix) {
        uint length = a.length < b.length ? a.length : b.length;
        // TODO: This could actually use a "highestBitSet" helper
        uint diff = uint(a.data ^ b.data);
        uint mask = 1 << 255;
        for (; prefix < length; prefix++)
        {
            if ((mask & diff) != 0)
                break;
            diff += diff;
        }
    }
    /// Returns the result of removing a prefix of length `prefix` bits from the
    /// given label (i.e. shifting its data to the left).
    function removePrefix(D.Label l, uint prefix) internal returns (D.Label r) {
        require(prefix <= l.length);
        r.length = l.length - prefix;
        r.data = l.data << prefix;
    }
    /// Removes the first bit from a label and returns the bit and a
    /// label containing the rest of the label (i.e. shifted to the left).
    function chopFirstBit(D.Label l) internal returns (uint firstBit, D.Label tail) {
        require(l.length > 0);
        return (uint(l.data >> 255), D.Label(l.data << 1, l.length - 1));
    }
    /// Returns the first bit set in the bitfield, where the 0th bit
    /// is the least significant.
    /// Throws if bitfield is zero.
    /// More efficient the smaller the result is.
    function lowestBitSet(uint bitfield) internal returns (uint bit) {
        require(bitfield != 0);
        bytes32 bitfieldBytes = bytes32(bitfield);
        // First, find the lowest byte set
        for (uint byteSet = 0; byteSet < 32; byteSet++) {
            if (bitfieldBytes[31 - byteSet] != 0)
                break;
        }
        uint singleByte = uint(uint8(bitfieldBytes[31 - byteSet]));
        uint mask = 1;
        for (bit = 0; bit < 256; bit ++) {
            if ((singleByte & mask) != 0)
                return 8 * byteSet + bit;
            mask += mask;
        }
        assert(false);
        return 0;
    }
    /// Returns the value of the `bit`th bit inside `bitfield`, where
    /// the least significant is the 0th bit.
    function bitSet(uint bitfield, uint bit) internal returns (uint) {
        return (bitfield & (uint(1) << bit)) != 0 ? 1 : 0;
    }
}


contract UtilsTest {
    function test() {
        testLowestBitSet();
        testChopFirstBit();
        testRemovePrefix();
        testCommonPrefix();
        testSplitAt();
        testSplitCommonPrefix();
    }
    function testLowestBitSet() internal {
        require(Utils.lowestBitSet(0x123) == 0);
        require(Utils.lowestBitSet(0x124) == 2);
        require(Utils.lowestBitSet(0x11 << 30) == 30);
        require(Utils.lowestBitSet(1 << 255) == 255);
    }
    function testChopFirstBit() internal {
        D.Label memory l;
        l.data = hex"ef1230";
        l.length = 20;
        uint bit1;
        uint bit2;
        uint bit3;
        uint bit4;
        (bit1, l) = Utils.chopFirstBit(l);
        (bit2, l) = Utils.chopFirstBit(l);
        (bit3, l) = Utils.chopFirstBit(l);
        (bit4, l) = Utils.chopFirstBit(l);
        require(bit1 == 1);
        require(bit2 == 1);
        require(bit3 == 1);
        require(bit4 == 0);
        require(l.length == 16);
        require(l.data == hex"F123");

        l.data = hex"80";
        l.length = 1;
        (bit1, l) = Utils.chopFirstBit(l);
        require(bit1 == 1);
        require(l.length == 0);
        require(l.data == 0);
    }
    function testRemovePrefix() internal {
        D.Label memory l;
        l.data = hex"ef1230";
        l.length = 20;
        l = Utils.removePrefix(l, 4);
        require(l.length == 16);
        require(l.data == hex"f123");
        l = Utils.removePrefix(l, 15);
        require(l.length == 1);
        require(l.data == hex"80");
        l = Utils.removePrefix(l, 1);
        require(l.length == 0);
        require(l.data == 0);
    }
    function testCommonPrefix() internal {
        D.Label memory a;
        D.Label memory b;
        a.data = hex"abcd";
        a.length = 16;
        b.data = hex"a000";
        b.length = 16;
        require(Utils.commonPrefix(a, b) == 4);

        b.length = 0;
        require(Utils.commonPrefix(a, b) == 0);

        b.data = hex"bbcd";
        b.length = 16;
        require(Utils.commonPrefix(a, b) == 3);
        require(Utils.commonPrefix(b, b) == b.length);
    }
    function testSplitAt() internal {
        D.Label memory a;
        a.data = hex"abcd";
        a.length = 16;
        var (x, y) = Utils.splitAt(a, 0);
        require(x.length == 0);
        require(y.length == a.length);
        require(y.data == a.data);

        (x, y) = Utils.splitAt(a, 4);
        require(x.length == 4);
        require(x.data == hex"a0");
        require(y.length == 12);
        require(y.data == hex"bcd0");

        (x, y) = Utils.splitAt(a, 16);
        require(y.length == 0);
        require(x.length == a.length);
        require(x.data == a.data);
    }
    function testSplitCommonPrefix() internal {
        D.Label memory a;
        D.Label memory b;
        a.data = hex"abcd";
        a.length = 16;
        b.data = hex"a0f570";
        b.length = 20;
        var (prefix, suffix) = Utils.splitCommonPrefix(b, a);
        require(prefix.length == 4);
        require(prefix.data == hex"a0");
        require(suffix.length == 16);
        require(suffix.data == hex"0f57");
    }
}
