// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "../lib/forge-std/src/Script.sol";
import {ParticlePositionManager} from "../contracts/protocol/ParticlePositionManager.sol";
import {ERC1967Proxy} from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

///@dev uniswap v3 router: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
///@dev 1inch v5 router: 0x1111111254EEB25477B68fb85Ed929f73A960582
address constant DEX_AGGREGATOR = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
uint256 constant FEE_FACTOR = 500;
uint128 constant LIQUIDATION_REWARD_FACTOR = 50_000;
uint256 constant LOAN_TERM = 7 days;
uint256 constant TREASURY_RATE = 500_000;

contract DeployParticlePositionManager is Script {
    event Deployed(address positionManager);

    ParticlePositionManager public positionManager;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ParticlePositionManager positionManagerImpl = new ParticlePositionManager();
        ERC1967Proxy proxy = new ERC1967Proxy(address(positionManagerImpl), "");
        positionManager = ParticlePositionManager(payable(address(proxy)));
        positionManager.initialize(DEX_AGGREGATOR, FEE_FACTOR, LIQUIDATION_REWARD_FACTOR, LOAN_TERM, TREASURY_RATE);
        emit Deployed(address(positionManager));

        vm.stopBroadcast();
    }
}
