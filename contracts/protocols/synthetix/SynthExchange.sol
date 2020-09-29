pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../tokens/Wrapped777.sol";
import "../uniswap/interfaces/IUniswapV2Router01.sol";
import "./interfaces/ISynthetix.sol";
import "../../Receiver.sol";
import "./ISynthExchangeFactory.sol";

contract SynthExchange is Receiver {
  Wrapped777 public immutable outputWrapper;
  IUniswapV2Router01 public immutable router;
  ISynthetix public immutable snx;
  bytes32 public immutable outputKey;

  bytes32 constant private SUSD = 0x7355534400000000000000000000000000000000000000000000000000000000;
  bytes32 constant private SETH = 0x7345544800000000000000000000000000000000000000000000000000000000;

  bool private wrapping = false;

  constructor() public {
    Wrapped777 _outputWrapper = Wrapped777(ISynthExchangeFactory(msg.sender).nextWrapper());
    outputWrapper = _outputWrapper;
    ISynthetix _snx = ISynthetix(ISynthExchangeFactory(msg.sender).snx());
    snx = _snx;
    router = IUniswapV2Router01(ISynthExchangeFactory(msg.sender).uniswapRouter());
    outputKey = _snx.synthsByAddress(address(_outputWrapper.token()));
  }

  receive() external payable {
    address[] memory path = new address[](2);
    path[0] = router.WETH();
    path[1] = address(snx.synths(SETH));

    uint256[] memory outputs = router.swapExactETHForTokens{value: msg.value}(0, path, address(this), now);

    uint256 outputAmount;
    if (outputKey == SETH) {
      outputAmount = outputs[2];
    } else {
      outputAmount = synthExchange(SETH);
    }

    wrapAndReturn(msg.sender, outputAmount);
  }

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    if (address(_token) == address(outputWrapper) && wrapping) {
      return;
    }

    Wrapped777 _wrapper = Wrapped777(address(_token));
    _token.send(address(_token), amount, "");

    ERC20 unwrappedToken = _wrapper.token();
    uint256 outputAmount;

    bytes32 inputKey = snx.synthsByAddress(address(unwrappedToken));
    if (inputKey == bytes32(0)) {
      outputAmount = swapToSUSD(unwrappedToken);
      inputKey = SUSD;
    }

    if (inputKey != outputKey) {
      outputAmount = synthExchange(inputKey);
    }

    wrapAndReturn(from, outputAmount);
  }

  function synthExchange(bytes32 inputKey) private returns (uint256) {
    ERC20 inputToken = ERC20(address(snx.synths(inputKey)));
    uint256 amount = inputToken.balanceOf(address(this));
    return snx.exchange(inputKey, amount, outputKey);
  }

  function swapToSUSD(ERC20 token) private returns (uint256) {
    uint unwrappedBalance = token.balanceOf(address(this));
    token.approve(address(router), unwrappedBalance);

    address[] memory path = new address[](3);
    path[0] = address(token);
    path[1] = router.WETH();
    path[2] = address(snx.synths(SUSD));

    uint256[] memory outputs = router.swapExactTokensForTokens(unwrappedBalance, 0 /*amountOutMin*/, path, address(this), now);

    return outputs[3];
  }

  function wrapAndReturn(address recipient, uint256 amount) private {
    wrapping = true;
    outputWrapper.token().approve(address(outputWrapper), amount);
    outputWrapper.wrapTo(amount, recipient);
    wrapping = false;
  }
}
