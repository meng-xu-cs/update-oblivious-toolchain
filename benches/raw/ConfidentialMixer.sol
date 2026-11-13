pragma solidity ^0.8.0;

contract ConfidentialMixer {
    mapping(bytes32 => uint256) private balances;
    uint256 private total;

    function deposit(bytes32 commitment, uint256 amount) public {
        uint256 oldBalance = balances[commitment];
        balances[commitment] = oldBalance + amount;
        total = total + amount;
    }

    function withdraw(bytes32 commitment, uint256 amount) public returns (uint256) {
        uint256 oldBalance = balances[commitment];
        require(oldBalance >= amount);
        balances[commitment] = oldBalance - amount;
        total = total - amount;
        return amount;
    }

    function balanceOf(bytes32 commitment) public returns (uint256) {
        return balances[commitment];
    }

    function sealedBalanceOf(bytes32 commitment) public returns (uint256) {
        return balances[commitment];
    }

    function totalValue() public returns (uint256) {
        return total;
    }
}
