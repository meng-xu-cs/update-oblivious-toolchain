pragma solidity ^0.8.0;

contract ERC20Lite {
    mapping(address => uint256) private balances;
    mapping(bytes32 => uint256) private allowances;

    function allowanceKey(address owner, address spender) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, spender));
    }

    function mint(address owner, uint256 amount) public {
        balances[owner] = balances[owner] + amount;
    }

    function approve(address owner, address spender, uint256 amount) public {
        bytes32 key = allowanceKey(owner, spender);
        allowances[key] = amount;
    }

    function transfer(address from, address to, uint256 amount) public returns (uint256) {
        uint256 fromBalance = balances[from];
        require(fromBalance >= amount);
        balances[from] = fromBalance - amount;
        balances[to] = balances[to] + amount;
        return 1;
    }

    function transferFrom(address owner, address spender, address to, uint256 amount) public returns (uint256) {
        bytes32 key = allowanceKey(owner, spender);
        uint256 allowance = allowances[key];
        uint256 fromBalance = balances[owner];
        require(allowance >= amount);
        require(fromBalance >= amount);
        allowances[key] = allowance - amount;
        balances[owner] = fromBalance - amount;
        balances[to] = balances[to] + amount;
        return 1;
    }

    function balanceOf(address owner) public returns (uint256) {
        return balances[owner];
    }

    function allowanceOf(address owner, address spender) public returns (uint256) {
        bytes32 key = allowanceKey(owner, spender);
        return allowances[key];
    }
}
