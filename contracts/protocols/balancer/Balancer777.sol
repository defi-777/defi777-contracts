pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../Receiver.sol";
import "../../tokens/WrapperFactory.sol";
import "../../tokens/IWrapped777.sol";
import "./BalancerHub.sol";

contract Balancer777 is Receiver {
  address public outputToken;
  BalancerHub private hub;

  address private wrapping;

  constructor(address _outputToken) public {
    outputToken = _outputToken;
    hub = BalancerHub(msg.sender);
  }

  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    if (address(_token) == wrapping) {
      return;
    }

    ERC20 innerInputToken = IWrapped777(address(_token)).token();
    BPool pool = hub.getBestPool(address(innerInputToken), outputToken);

    _token.send(address(_token), amount, '');

    uint _amount = innerInputToken.balanceOf(address(this));
    innerInputToken.approve(address(pool), _amount);

    (uint tokenAmountOut,) = pool.swapExactAmountIn(
      address(innerInputToken),
      _amount,
      outputToken,
      0, // minAmountOut
      ~uint(0) // maxPrice
    );

    WrapperFactory factory = WrapperFactory(IWrapped777(address(_token)).factory());
    address outputWrapper = factory.getWrapperAddress(outputToken);

    ERC20(outputToken).approve(outputWrapper, tokenAmountOut);
    wrapping = outputWrapper;
    uint outputWrapperAmount = IWrapped777(outputWrapper).wrap(tokenAmountOut);
    wrapping = address(0);

    ERC20(outputWrapper).transfer(from, outputWrapperAmount);
  }
}
