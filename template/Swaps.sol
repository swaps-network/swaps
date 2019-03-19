pragma solidity ^0.5.6;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

// todo: checkable
contract Swaps is Ownable {
    using SafeMath for uint;

    bool public isSwapped;
    bool public isCancelled;

    address public baseAddress;
    address public quoteAddress;

    uint public expirationTimestamp;

    mapping(address => uint) private limits;
    mapping(address => uint) private raised;
    mapping(address => address[]) private investors;
    mapping(address => mapping(address => uint)) private investments;

    event Cancel();
    event Deposit(address indexed token, address indexed user, uint amount, uint balance);
    event Refund(address indexed token, address indexed user, uint amount, uint balance);

    constructor() public {
        require(D_BASE_ADDRESS != D_QUOTE_ADDRESS, "Exchanged tokens must be different");
        require(D_BASE_LIMIT > 0, "Base limit must be positive");
        require(D_QUOTE_LIMIT > 0, "Quote limit must be positive");
        require(D_EXPIRATION_TS > now, "Expiration time must be in future");

        baseAddress = D_BASE_ADDRESS;
        quoteAddress = D_QUOTE_ADDRESS;
        limits[baseAddress] = D_BASE_LIMIT;
        limits[quoteAddress] = D_QUOTE_LIMIT;

        expirationTimestamp = D_EXPIRATION_TS;
        _transferOwnership(D_OWNER);
    }

    function () external payable {
        this.deposit();
    }

    modifier onlyInvestor() {
        require(_isInvestor(msg.sender), "Allowed only for investors");
        _;
    }

    function deposit() external payable {
        _deposit(address(0), msg.sender, msg.value);
    }

    // todo: check reentrancy
    function depositTokens(address _token) public {
        address from = msg.sender;
        uint allowance = IERC20(_token).allowance(from, address(this));
        IERC20(_token).transferFrom(from, address(this), allowance);
        _deposit(_token, from, allowance);
    }

    function swap() public {
        // todo
    }

    function cancel() public onlyOwner {
        // todo
    }

    // todo: check reentrancy
    function refund() public onlyInvestor {
        uint userInvestments;
        address[2] memory tokens = [baseAddress, quoteAddress];
        for (uint t = 0; t < tokens.length; t++) {
            address token = tokens[t];
            uint investment = _removeInvestment(investments[token], msg.sender);
            _removeInvestor(investors[token], msg.sender);

            if (investment > 0) {
                raised[token] = raised[token].sub(investment);
                userInvestments = userInvestments.add(investment);
            }
        }
    }

    function _removeInvestment(
        mapping(address => uint) storage _investments,
        address _investor
    ) internal returns (uint _investment) {
        _investment = _investments[_investor];
        if (_investment > 0) {
            delete _investments[_investor];
        }
    }

    function _removeInvestor(address[] storage _array, address _investor) internal {
        uint idx = _array.length - 1;
        for (uint i = 0; i < _array.length - 1; i++) {
            if (_array[i] == _investor) {
                idx = i;
                break;
            }
        }

        _array[idx] = _array[_array.length - 1];
        delete _array[_array.length - 1];
        _array.length--;
    }

    // todo: withdraw accidentally sent tokens

    function _deposit(address _token, address _from, uint _amount) internal {
        require(baseAddress == _token || quoteAddress == _token, "You can deposit only base or quote currency");
        require(_amount > 0, "Currency amount must be positive");

        if (!_isInvestor(_from)) {
            investors[_token].push(_from);
        }

        investments[_token][_from] = investments[_token][_from].add(_amount);

        raised[_token] = raised[_token].add(_amount);
        require(raised[_token] <= limits[_token], "Raised should not be more than limit");

        // todo: execute swap by last transaction
    }

    function _isInvestor(address _who) internal view returns (bool) {
        if (investments[baseAddress][_who] > 0) {
            return true;
        }

        if (investments[quoteAddress][_who] > 0) {
            return true;
        }

        return false;
    }
}