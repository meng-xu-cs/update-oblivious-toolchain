pragma solidity ^0.8.0;

contract SingleAccessMap {
    mapping(bytes32 => uint256) private records;

    function put(bytes32 key, uint256 value) public {
        records[key] = value;
    }

    function clear(bytes32 key) public {
        records[key] = 0;
    }

    function add(bytes32 key, uint256 delta) public {
        uint256 current = records[key];
        records[key] = current + delta;
    }

    function read(bytes32 key) public returns (uint256) {
        return records[key];
    }
}
