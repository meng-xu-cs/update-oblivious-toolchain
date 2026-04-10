pragma solidity ^0.8.0;

contract RegistryCRUD {
    mapping(bytes32 => uint256) private records;

    function upsert(bytes32 key, uint256 value) public {
        records[key] = value;
    }

    function clear(bytes32 key) public {
        records[key] = 0;
    }

    function clearIfMatch(bytes32 key, uint256 value) public returns (uint256) {
        uint256 current = records[key];
        uint256 result = 0;
        if (current == value) {
            records[key] = 0;
            result = 1;
        }
        return result;
    }

    function read(bytes32 key) public returns (uint256) {
        return records[key];
    }
}
