require File.dirname(__FILE__) + '/../wallet'

BitCoinAddressRexExp = /^1[#{Wallet::Base58Chars}]{33}$/
TestPath = File.dirname(__FILE__) + '/../bitcoin-wallet.cache.test'

def bg(amount)
  BigDecimal.new(amount.to_s)
end

describe Wallet do
  let(:wallet) { Wallet.new(TestPath).test_reset }
  
  context "blank slate" do
    it 'getbalance' do
      wallet.getbalance.                should == {'balance' => bg(0)}
      wallet.getbalance("some-account").should == {'balance' => bg(0)}
    end

    it 'getaddressesbyaccount' do 
      wallet.getaddressesbyaccount("").            should == []
      wallet.getaddressesbyaccount("some-account").should == []
    end

    it 'listaccounts' do
      wallet.listaccounts == [["", bg(0)]]
    end
  end
      
  context 'generating addresses for ""' do
    let!(:address) { wallet.getnewaddress }
    
    it do
      address.should =~ BitCoinAddressRexExp
    end
    
    it do
      wallet.getaddressesbyaccount("").should == [address]      
    end
    
    it do
      wallet.getaccount(address).should == ""
    end
    
    it do
      wallet.getreceivedbyaddress(address).should == bg(0)
    end
    
    it do
      a2 = wallet.getnewaddress
      a2.should_not == address
      wallet.getaddressesbyaccount("").should == [address, a2]
    end
  end

  context 'generating addresses for "savings"' do
    let!(:address) { wallet.getnewaddress("savings") }
    
    it do
      address.should =~ BitCoinAddressRexExp
    end
    
    it do
      wallet.getaddressesbyaccount("").       should == []      
      wallet.getaddressesbyaccount("savings").should == [address]      
    end
    
    it do
      wallet.getaccount(address).should == "savings"
    end
    
    it do
      wallet.getreceivedbyaddress(address).should == bg(0)
    end
    
    it do
      a2 = wallet.getnewaddress("savings")
      a2.should_not == address
      wallet.getaddressesbyaccount("savings").should == [address, a2]
    end
  end
  
  context "receiving payments" do
    let(:address) { wallet.getnewaddress }
    
    before :each do
      wallet.test_incoming_payment address, bg(7)
    end
    
    it do
      wallet.getbalance.should == {'balance' => bg(7)}

      wallet.test_incoming_payment address, bg(2)
      wallet.getbalance.should == {'balance' => bg(9)}
    end
    
    it do
      wallet.getreceivedbyaddress(address).should == bg(7)

      wallet.test_incoming_payment address, bg(2)
      wallet.getreceivedbyaddress(address).should == bg(9)
    end
  end
  
  
  context 'testing interface' do
    it 'should adjust the balance' do
      wallet.test_adjust_balance("", bg(1.5))
      wallet.getbalance.should == {'balance' => bg(1.5)}
    end
  end
    
end