require 'pstore'
require 'bigdecimal'

class Wallet
  Base58Chars = ('a'..'z').to_a + ('A'..'Z').to_a + (0..9).to_a - %w{0 O I l}
  DefaultPath = File.dirname(__FILE__) + '/bitcoin-wallet.cache'
  
  attr_reader :db_path
  
  def initialize(db_path = DefaultPath)
    @db_path = db_path
    
    ensure_account("")
  end
  
  def getbalance(account_name = nil)
    if account_name
      t_accounts[account_name] ? t_accounts[account_name].balance : bg(0)
    else
      t_accounts.collect {|name, a| a}.inject(0) {|sum, a| sum += a.balance}
    end
  end
  
  def listaccounts
    result = {}
    t_accounts.each do |account_name, account|
      result[account_name] = account.balance
    end
    result
  end
  
  def getnewaddress(account_name = "")
    result = "1" + (1..33).collect { Base58Chars[rand(Base58Chars.length)] }.join

    ensure_account(account_name)

    address = Address.new(result, bg(0))
    t_accounts do |accounts|
      accounts[account_name].addresses[result] = address
    end
    t_addresses do |addresses|
      addresses[address.address] = account_name
    end
    result
  end
  
  def getaccount(address)
    t_addresses[address]
  end
    
  def getaddressesbyaccount(account_name)
    
    if t_accounts[account_name]
      t_accounts[account_name].addresses.collect {|raw_address, address| raw_address}
    else
      []
    end
  end
  
  def getreceivedbyaddress(address)
    account_name = t_addresses[address]
    t_accounts[account_name].addresses[address].balance
  end
  
  def move(from_name, to_name, amount)
    ensure_account(from_name)
    ensure_account(to_name)
    
    t_accounts do |accounts|
      from = accounts[from_name]
      to = accounts[to_name]
      
      from.balance -= amount
      to.balance += amount
    end
    true
  end

  def sendfrom(from_name, to_address, amount)
    to_name = t_addresses[to_address]
    fee = t_fee
    
    t_accounts do |accounts|
      from = accounts[from_name]
      to = accounts[to_name]
      
      from.balance -= (amount + fee)
      to.balance += amount
    end
  end
  
  # Simlulate methods
  
  def simulate_reset
    File.delete(db.path) if File.exists?(db.path)
    ensure_account("")
    self
  end
  
  def simulate_set_fee(fee)
    db.transaction do 
      db[:fee] = fee
    end
  end

  def simulate_adjust_balance(account_name, amount)
    ensure_account(account_name)
    
    t_accounts do |accounts|
      accounts[account_name].balance = amount
    end
  end
  
  def simulate_incoming_payment(address, amount)
    account_name = t_addresses[address]
    
    t_accounts do |accounts|
      account = accounts[account_name]
      account.balance += amount
      account.addresses[address].balance += amount
    end
  end
  
  private
  
  def bg(amount)
    BigDecimal.new(amount.to_s)
  end
  
  def ensure_account(account_name)
    db.transaction do 
      accounts = db[:accounts] || {}
      if accounts[account_name].nil?
        accounts[account_name] = Account.new(account_name, {}, bg(0))
      end
      db[:accounts] = accounts
    end
  end
  
  def t_accounts(&block)
    db.transaction do 
      accounts = db[:accounts]
      yield(accounts) if block
      db[:accounts] = accounts
      db[:accounts]
    end
  end
    
  def t_addresses(&block)
    db.transaction do 
      addresses = db[:addresses] || {}
      yield(addresses) if block
      db[:addresses] = addresses
      db[:addresses]
    end
  end
  
  def t_fee
    db.transaction do 
      db[:fee] ||= bg(0)
    end
  end
            
  def db
    @db ||= PStore.new(db_path)
  end
  
  class Account < Struct.new(:name, :addresses, :balance)
  end
  
  class Address < Struct.new(:address, :balance)
  end
end

