pragma solidity ^0.8.0;

// The matched baselines' map with 1-byte values (Issue 49 of the external
// review): SweepMap's put and read, of a flag. Not a benchmark.
contract SweepFlagMap {
    mapping(bytes32 => bool) private records;

    function put(bytes32 key, bool value) public {
        records[key] = value;
    }

    function read(bytes32 key) public returns (bool) {
        return records[key];
    }
}
