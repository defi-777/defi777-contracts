pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../IUniswapV2Router01.sol";
import "../IUniswapV2Factory.sol";
import "./TestUniswapFactory.sol";

contract TestUniswapRouter is IUniswapV2Router01 {

  address constant weth = 0x0000000000000000000000000000000000000001;

  IUniswapV2Factory _factory;

  constructor() public {
    _factory = IUniswapV2Factory(new TestUniswapFactory());
  }

  receive() external payable {}

  function WETH() external override pure returns (address) {
    return weth;
  }

  function factory() external override view returns (IUniswapV2Factory) {
    return _factory;
  }


  function swapExactTokensForTokens(
      uint amountIn,
      uint /*amountOutMin*/,
      address[] calldata path,
      address to,
      uint /*deadline*/
  ) external override returns (uint[] memory /*amounts*/) {
    IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
    IERC20(path[path.length - 1]).transfer(to, amountIn);
  }

  function swapExactETHForTokens(uint /*amountOutMin*/, address[] calldata path, address to, uint /*deadline*/)
    external override
    payable
    returns (uint[] memory /*amounts*/)
  {
    IERC20(path[path.length - 1]).transfer(to, msg.value);
  }

  function swapExactTokensForETH(uint amountIn, uint /*amountOutMin*/, address[] calldata path, address to, uint /*deadline*/)
    external override
    returns (uint[] memory /*amounts*/)
  {
    IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
    payable(to).transfer(amountIn);
  }
}
