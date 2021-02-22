const Boson = artifacts.require('Boson');
const truffleAssert = require('truffle-assertions')

contract('Boson', async (accounts) => {

    let boson;

    before(async () => {
        boson = await Boson.deployed();
    })

    // Balance updates on deposit
    it('should update balance correctly on deposit', async () => {
        await boson.deposit({from: accounts[2], value: web3.utils.toWei('10', 'ether')});
        assert(await boson.getBalance({from: accounts[2]}) == web3.utils.toWei('10', 'ether'));
    });

    // Item is added correctly
    it('should add item correctly', async () => {
        await truffleAssert.passes(await boson.createItem('Coffee', web3.utils.toWei('3', 'ether'), {from: accounts[1]}));
        let coffee = await boson.getItem('Coffee');
        assert(coffee.title === 'Coffee');
        assert(coffee.seller === accounts[1]);
    });

    // Order is created successfully
    it('should create order successfully', async () => {
        await truffleAssert.passes(await boson.orderItem('Coffee', {from: accounts[2]}));
        let order = await boson.getOrderById(0);
        assert(order.buyer === accounts[2]);
    });

    // Balance is changed after placing an order
    it('should update balance on order', async () => {
        assert(await boson.getBalance({from: accounts[2]}) == web3.utils.toWei('7', 'ether'));
    });

    // Balance is added in escrow on order
    it('should update balance in escrow', async () => {
        assert(await boson.getEscrowBalance() == web3.utils.toWei('3', 'ether'));
    });

    // Only seller can fulfill order
    it('should only let seller fulfil order', async () => {
        await truffleAssert.fails(boson.fulfill(0, {from: accounts[4]}),
            truffleAssert.ErrorType.REVERT);
        await truffleAssert.passes(await boson.fulfill(0, {from: accounts[1]}));
    });

    // Only buyer can complete an order
    it('should only let buyer complete the order', async () => {
        await truffleAssert.fails(boson.complete(0, {from: accounts[4]}),
            truffleAssert.ErrorType.REVERT);
        await truffleAssert.passes(await boson.complete(0, {from: accounts[2]}));
    });

    // Seller is credited on complete
    it('should credit seller on complete', async () => {
        let balance = await web3.eth.getBalance(accounts[1]);
        assert(balance > web3.utils.toWei('100', 'ether'), 'Contract balance was not 0 after withdrawal or did not match');
    });

    // only buyer can complain
    it('should only let buyer complain and revert balance', async () => {
        await boson.deposit({from: accounts[3], value: web3.utils.toWei('10', 'ether')});
        await boson.orderItem('Coffee', {from: accounts[3]});
        assert(await boson.getBalance({from: accounts[3]}) == web3.utils.toWei('7', 'ether'));
        await truffleAssert.fails(boson.complain(1, {from: accounts[4]}),
            truffleAssert.ErrorType.REVERT);
        await truffleAssert.passes(await boson.complain(1, {from: accounts[3]}));
        assert(await boson.getBalance({from: accounts[3]}) == web3.utils.toWei('10', 'ether'));
    });

    // Order fails to be completed if not fulfilled
    it('should not complete order if it is not fulfilled', async () => {
        await boson.orderItem('Coffee', {from: accounts[3]});
        await truffleAssert.fails(boson.complete(2, {from: accounts[3]}),
            truffleAssert.ErrorType.REVERT);
    });

    // Buyer cannot place an order if balance is lower
    it('should not create order if balance is not sufficient', async () => {
        await truffleAssert.fails(boson.orderItem('Coffee', {from: accounts[4]}),
            truffleAssert.ErrorType.REVERT);
    });

});