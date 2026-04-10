pragma solidity ^0.8.0;

contract FixedSlotClassifier {
    uint256 private last;

    function classify(uint256 secret) public {
        uint256 bit = secret & 1;
        last = bit;
    }

    function sameSame(uint256 secret) public {
        uint256 ignored = secret & 7;
        last = 1;
    }

    function peek() public returns (uint256) {
        return last;
    }
}
