pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../../tokens/Wrapped777.sol";
import "../uniswap/IUniswapV2Router01.sol";
import "../../Receiver.sol";

contract UniswapPoolTogether is Receiver, Ownable {
  IUniswapV2Router01 public router;
  mapping(address => address) public outputToken;

  bool private wrapping = false;


  constructor(address _router) public {
    router = IUniswapV2Router01(_router);
  }

  function addPool(Wrapped777 wrapper, address plToken) external onlyOwner {
    outputToken[address(wrapper.token())] = plToken;
    outputToken[plToken] = address(wrapper);
  }

  /**
    * Ex: Assume this is a Dai Uniswap contract
    * If Dai777 is sent to this, it will swap to ETH
    * If USDC777 is sent to this, it wall swap to Dai777
    */
  function _tokensReceived(IERC777 _token, address from, uint256 amount, bytes memory /*data*/) internal override {
    if (wrapping) {
      return;
    }

    if (outputToken[address(_token)] != address(0)) {
      Wrapped777 wrapper = Wrapped777(outputToken[address(_token)]);
      swap(address(_token), address(wrapper.token()), address(this));
      wrapAndReturn(wrapper, from);
      return;
    }

    ERC20 wrapped = Wrapped777(address(_token)).token();
    if (outputToken[address(wrapped)] != address(0)) {
      _token.send(address(_token), amount, '');
      return swap(address(wrapped), outputToken[address(wrapped)], from);
    }

    revert('Invalid token');
  }

  function swap(address input, address output, address recipient) private {
    address[] memory path = new address[](2);
    path[0] = input;
    path[1] = output;

    uint256 balance = ERC20(input).balanceOf(address(this));
    ERC20(input).approve(address(router), balance);
    router.swapExactTokensForTokens(balance, 0 /*amountOutMin*/, path, recipient, now);
  }

  function wrapAndReturn(Wrapped777 wrapper, address recipient) private {
    wrapping = true;
    ERC20 innerToken = wrapper.token();
    uint256 amount = innerToken.balanceOf(address(this));

    innerToken.approve(address(wrapper), amount);
    uint256 wrappedAmount = wrapper.wrap(amount);
    wrapper.transfer(recipient, wrappedAmount);
    wrapping = false;
  }
}