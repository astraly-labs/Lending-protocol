use starknet::ContractAddress;
use Lendingprotocol::contracts::lending::{
    ILendingProtocolABIDispatcherTrait, ILendingProtocolABIDispatcher, LendingProtocol
};
use Lendingprotocol::interfaces::Pragma::{PragmaOracleDispatcher, PragmaOracleDispatcherTrait, };
use Lendingprotocol::contracts::erc20::{erc_20, IERC20Dispatcher, IERC20DispatcherTrait};
use array::ArrayTrait;
use starknet::contract_address_const;
use serde::Serde;
use debug::PrintTrait;
use starknet::syscalls::deploy_syscall;
use starknet::testing::{
    set_caller_address, set_contract_address, set_block_timestamp, set_chain_id
};
use starknet::info;
use starknet::SyscallResultTrait;
use traits::TryInto;
use result::ResultTrait;
use option::OptionTrait;
const CHAIN_ID: felt252 = 'SN_GOERLI';
const ASSET_ID: felt252 = 'BTC/USD';
fn setup() -> (ILendingProtocolABIDispatcher, IERC20Dispatcher, IERC20Dispatcher) {
    let admin =
        contract_address_const::<0x0092cC9b7756E6667b654C0B16d9695347AF788EFBC00a286efE82a6E46Bce4b>();
    set_contract_address(admin);
    set_chain_id(CHAIN_ID);

    //token 1
    let mut token_1_calldata = ArrayTrait::new();
    let token_1: felt252 = 'Pragma1';
    let symbol_1: felt252 = 'PRA1';
    let decimal: u8 = 8;
    let initial_supply: u256 = u256 { low: 1000000000000, high: 100000000000 };
    token_1.serialize(ref token_1_calldata);
    symbol_1.serialize(ref token_1_calldata);
    decimal.serialize(ref token_1_calldata);
    initial_supply.serialize(ref token_1_calldata);
    admin.serialize(ref token_1_calldata);
    let (token_1_address, _) = deploy_syscall(
        erc_20::TEST_CLASS_HASH.try_into().unwrap(), 0, token_1_calldata.span(), true
    )
        .unwrap_syscall();
    let mut token_1 = IERC20Dispatcher { contract_address: token_1_address };

    //token 2
    let mut token_2_calldata = ArrayTrait::new();
    let token_2: felt252 = 'Pragma2';
    let symbol_2: felt252 = 'PRA2';
    token_2.serialize(ref token_2_calldata);
    symbol_2.serialize(ref token_2_calldata);
    decimal.serialize(ref token_2_calldata);
    initial_supply.serialize(ref token_2_calldata);
    admin.serialize(ref token_2_calldata);
    let (token_2_address, _) = deploy_syscall(
        erc_20::TEST_CLASS_HASH.try_into().unwrap(), 0, token_2_calldata.span(), true
    )
        .unwrap_syscall();
    let mut token_2 = IERC20Dispatcher { contract_address: token_2_address };
    let mut constructor_calldata = ArrayTrait::new();
    let borrow_address: ContractAddress = token_1_address;
    let collateral_address: ContractAddress = token_2_address;
    borrow_address.serialize(ref constructor_calldata);
    collateral_address.serialize(ref constructor_calldata);
    let (lending_protocol_address, _) = deploy_syscall(
        LendingProtocol::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_calldata.span(), true
    )
        .unwrap_syscall();
    let mut lending_protocol = ILendingProtocolABIDispatcher {
        contract_address: lending_protocol_address
    };
    token_1.approve(lending_protocol_address, initial_supply);
    token_1.transfer(lending_protocol_address, initial_supply / 10); //INTIAL WORKING ENTRY

    token_2.approve(lending_protocol_address, initial_supply);
    token_2.transfer(lending_protocol_address, initial_supply / 10); //INIITAL WORKING ENTRY
    return (lending_protocol, token_1, token_2);
}

#[test]
#[available_gas(1000000000)]
fn test_lending_deploy() {
    let admin =
        contract_address_const::<0x0092cC9b7756E6667b654C0B16d9695347AF788EFBC00a286efE82a6E46Bce4b>();
    let (lending_protocol, token_1, token_2) = setup();
    set_contract_address(admin);
    lending_protocol.deposit(1000000000000); 
    token_2.balance_of(admin);
    let user = lending_protocol.get_user_balance(admin);
    assert(user.deposited == 1000000000000, 'wrong deposited value');
    assert(lending_protocol.get_total_liquidity() == 1000000000000, 'wrong total liquidity');
    assert(lending_protocol.get_total_borrowed() == 0, 'wrong total borrowed');
    lending_protocol.borrow(80000000000);
    assert(lending_protocol.get_user_balance(admin).borrowed == 80000000000, 'wrong borrowed value');
    lending_protocol.withdraw(20000000000);
    assert(lending_protocol.get_user_balance(admin).deposited==1000000000000-20000000000, 'wrong withdrawed value');
    lending_protocol.repay(60000000000);
    assert(lending_protocol.get_user_balance(admin).borrowed == 80000000000-60000000000, 'wrong repay value');
    lending_protocol.borrow(650000000000);
    lending_protocol.liquidate(admin);
    assert(lending_protocol.get_total_borrowed() == 0, 'liquidation failed');
    assert(lending_protocol.get_total_liquidity() == 1000000000000, 'wrong liquidity:liquidate');
    assert(lending_protocol.get_user_balance(admin).borrowed == 0, 'wrong user balance');
    assert(lending_protocol.get_user_balance(admin).deposited == 0, 'wrong user balance');
    return ();
}
