import {OAppRead} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppRead.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract OAppReadDemo  is OAppRead{
    constructor(address _endpoint, address _delegate) Ownable(_delegate) OAppRead(_endpoint, _delegate){}
    
    function readAverageUniswapPrice(bytes calldata _extraOptions)
    external payable returns(MessagingReceipt memory receipt){
        bytes memory cmd = getCmd();
        return 
        _lzSend(
            READ_CHANNEL,
            cmd, 
            combineOptions(READ_CHANNEL, READ_MSG_TYPE, _extraOptions),
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
    }

    /**
     * @notice Constructs a command to query the Uniswap QuoterV2 for WETH/USDC prices on all configured chains.
     * @return cmd The encoded command to request Uniswap quotes.
    */
    function getCmd() external  view returns(bytes memory) {
        uint256 pairCount = targetEids.length;
        EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](pairCount);

        for (uint256 i = 0; i < pairCount; i++){
            uint32 targetEid = targetEids[i];
            ChainConfig memory config = chainConfigs[targetEid];

            IQuoterV2.QuoteExactInputSingleParams memory params = IQuoterV2.QuoteExactInputSingleParams({
                tokenIn: config.tokenInAdress,
                tokenOut: config.tokenOutAddress,
                amountIn: 1 ether,
                fee: config.fee,
                sqrtPriceLimitX96: 0
            });

            bytes memory callData = abi.encodeWithSelector(IQuoterV2.quoteExactInputSingle.selector, params);

            readRequests[i] = EVMCallRequestV1({
                appRequestLabel: uint16(i + 1),
                targetEid: targetEid,
                isBlockNum: false,
                blockNumOrTimestamp: uint64(block.timestamp),
                confirmations: config.confirmations,
                to: config.quoterAddress,
                callData: callData
            });
        }

        EVMCallComputeV1 memory computeSettings = EVMCallComputeV1({
            computeSetting: 2, // lzMap() and lzReduce()
            targetEid: ILayerZeroEndpointV2(endpoint).eid(),
            isBlockNum: false,
            blockNumOrTimestamp: uint64(block.timestamp),
            confirmations: 15,
            to: address(this)
        });

        return ReadCodecV1.encode(0, readRequests, computeSettings);
    }
}
