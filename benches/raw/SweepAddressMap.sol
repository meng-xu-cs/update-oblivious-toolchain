pragma solidity ^0.8.0;

// The matched baselines' map with 20-byte keys (Issue 49 of the external
// review): SweepMap's put and read, keyed by address. Not a benchmark.
contract SweepAddressMap {
    mapping(address => uint256) private records;

    function put(address key, uint256 value) public {
        records[key] = value;
    }

    function read(address key) public returns (uint256) {
        return records[key];
    }
}
