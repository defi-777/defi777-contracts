pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../tokens/Wrapped777.sol";
import "../../Receiver.sol";
import "./IUniswapV2Router01.sol";
import "./IUniswapWrapperFactory.sol";

contract UniswapWrapper is Receiver {
  Wrapped777 public immutable wrapper;
  IUniswapV2Router01 public immutable router;
  IUniswapV2Factory public immutable uniswapFactory;
  address private immutable weth;

  uint256 private constant INFINITY = uint256(-1);

  constructor() public {
    IUniswapWrapperFactory factory = IUniswapWrapperFactory(msg.sender);
    Wrapped777 _wrapper = Wrapped777(factory.nextToken());
    wrapper = _wrapper;
    IUniswapV2Router01 _router = IUniswapV2Router01(factory.uniswapRouter());
    weth = _router.WETH();
    router = _router;
    uniswapFactory = _router.factory();
    infiniteApprove(_wrapper.token(), address(_wrapper), 1);
  }

  receive() external payable {
    // uint (reserveA, reserveB) = getReserves(router.WETH(), address(wrapper.token()));
    // uint output = getAmountOut(msg.value, reserveA, reserveB);
    address[] memory path = new address[](2);
    path[0] = router.WETH();
    path[1] = address(wrapper.token());

    uint256[] memory outputs = router.swapExactETHForTokens{value: msg.value}(0, path, address(this), now);

    wrapAndReturn(msg.sender, outputs[1]);
  }

  /**
    * Ex: Assume this is a Dai Uniswap contract
    * If Dai777 is sent to this, it will swap to ETH
    * If USDC777 is sent to this, it wall swap to Dai777
    */
  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    // Todo: support non-wrapped 777 tokens
    Wrapped777 inputWrapper = Wrapped777(address(_token));
    ERC20 unwrappedInput = inputWrapper.token();
    ERC20 outputToken = wrapper.token();

    uint unwrappedBalance = inputWrapper.unwrap(amount);
    infiniteApprove(unwrappedInput, address(router), unwrappedBalance);

    if (address(_token) == address(wrapper)) {
      address[] memory path = new address[](2);
      path[0] = address(inputWrapper.token());
      path[1] = weth;

      router.swapExactTokensForETH(unwrappedBalance, 0, path, from, now);
    } else {
      address[] memory path;

      if (uniswapFactory.getPair(address(unwrappedInput), address(outputToken)) == address(0)) {
        path = new address[](3);
        path[0] = address(unwrappedInput);
        path[1] = weth;
        path[2] = address(outputToken);
      } else {
        path = new address[](2);
        path[0] = address(unwrappedInput);
        path[1] = address(outputToken);
      }

      uint256[] memory outputs = router.swapExactTokensForTokens(unwrappedBalance, 0 /*amountOutMin*/, path, address(this), now);

      wrapAndReturn(from, outputs[path.length - 1]);
    }
  }

  function wrapAndReturn(address recipient, uint256 amount) private {
    infiniteApprove(wrapper.token(), address(wrapper), amount);
    wrapper.wrapTo(amount, recipient);
  }

  function infiniteApprove(ERC20 token, address spender, uint256 amount) private {
    if (token.allowance(address(this), spender) < amount) {
      token.approve(spender, INFINITY);
    }
  }
}
