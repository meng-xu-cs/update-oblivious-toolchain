pragma solidity ^0.8.0;

contract SingleAccessMap {
    mapping(bytes32 => uint256) private records;

    function put(bytes32 key, uint256 value) public {
        records[key] = value;
    }

    function clear(bytes32 key) public {
        records[key] = 0;
    }

    function read(bytes32 key) public returns (uint256) {
        return records[key];
    }
}
