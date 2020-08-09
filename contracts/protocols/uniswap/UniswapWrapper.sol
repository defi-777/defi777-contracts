pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../tokens/Wrapped777.sol";
import "../../Receiver.sol";
import "./IUniswapV2Router01.sol";
import "./IUniswapWrapperFactory.sol";

contract UniswapWrapper is Receiver {
  Wrapped777 public immutable wrapper;
  IUniswapV2Router01 public immutable router;
  IUniswapV2Factory public immutable factory;

  bool private wrapping = false;

  constructor() public {
    wrapper = Wrapped777(IUniswapWrapperFactory(msg.sender).nextToken());
    IUniswapV2Router01 _router = IUniswapV2Router01(IUniswapWrapperFactory(msg.sender).uniswapRouter());
    router = _router;
    factory = _router.factory();
  }

  receive() external payable {
    // uint (reserveA, reserveB) = getReserves(router.WETH(), address(wrapper.token()));
    // uint output = getAmountOut(msg.value, reserveA, reserveB);
    address[] memory path = new address[](2);
    path[0] = router.WETH();
    path[1] = address(wrapper.token());

    router.swapExactETHForTokens{value: msg.value}(0, path, address(this), now);

    wrapAndReturn(msg.sender);
  }

  /**
    * Ex: Assume this is a Dai Uniswap contract
    * If Dai777 is sent to this, it will swap to ETH
    * If USDC777 is sent to this, it wall swap to Dai777
    */
  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    if (address(_token) == address(wrapper) && wrapping) {
      return;
    }

    // Todo: support non-wrapped 777 tokens
    Wrapped777 inputWrapper = Wrapped777(address(_token));
    ERC20 unwrappedInput = inputWrapper.token();
    ERC20 outputToken = wrapper.token();

    _token.send(address(_token), amount, "");
    uint unwrappedBalance = unwrappedInput.balanceOf(address(this));
    inputWrapper.token().approve(address(router), unwrappedBalance);

    if (address(_token) == address(wrapper)) {
      address[] memory path = new address[](2);
      path[0] = address(inputWrapper.token());
      path[1] = router.WETH();

      router.swapExactTokensForETH(unwrappedBalance, 0, path, from, now);
    } else {
      address[] memory path;

      if (factory.getPair(address(unwrappedInput), address(outputToken)) == address(0)) {
        path = new address[](3);
        path[0] = address(unwrappedInput);
        path[1] = router.WETH();
        path[2] = address(outputToken);
      } else {
        path = new address[](2);
        path[0] = address(unwrappedInput);
        path[1] = address(outputToken);
      }

      router.swapExactTokensForTokens(unwrappedBalance, 0 /*amountOutMin*/, path, address(this), now);

      wrapAndReturn(from);
    }
  }

  function wrapAndReturn(address recipient) private {
    wrapping = true;
    uint256 amount = wrapper.token().balanceOf(address(this));
    wrapper.token().approve(address(wrapper), amount);
    wrapper.wrapTo(amount, recipient);
    wrapping = false;
  }
}