// SPDX-License-Identifier: MIT
import "./Ownable.sol";
pragma solidity >=0.4.22 <0.9.0;
// encoder to get items
pragma experimental ABIEncoderV2;

//pragma abicoder v2; for remix

contract Boson is Ownable {

    enum State {PENDING, FULFILLED, COMPLETE, COMPLAINED}

    // Events
    event balanceAdded(uint amount, address indexed recipient);
    event EscrowCreated(uint _id, uint _amount, address _initiator, address _receiver);
    event EscrowResolved(uint _id);
    event OrderFulfilled(uint _id);

    uint escrowBalance;

    constructor() public{
        owner = msg.sender;
        escrowBalance = 0;
    }

    // Add mapping to keep track of balances
    mapping(address => uint) balance;

    // Items
    mapping(string => Item) items;

    // Escrow Requests
    Order[] escrowRequests;

    // Mapping to get orders for buyers
    mapping(address => uint[]) buyerOrders;

    // Mapping to get orders for sellers
    mapping(address => uint[]) sellerOrders;

    // Deposit through sender
    function deposit() public payable returns (uint) {
        balance[msg.sender] += msg.value;
        emit balanceAdded(msg.value, msg.sender);
        return balance[msg.sender];
    }

    // Create new item
    function createItem(string memory name, uint price) public {
        // Create new item instance
        Item memory newItem;
        newItem.seller = msg.sender;
        newItem.price = price;
        newItem.title = name;

        // Add item to mapping
        items[name] = newItem;
    }

    // Order item
    function orderItem(string memory _name) public {
        // Check that user has enough balance to orderItem
        require(balance[msg.sender] >= items[_name].price);

        // Deduct balance from buyers account first to stop re-entrance attack
        balance[msg.sender] -= items[_name].price;

        // Update escrow balance
        escrowBalance += items[_name].price;

        // Emit event that escrow was created
        emit EscrowCreated(escrowRequests.length, items[_name].price, msg.sender, items[_name].seller);

        // Create escrow instance
        Order memory order = Order(escrowRequests.length - 1, _name, items[_name].price, msg.sender, items[_name].seller, false, State.PENDING);

        // Create and add an escrow request
        escrowRequests.push(order);

        // Push order ids to sellers and buyer to keep track of orders on front end
        buyerOrders[msg.sender].push(escrowRequests.length - 1);
        sellerOrders[items[_name].seller].push(escrowRequests.length - 1);
    }

    // Transfer funds when buyer marks order complete
    function complete(uint _id) public {
        // require that only buyer is approved to perform this action
        require(escrowRequests[_id].resolved == false);
        require(msg.sender == escrowRequests[_id].buyer);
        require(escrowRequests[_id].state == State.FULFILLED);

        // Complete escrow request
        escrowRequests[_id].state = State.COMPLETE;
        escrowRequests[_id].resolved = true;
        // Transfer funds to seller
        escrowRequests[_id].seller.transfer(escrowRequests[_id].amount);

        // Reduce escrow balance
        escrowBalance -= escrowRequests[_id].amount;

        emit EscrowResolved(_id);
    }

    // Return balance when buyer complains about order
    function complain(uint _id) public {
        // require that only buyer is approved to perform this action
        require(escrowRequests[_id].resolved == false);
        require(msg.sender == escrowRequests[_id].buyer);

        // Complain escrow request
        escrowRequests[_id].state = State.COMPLAINED;
        escrowRequests[_id].resolved = true;
        // Return balance to buyer
        balance[escrowRequests[_id].buyer] += escrowRequests[_id].amount;

        // Reduce escrow balance
        escrowBalance -= escrowRequests[_id].amount;

        emit EscrowResolved(_id);
    }

    // Return balance when buyer complains about order
    function fulfill(uint _id) public {
        // require that only seller can do this
        require(escrowRequests[_id].resolved == false);
        require(msg.sender == escrowRequests[_id].seller);
        require(escrowRequests[_id].state == State.PENDING);

        // Mark order fulfilled
        escrowRequests[_id].state = State.FULFILLED;

        emit OrderFulfilled(_id);
    }

    //-----Getters----//
    function getItem(string memory name) public view returns (Item memory){
        return items[name];
    }

    function getOrdersForBuyer() public view returns (uint[] memory){
        return buyerOrders[msg.sender];
    }

    function getOrdersForSeller() public view returns (uint[] memory){
        return sellerOrders[msg.sender];
    }

    function getOrderById(uint _id) public view returns (Order memory){
        return escrowRequests[_id];
    }

    // Functions to check balance
    function getBalance() public view returns (uint){
        return balance[msg.sender];
    }

    // Functions to check balance
    function getEscrowBalance() public view onlyOwner returns (uint){
        return escrowBalance;
    }

    // Function to check balance of any address only accessible by owner
    function getBalance(address buyer) public view onlyOwner returns (uint) {
        return balance[buyer];
    }

    // Shop items
    // Note: In production this would probably include an id as well depending on how we want to implement it on the ecommerce
    // but for simplicity we will add these items to mapping and use the name as an id
    struct Item {
        string title;
        address payable seller;
        uint price;
    }

    // Escrow
    struct Order {
        uint id;
        string item;
        uint amount;
        address buyer;
        address payable seller;
        bool resolved;
        State state;
    }
}
