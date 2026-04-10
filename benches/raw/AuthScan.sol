pragma solidity ^0.8.0;

contract AuthScan {
    bytes32[4] private TOKENS;
    uint256 private lastAuth;

    function seed(uint256 index, bytes32 token) public {
        TOKENS[index] = token;
    }

    function auth(bytes32 token) public returns (uint256) {
        uint256 result = 0;
        for (uint256 i = 0; i < TOKENS.length; i++) {
            if (TOKENS[i] == token) {
                result = 1;
            }
        }
        lastAuth = result;
        return result;
    }

    function readLast() public returns (uint256) {
        return lastAuth;
    }
}
