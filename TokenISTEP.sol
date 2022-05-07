//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

contract TokenISTEP is OwnableUpgradeable, ERC20Upgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    mapping(address => uint256) private lockBalances;

    EnumerableSetUpgradeable.AddressSet private operatorAccounts;

    uint256 public unlockPercent;

    modifier onlyOperatorAccount() {
        require(operatorAccounts.contains(msg.sender), "Only operator accounts");
        _;
    }

    function initialize(address[] memory accounts) public initializer {
        __Ownable_init();
        __ERC20_init("ISTEP", "ISTEP");
        _mint(owner(), 300_000_000 * 10**18);

        unlockPercent = 0;

        for (uint256 i = 0; i < accounts.length; i++) {
            operatorAccounts.add(accounts[i]);
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function addOperatorAccount(address account) external onlyOwner {
        operatorAccounts.add(account);
    }

    function removeOperatorAccount(address account) external onlyOwner {
        operatorAccounts.remove(account);
    }

    function setUnlockPercent(uint256 percent) external onlyOperatorAccount {
        require(percent <= 100);
        unlockPercent = percent;
    }

    function mint(address account, uint256 amount) external onlyOperatorAccount {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external onlyOperatorAccount {
        _burn(account, amount);
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        if (unlockPercent < 100) {
            uint256 locked = (lockBalances[msg.sender] * (100 - unlockPercent)) / 100;
            require(balanceOf(msg.sender) - locked >= amount, "Unlocked balance is not enough");
        }

        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        if (unlockPercent < 100) {
            uint256 locked = (lockBalances[from] * (100 - unlockPercent)) / 100;
            require(balanceOf(from) - locked > amount, "Unlocked balance is not enough");
        }

        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function transferAndLock(address to, uint256 amount) public onlyOperatorAccount returns (bool) {
        _transfer(msg.sender, to, amount);
        lockBalances[to] = lockBalances[to] + amount;
        return true;
    }

    function transferFromAndUnlock(
        address from,
        address to,
        uint256 amount
    ) public onlyOperatorAccount returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);

        uint256 locked = (lockBalances[from] * (100 - unlockPercent)) / 100;
        if (locked > amount) {
            lockBalances[from] = lockBalances[from] - amount;
        } else {
            lockBalances[from] = 0;
        }
        return true;
    }
}
