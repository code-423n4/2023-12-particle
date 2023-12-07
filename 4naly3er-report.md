# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | Cache array length outside of loop | 1 |
| [GAS-2](#GAS-2) | For Operations that will not overflow, you could use unchecked | 342 |
| [GAS-3](#GAS-3) | Don't initialize variables with default value | 2 |
| [GAS-4](#GAS-4) | Functions guaranteed to revert when called by normal users can be marked `payable` | 9 |
| [GAS-5](#GAS-5) | `++i` costs less gas than `i++`, especially when it's used in `for`-loops (`--i`/`i--` too) | 2 |
| [GAS-6](#GAS-6) | Use != 0 instead of > 0 for unsigned integer comparison | 9 |
### <a name="GAS-1"></a>[GAS-1] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (1)*:
```solidity
File: contracts/protocol/ParticleInfoReader.sol

106:         for (uint256 i = 0; i < feeTiers.length; i++) {

```

### <a name="GAS-2"></a>[GAS-2] For Operations that will not overflow, you could use unchecked

*Instances (342)*:
```solidity
File: contracts/interfaces/IParticlePositionManager.sol

4: import {DataStruct} from "../libraries/Structs.sol";

4: import {DataStruct} from "../libraries/Structs.sol";

9:     ==============================================================*/

9:     ==============================================================*/

24:     ==============================================================*/

24:     ==============================================================*/

33:     ==============================================================*/

33:     ==============================================================*/

56:     ==============================================================*/

56:     ==============================================================*/

111:     ==============================================================*/

111:     ==============================================================*/

124:     ==============================================================*/

124:     ==============================================================*/

```

```solidity
File: contracts/libraries/Base.sol

4: import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

4: import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

4: import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

4: import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

4: import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

4: import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

4: import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

5: import {FixedPoint128} from "../../lib/v3-core/contracts/libraries/FixedPoint128.sol";

5: import {FixedPoint128} from "../../lib/v3-core/contracts/libraries/FixedPoint128.sol";

5: import {FixedPoint128} from "../../lib/v3-core/contracts/libraries/FixedPoint128.sol";

5: import {FixedPoint128} from "../../lib/v3-core/contracts/libraries/FixedPoint128.sol";

5: import {FixedPoint128} from "../../lib/v3-core/contracts/libraries/FixedPoint128.sol";

5: import {FixedPoint128} from "../../lib/v3-core/contracts/libraries/FixedPoint128.sol";

5: import {FixedPoint128} from "../../lib/v3-core/contracts/libraries/FixedPoint128.sol";

6: import {IUniswapV3Pool} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

6: import {IUniswapV3Pool} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

6: import {IUniswapV3Pool} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

6: import {IUniswapV3Pool} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

6: import {IUniswapV3Pool} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

6: import {IUniswapV3Pool} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

6: import {IUniswapV3Pool} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

7: import {IUniswapV3Factory} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

7: import {IUniswapV3Factory} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

7: import {IUniswapV3Factory} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

7: import {IUniswapV3Factory} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

7: import {IUniswapV3Factory} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

7: import {IUniswapV3Factory} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

7: import {IUniswapV3Factory} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

8: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

8: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

8: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

8: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

8: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

8: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

8: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

10: import {INonfungiblePositionManager} from "../interfaces/INonfungiblePositionManager.sol";

10: import {INonfungiblePositionManager} from "../interfaces/INonfungiblePositionManager.sol";

11: import {Errors} from "./Errors.sol";

12: import {FullMath} from "./FullMath.sol";

13: import {TickMath} from "./TickMath.sol";

14: import {LiquidityAmounts} from "./LiquidityAmounts.sol";

15: import {DataStruct, DataCache} from "../libraries/Structs.sol";

15: import {DataStruct, DataCache} from "../libraries/Structs.sol";

62:         amountSpent = balanceFromBefore - IERC20(tokenFrom).balanceOf(address(this));

63:         amountReceived = IERC20(tokenTo).balanceOf(address(this)) - balanceToBefore;

77:             TransferHelper.safeTransfer(token, recipient, amountExpected - amountActual);

331:             feeGrowthInside0X128 = lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;

332:             feeGrowthInside1X128 = lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;

336:             feeGrowthInside0X128 = feeGrowthGlobal0X128 - lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;

336:             feeGrowthInside0X128 = feeGrowthGlobal0X128 - lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;

337:             feeGrowthInside1X128 = feeGrowthGlobal1X128 - lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;

337:             feeGrowthInside1X128 = feeGrowthGlobal1X128 - lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;

339:             feeGrowthInside0X128 = upperFeeGrowthOutside0X128 - lowerFeeGrowthOutside0X128;

340:             feeGrowthInside1X128 = upperFeeGrowthOutside1X128 - lowerFeeGrowthOutside1X128;

363:                 FullMath.mulDiv(feeGrowthInside0X128 - feeGrowthInside0LastX128, liquidity, FixedPoint128.Q128)

368:                 FullMath.mulDiv(feeGrowthInside1X128 - feeGrowthInside1LastX128, liquidity, FixedPoint128.Q128)

388:         token0Premium = uint128((token0PremiumPortion * collateral0) / BASIS_POINT);

388:         token0Premium = uint128((token0PremiumPortion * collateral0) / BASIS_POINT);

389:         token1Premium = uint128((token1PremiumPortion * collateral1) / BASIS_POINT);

389:         token1Premium = uint128((token1PremiumPortion * collateral1) / BASIS_POINT);

```

```solidity
File: contracts/libraries/LiquidityPosition.sol

4: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

4: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

4: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

4: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

4: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

4: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

4: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

5: import {INonfungiblePositionManager} from "../interfaces/INonfungiblePositionManager.sol";

5: import {INonfungiblePositionManager} from "../interfaces/INonfungiblePositionManager.sol";

6: import {DataStruct} from "./Structs.sol";

7: import {Errors} from "./Errors.sol";

8: import {Base} from "./Base.sol";

15:         uint32 renewalCutoffTime; ///@dev loans before this time can't be renewed

15:         uint32 renewalCutoffTime; ///@dev loans before this time can't be renewed

15:         uint32 renewalCutoffTime; ///@dev loans before this time can't be renewed

27:     ==============================================================*/

27:     ==============================================================*/

60:     ==============================================================*/

60:     ==============================================================*/

76:         info.token0Owed += token0Owed;

77:         info.token1Owed += token1Owed;

93:     ==============================================================*/

93:     ==============================================================*/

107:     ==============================================================*/

107:     ==============================================================*/

164:     ==============================================================*/

164:     ==============================================================*/

243:     ==============================================================*/

243:     ==============================================================*/

285:     ==============================================================*/

285:     ==============================================================*/

335:             amount0Collected += token0Owed;

339:             amount1Collected += token1Owed;

348:     ==============================================================*/

348:     ==============================================================*/

```

```solidity
File: contracts/libraries/Structs.sol

58:         uint256 collateralFrom; ///@dev collateralTo is the position amount in the returns

58:         uint256 collateralFrom; ///@dev collateralTo is the position amount in the returns

58:         uint256 collateralFrom; ///@dev collateralTo is the position amount in the returns

```

```solidity
File: contracts/libraries/SwapPosition.sol

4: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

4: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

4: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

4: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

4: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

4: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

4: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

5: import {Errors} from "./Errors.sol";

6: import {Base} from "./Base.sol";

18:     ==============================================================*/

18:     ==============================================================*/

```

```solidity
File: contracts/protocol/ParticleInfoReader.sol

4: import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

4: import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

4: import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

4: import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

4: import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

4: import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

4: import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

5: import {Multicall} from "../../lib/openzeppelin-contracts/contracts/utils/Multicall.sol";

5: import {Multicall} from "../../lib/openzeppelin-contracts/contracts/utils/Multicall.sol";

5: import {Multicall} from "../../lib/openzeppelin-contracts/contracts/utils/Multicall.sol";

5: import {Multicall} from "../../lib/openzeppelin-contracts/contracts/utils/Multicall.sol";

5: import {Multicall} from "../../lib/openzeppelin-contracts/contracts/utils/Multicall.sol";

5: import {Multicall} from "../../lib/openzeppelin-contracts/contracts/utils/Multicall.sol";

5: import {Multicall} from "../../lib/openzeppelin-contracts/contracts/utils/Multicall.sol";

6: import {Ownable2StepUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

6: import {Ownable2StepUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

6: import {Ownable2StepUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

6: import {Ownable2StepUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

6: import {Ownable2StepUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

6: import {Ownable2StepUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

6: import {Ownable2StepUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

6: import {Ownable2StepUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

7: import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

7: import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

7: import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

7: import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

7: import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

7: import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

7: import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

7: import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

7: import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

8: import {IUniswapV3Pool} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

8: import {IUniswapV3Pool} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

8: import {IUniswapV3Pool} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

8: import {IUniswapV3Pool} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

8: import {IUniswapV3Pool} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

8: import {IUniswapV3Pool} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

8: import {IUniswapV3Pool} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

9: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

9: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

9: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

9: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

9: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

9: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

9: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

11: import {ParticlePositionManager} from "./ParticlePositionManager.sol";

12: import {Errors} from "../libraries/Errors.sol";

12: import {Errors} from "../libraries/Errors.sol";

13: import {Base} from "../libraries/Base.sol";

13: import {Base} from "../libraries/Base.sol";

14: import {LiquidityPosition} from "../libraries/LiquidityPosition.sol";

14: import {LiquidityPosition} from "../libraries/LiquidityPosition.sol";

15: import {Lien} from "../libraries/Lien.sol";

15: import {Lien} from "../libraries/Lien.sol";

16: import {FullMath} from "../libraries/FullMath.sol";

16: import {FullMath} from "../libraries/FullMath.sol";

17: import {TickMath} from "../libraries/TickMath.sol";

17: import {TickMath} from "../libraries/TickMath.sol";

18: import {LiquidityAmounts} from "../libraries/LiquidityAmounts.sol";

18: import {LiquidityAmounts} from "../libraries/LiquidityAmounts.sol";

19: import {DataStruct, DataCache} from "../libraries/Structs.sol";

19: import {DataStruct, DataCache} from "../libraries/Structs.sol";

46:     ==============================================================*/

46:     ==============================================================*/

61:     ==============================================================*/

61:     ==============================================================*/

106:         for (uint256 i = 0; i < feeTiers.length; i++) {

106:         for (uint256 i = 0; i < feeTiers.length; i++) {

121:     ==============================================================*/

121:     ==============================================================*/

199:     ==============================================================*/

199:     ==============================================================*/

218:     ==============================================================*/

218:     ==============================================================*/

```

```solidity
File: contracts/protocol/ParticlePositionManager.sol

4: import {IERC721Receiver} from "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

4: import {IERC721Receiver} from "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

4: import {IERC721Receiver} from "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

4: import {IERC721Receiver} from "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

4: import {IERC721Receiver} from "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

4: import {IERC721Receiver} from "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

4: import {IERC721Receiver} from "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

4: import {IERC721Receiver} from "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

5: import {Multicall} from "../../lib/openzeppelin-contracts/contracts/utils/Multicall.sol";

5: import {Multicall} from "../../lib/openzeppelin-contracts/contracts/utils/Multicall.sol";

5: import {Multicall} from "../../lib/openzeppelin-contracts/contracts/utils/Multicall.sol";

5: import {Multicall} from "../../lib/openzeppelin-contracts/contracts/utils/Multicall.sol";

5: import {Multicall} from "../../lib/openzeppelin-contracts/contracts/utils/Multicall.sol";

5: import {Multicall} from "../../lib/openzeppelin-contracts/contracts/utils/Multicall.sol";

5: import {Multicall} from "../../lib/openzeppelin-contracts/contracts/utils/Multicall.sol";

6: import {ReentrancyGuard} from "../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

6: import {ReentrancyGuard} from "../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

6: import {ReentrancyGuard} from "../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

6: import {ReentrancyGuard} from "../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

6: import {ReentrancyGuard} from "../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

6: import {ReentrancyGuard} from "../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

6: import {ReentrancyGuard} from "../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

7: import {Ownable2StepUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

7: import {Ownable2StepUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

7: import {Ownable2StepUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

7: import {Ownable2StepUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

7: import {Ownable2StepUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

7: import {Ownable2StepUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

7: import {Ownable2StepUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

7: import {Ownable2StepUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

8: import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

8: import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

8: import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

8: import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

8: import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

8: import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

8: import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

8: import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

8: import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

9: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

9: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

9: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

9: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

9: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

9: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

9: import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

11: import {IParticlePositionManager} from "../interfaces/IParticlePositionManager.sol";

11: import {IParticlePositionManager} from "../interfaces/IParticlePositionManager.sol";

12: import {Base} from "../libraries/Base.sol";

12: import {Base} from "../libraries/Base.sol";

13: import {LiquidityPosition} from "../libraries/LiquidityPosition.sol";

13: import {LiquidityPosition} from "../libraries/LiquidityPosition.sol";

14: import {Lien} from "../libraries/Lien.sol";

14: import {Lien} from "../libraries/Lien.sol";

15: import {SwapPosition} from "../libraries/SwapPosition.sol";

15: import {SwapPosition} from "../libraries/SwapPosition.sol";

16: import {DataStruct, DataCache} from "../libraries/Structs.sol";

16: import {DataStruct, DataCache} from "../libraries/Structs.sol";

17: import {Errors} from "../libraries/Errors.sol";

17: import {Errors} from "../libraries/Errors.sol";

38:     uint96 private _nextRecordId; ///@dev used for both lien and swap

38:     uint96 private _nextRecordId; ///@dev used for both lien and swap

38:     uint96 private _nextRecordId; ///@dev used for both lien and swap

48:     mapping(uint256 => LiquidityPosition.Info) public lps; ///@dev tokenId => liquidity position

48:     mapping(uint256 => LiquidityPosition.Info) public lps; ///@dev tokenId => liquidity position

48:     mapping(uint256 => LiquidityPosition.Info) public lps; ///@dev tokenId => liquidity position

49:     mapping(bytes32 => Lien.Info) public liens; ///@dev (address, lienId) => lien

49:     mapping(bytes32 => Lien.Info) public liens; ///@dev (address, lienId) => lien

49:     mapping(bytes32 => Lien.Info) public liens; ///@dev (address, lienId) => lien

50:     mapping(address => uint256) private _treasury; ///@dev address => amount

50:     mapping(address => uint256) private _treasury; ///@dev address => amount

50:     mapping(address => uint256) private _treasury; ///@dev address => amount

78:     ==============================================================*/

78:     ==============================================================*/

115:     ==============================================================*/

115:     ==============================================================*/

148:     ==============================================================*/

148:     ==============================================================*/

193:             cache.feeAmount = ((params.marginFrom + cache.amountFromBorrowed) * FEE_FACTOR) / Base.BASIS_POINT;

193:             cache.feeAmount = ((params.marginFrom + cache.amountFromBorrowed) * FEE_FACTOR) / Base.BASIS_POINT;

193:             cache.feeAmount = ((params.marginFrom + cache.amountFromBorrowed) * FEE_FACTOR) / Base.BASIS_POINT;

194:             cache.treasuryAmount = (cache.feeAmount * _treasuryRate) / Base.BASIS_POINT;

194:             cache.treasuryAmount = (cache.feeAmount * _treasuryRate) / Base.BASIS_POINT;

195:             _treasury[cache.tokenFrom] += cache.treasuryAmount;

197:                 lps.addTokensOwed(params.tokenId, uint128(cache.feeAmount - cache.treasuryAmount), 0);

199:                 lps.addTokensOwed(params.tokenId, 0, uint128(cache.feeAmount - cache.treasuryAmount));

204:         if (params.amountSwap > params.marginFrom + cache.amountFromBorrowed - cache.feeAmount)

204:         if (params.amountSwap > params.marginFrom + cache.amountFromBorrowed - cache.feeAmount)

212:             collateralTo - cache.amountToBorrowed - params.marginTo, // amount needed to meet requirement

212:             collateralTo - cache.amountToBorrowed - params.marginTo, // amount needed to meet requirement

212:             collateralTo - cache.amountToBorrowed - params.marginTo, // amount needed to meet requirement

212:             collateralTo - cache.amountToBorrowed - params.marginTo, // amount needed to meet requirement

220:                 ((params.marginFrom + cache.amountFromBorrowed - cache.feeAmount - cache.amountSpent) *

220:                 ((params.marginFrom + cache.amountFromBorrowed - cache.feeAmount - cache.amountSpent) *

220:                 ((params.marginFrom + cache.amountFromBorrowed - cache.feeAmount - cache.amountSpent) *

220:                 ((params.marginFrom + cache.amountFromBorrowed - cache.feeAmount - cache.amountSpent) *

221:                     Base.BASIS_POINT) / cache.collateralFrom

224:                 ((cache.amountReceived + cache.amountToBorrowed + params.marginTo - collateralTo) * Base.BASIS_POINT) /

224:                 ((cache.amountReceived + cache.amountToBorrowed + params.marginTo - collateralTo) * Base.BASIS_POINT) /

224:                 ((cache.amountReceived + cache.amountToBorrowed + params.marginTo - collateralTo) * Base.BASIS_POINT) /

224:                 ((cache.amountReceived + cache.amountToBorrowed + params.marginTo - collateralTo) * Base.BASIS_POINT) /

224:                 ((cache.amountReceived + cache.amountToBorrowed + params.marginTo - collateralTo) * Base.BASIS_POINT) /

233:                 ((params.marginFrom + cache.amountFromBorrowed - cache.feeAmount - cache.amountSpent) *

233:                 ((params.marginFrom + cache.amountFromBorrowed - cache.feeAmount - cache.amountSpent) *

233:                 ((params.marginFrom + cache.amountFromBorrowed - cache.feeAmount - cache.amountSpent) *

233:                 ((params.marginFrom + cache.amountFromBorrowed - cache.feeAmount - cache.amountSpent) *

234:                     Base.BASIS_POINT) / cache.collateralFrom

237:                 ((cache.amountReceived + cache.amountToBorrowed + params.marginTo - collateralTo) * Base.BASIS_POINT) /

237:                 ((cache.amountReceived + cache.amountToBorrowed + params.marginTo - collateralTo) * Base.BASIS_POINT) /

237:                 ((cache.amountReceived + cache.amountToBorrowed + params.marginTo - collateralTo) * Base.BASIS_POINT) /

237:                 ((cache.amountReceived + cache.amountToBorrowed + params.marginTo - collateralTo) * Base.BASIS_POINT) /

237:                 ((cache.amountReceived + cache.amountToBorrowed + params.marginTo - collateralTo) * Base.BASIS_POINT) /

247:         liens[keccak256(abi.encodePacked(msg.sender, lienId = _nextRecordId++))] = Lien.Info({

247:         liens[keccak256(abi.encodePacked(msg.sender, lienId = _nextRecordId++))] = Lien.Info({

263:     ==============================================================*/

263:     ==============================================================*/

350:             ((closeCache.tokenFromPremium) * LIQUIDATION_REWARD_FACTOR) /

350:             ((closeCache.tokenFromPremium) * LIQUIDATION_REWARD_FACTOR) /

353:             ((closeCache.tokenToPremium) * LIQUIDATION_REWARD_FACTOR) /

353:             ((closeCache.tokenToPremium) * LIQUIDATION_REWARD_FACTOR) /

355:         closeCache.tokenFromPremium -= liquidateCache.liquidationRewardFrom;

356:         closeCache.tokenToPremium -= liquidateCache.liquidationRewardTo;

365:                     lien.startTime + LOAN_TERM < block.timestamp))

398:         if (params.amountSwap + params.repayFrom > cache.collateralFrom + cache.tokenFromPremium)

398:         if (params.amountSwap + params.repayFrom > cache.collateralFrom + cache.tokenFromPremium)

465:                 cache.collateralFrom + cache.tokenFromPremium,

466:                 cache.amountSpent + cache.amountFromAdd + cache.token1Owed

466:                 cache.amountSpent + cache.amountFromAdd + cache.token1Owed

468:             Base.refundWithCheck(borrower, cache.tokenTo, cache.amountReceived, cache.amountToAdd + cache.token0Owed);

475:                 cache.collateralFrom + cache.tokenFromPremium,

476:                 cache.amountSpent + cache.amountFromAdd + cache.token0Owed

476:                 cache.amountSpent + cache.amountFromAdd + cache.token0Owed

478:             Base.refundWithCheck(borrower, cache.tokenTo, cache.amountReceived, cache.amountToAdd + cache.token1Owed);

487:     ==============================================================*/

487:     ==============================================================*/

514:             uint24(((token0Premium + premium0) * Base.BASIS_POINT) / collateral0),

514:             uint24(((token0Premium + premium0) * Base.BASIS_POINT) / collateral0),

514:             uint24(((token0Premium + premium0) * Base.BASIS_POINT) / collateral0),

515:             uint24(((token1Premium + premium1) * Base.BASIS_POINT) / collateral1)

515:             uint24(((token1Premium + premium1) * Base.BASIS_POINT) / collateral1)

515:             uint24(((token1Premium + premium1) * Base.BASIS_POINT) / collateral1)

531:     ==============================================================*/

531:     ==============================================================*/

546:     ==============================================================*/

546:     ==============================================================*/

```

### <a name="GAS-3"></a>[GAS-3] Don't initialize variables with default value

*Instances (2)*:
```solidity
File: contracts/protocol/ParticleInfoReader.sol

104:         uint128 maxLiquidity = 0;

106:         for (uint256 i = 0; i < feeTiers.length; i++) {

```

### <a name="GAS-4"></a>[GAS-4] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (9)*:
```solidity
File: contracts/protocol/ParticleInfoReader.sol

31:     function _authorizeUpgrade(address) internal override onlyOwner {}

52:     function updateParticleAddress(address particleAddr) external onlyOwner {

```

```solidity
File: contracts/protocol/ParticlePositionManager.sol

54:     function _authorizeUpgrade(address) internal override onlyOwner {}

549:     function updateDexAggregator(address dexAggregator) external override onlyOwner {

556:     function updateLiquidationRewardFactor(uint128 liquidationRewardFactor) external override onlyOwner {

563:     function updateFeeFactor(uint256 feeFactor) external override onlyOwner {

570:     function updateLoanTerm(uint256 loanTerm) external override onlyOwner {

577:     function updateTreasuryRate(uint256 treasuryRate) external override onlyOwner {

584:     function withdrawTreasury(address token, address recipient) external override onlyOwner nonReentrant {

```

### <a name="GAS-5"></a>[GAS-5] `++i` costs less gas than `i++`, especially when it's used in `for`-loops (`--i`/`i--` too)
*Saves 5 gas per loop*

*Instances (2)*:
```solidity
File: contracts/protocol/ParticleInfoReader.sol

106:         for (uint256 i = 0; i < feeTiers.length; i++) {

```

```solidity
File: contracts/protocol/ParticlePositionManager.sol

247:         liens[keccak256(abi.encodePacked(msg.sender, lienId = _nextRecordId++))] = Lien.Info({

```

### <a name="GAS-6"></a>[GAS-6] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (9)*:
```solidity
File: contracts/libraries/Base.sol

53:         if (amountFrom > 0) {

```

```solidity
File: contracts/libraries/LiquidityPosition.sol

334:         if (token0Owed > 0) {

338:         if (token1Owed > 0) {

```

```solidity
File: contracts/protocol/ParticlePositionManager.sol

184:         if (params.marginFrom > 0) {

187:         if (params.marginTo > 0) {

192:         if (FEE_FACTOR > 0) {

519:         if (premium0 > 0) {

522:         if (premium1 > 0) {

586:         if (withdrawAmount > 0) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) |  `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()` | 7 |
| [L-2](#L-2) | Do not use deprecated library functions | 10 |
| [L-3](#L-3) | Empty Function Body - Consider commenting why | 2 |
| [L-4](#L-4) | Initializers could be front-run | 8 |
### <a name="L-1"></a>[L-1]  `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()`
Use `abi.encode()` instead which will pad items to 32 bytes, which will [prevent hash collisions](https://docs.soliditylang.org/en/v0.8.13/abi-spec.html#non-standard-packed-mode) (e.g. `abi.encodePacked(0x123,0x456)` => `0x123456` => `abi.encodePacked(0x1,0x23456)`, but `abi.encode(0x123,0x456)` => `0x0...1230...456`). "Unless there is a compelling reason, `abi.encode` should be preferred". If there is only one argument to `abi.encodePacked()` it can often be cast to `bytes()` or `bytes32()` [instead](https://ethereum.stackexchange.com/questions/30912/how-to-compare-strings-in-solidity#answer-82739).
If all arguments are strings and or bytes, `bytes.concat()` should be used instead

*Instances (7)*:
```solidity
File: contracts/protocol/ParticleInfoReader.sol

302:         ) = _particlePositionManager.liens(keccak256(abi.encodePacked(borrower, lienId)));

326:         ) = _particlePositionManager.liens(keccak256(abi.encodePacked(borrower, lienId)));

378:         ) = _particlePositionManager.liens(keccak256(abi.encodePacked(borrower, lienId)));

```

```solidity
File: contracts/protocol/ParticlePositionManager.sol

247:         liens[keccak256(abi.encodePacked(msg.sender, lienId = _nextRecordId++))] = Lien.Info({

267:         bytes32 lienKey = keccak256(abi.encodePacked(msg.sender, params.lienId));

315:         bytes32 lienKey = keccak256(abi.encodePacked(borrower, params.lienId));

491:         bytes32 lienKey = keccak256(abi.encodePacked(msg.sender, lienId));

```

### <a name="L-2"></a>[L-2] Do not use deprecated library functions

*Instances (10)*:
```solidity
File: contracts/libraries/Base.sol

55:             TransferHelper.safeApprove(tokenFrom, dexAggregator, amountFrom);

59:             TransferHelper.safeApprove(tokenFrom, dexAggregator, 0);

```

```solidity
File: contracts/libraries/LiquidityPosition.sol

128:         TransferHelper.safeApprove(params.token0, Base.UNI_POSITION_MANAGER_ADDR, params.amount0ToMint);

129:         TransferHelper.safeApprove(params.token1, Base.UNI_POSITION_MANAGER_ADDR, params.amount1ToMint);

152:         TransferHelper.safeApprove(params.token0, Base.UNI_POSITION_MANAGER_ADDR, 0);

153:         TransferHelper.safeApprove(params.token1, Base.UNI_POSITION_MANAGER_ADDR, 0);

186:         TransferHelper.safeApprove(token0, Base.UNI_POSITION_MANAGER_ADDR, amount0);

187:         TransferHelper.safeApprove(token1, Base.UNI_POSITION_MANAGER_ADDR, amount1);

202:         TransferHelper.safeApprove(token0, Base.UNI_POSITION_MANAGER_ADDR, 0);

203:         TransferHelper.safeApprove(token1, Base.UNI_POSITION_MANAGER_ADDR, 0);

```

### <a name="L-3"></a>[L-3] Empty Function Body - Consider commenting why

*Instances (2)*:
```solidity
File: contracts/protocol/ParticleInfoReader.sol

31:     function _authorizeUpgrade(address) internal override onlyOwner {}

```

```solidity
File: contracts/protocol/ParticlePositionManager.sol

54:     function _authorizeUpgrade(address) internal override onlyOwner {}

```

### <a name="L-4"></a>[L-4] Initializers could be front-run
Initializers could be front-run, allowing an attacker to either set their own values, take ownership of the contract, and in the best case forcing a re-deployment

*Instances (8)*:
```solidity
File: contracts/protocol/ParticleInfoReader.sol

37:     function initialize(address particleAddr) external initializer {

37:     function initialize(address particleAddr) external initializer {

38:         __UUPSUpgradeable_init();

39:         __Ownable_init();

```

```solidity
File: contracts/protocol/ParticlePositionManager.sol

60:     function initialize(

66:     ) external initializer {

67:         __UUPSUpgradeable_init();

68:         __Ownable_init();

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Centralization Risk for trusted owners | 9 |
### <a name="M-1"></a>[M-1] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (9)*:
```solidity
File: contracts/protocol/ParticleInfoReader.sol

31:     function _authorizeUpgrade(address) internal override onlyOwner {}

52:     function updateParticleAddress(address particleAddr) external onlyOwner {

```

```solidity
File: contracts/protocol/ParticlePositionManager.sol

54:     function _authorizeUpgrade(address) internal override onlyOwner {}

549:     function updateDexAggregator(address dexAggregator) external override onlyOwner {

556:     function updateLiquidationRewardFactor(uint128 liquidationRewardFactor) external override onlyOwner {

563:     function updateFeeFactor(uint256 feeFactor) external override onlyOwner {

570:     function updateLoanTerm(uint256 loanTerm) external override onlyOwner {

577:     function updateTreasuryRate(uint256 treasuryRate) external override onlyOwner {

584:     function withdrawTreasury(address token, address recipient) external override onlyOwner nonReentrant {

```

