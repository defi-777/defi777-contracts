pragma solidity >=0.6.2 <0.7.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "./Balancer777.sol";
import "./interfaces/BFactory.sol";
import "./interfaces/BPool.sol";


contract BalancerHub {
  using Address for address;

  BFactory public factory;

  mapping(address => mapping(address => BPool[])) public swapPools;
  mapping(address => bool) private poolAdded;

  constructor(BFactory _factory) public {
    factory = _factory;
  }

  function addPool(BPool pool) external {
    require(!poolAdded[address(pool)], 'Already added');
    require(factory.isBPool(address(pool)), 'Not a pool');

    address[] memory tokens = pool.getCurrentTokens();

    for (uint i = 0; i < tokens.length; i++) {
      for (uint j = i + 1; j < tokens.length; j++) {
        swapPools[tokens[i]][tokens[j]].push(pool);
        swapPools[tokens[j]][tokens[i]].push(pool);
      }
      getAddress(tokens[i]);
    }

    poolAdded[address(pool)] = true;
  }

  function getBestPool(address _in, address _out) external view returns (BPool bestPool) {
    BPool[] memory pools = swapPools[_in][_out];


    uint bestPrice = ~uint(0);
    for (uint i = 0; i < pools.length; i++) {
      uint price = pools[i].getSpotPrice(_in, _out);
      if (price < bestPrice) {
        bestPool = pools[i];
        bestPrice = price;
      }
    }
    require(address(bestPool) != address(0), 'No matching pools');
  }

  function create(address outputToken) public {    
    new Balancer777{salt: bytes32(0)}(outputToken);
  }

  function calculateAddress(address outputToken) public view returns (address calculatedAddress) { 
    calculatedAddress = address(uint(keccak256(abi.encodePacked(
      byte(0xff),
      address(this),
      bytes32(0),
      keccak256(abi.encodePacked(
        type(Balancer777).creationCode,
        uint256(outputToken)
      ))
    ))));
  }

  function getAddress(address outputToken) public returns (address wrapperAddress) {
    wrapperAddress = calculateAddress(outputToken);

    if(!wrapperAddress.isContract()) {
      create(outputToken);
      assert(wrapperAddress.isContract());
    }
  }
}
