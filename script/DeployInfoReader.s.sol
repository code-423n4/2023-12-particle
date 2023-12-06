// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "../lib/forge-std/src/Script.sol";
import {ParticleInfoReader} from "../contracts/protocol/ParticleInfoReader.sol";
import {ERC1967Proxy} from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

address constant PARTICLE_POSITION_MANAGER = address(0x42); // deployed particle address

contract DeployParticleInfoReader is Script {
    event Deployed(address infoReader);

    ParticleInfoReader public infoReader;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ParticleInfoReader infoReaderImpl = new ParticleInfoReader();
        ERC1967Proxy proxy = new ERC1967Proxy(address(infoReaderImpl), "");
        infoReader = ParticleInfoReader(payable(address(proxy)));
        infoReader.initialize(PARTICLE_POSITION_MANAGER);
        emit Deployed(address(infoReader));

        vm.stopBroadcast();
    }
}
