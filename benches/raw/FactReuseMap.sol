pragma solidity ^0.8.0;

// A test contract for the fact reuse of Issue 48 of the external review: a
// lookup of a Path ORAM map whose key the program shows equal to an earlier
// lookup's in the call reuses what that lookup found. It is not one of the
// benchmarks; the runtime's tests and the tamper suite compile it.
contract FactReuseMap {
    mapping(bytes32 => uint256) private records;

    function put(bytes32 key, uint256 value) public {
        records[key] = value;
    }

    // On the private scheme each write reuses the presence the get of its
    // key found, though another access comes between.
    function swap(bytes32 a, bytes32 b) public {
        uint256 x = records[a];
        uint256 y = records[b];
        records[a] = y;
        records[b] = x;
    }

    // The get in the write's value reuses the value the require's get found,
    // on either scheme; on the private scheme the write reuses its presence.
    function take(bytes32 key, uint256 amount) public {
        require(records[key] >= amount);
        records[key] = records[key] - amount;
    }

    function read(bytes32 key) public returns (uint256) {
        return records[key];
    }
}
