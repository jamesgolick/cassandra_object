require 'test_helper'

class BasicScenariosTest < CassandraObjectTestCase
  def setup
    super
    @customer = Customer.create :first_name    => "Michael",
                                :last_name     => "Koziarski",
                                :date_of_birth => "1980/08/15"
    @customer_key = @customer.key.to_s                          
    
    assert @customer.valid?
  end
  
  test "get on a non-existent key returns nil" do
    assert_nil Customer.get("THIS IS NOT A KEY")
  end

  test "a new object can be retrieved by key" do
    other_customer = Customer.get(@customer_key)
    assert_equal @customer, other_customer
    
    assert_equal "Michael", other_customer.first_name
    assert_equal "Koziarski", other_customer.last_name
    assert_equal Date.parse("1980-08-15"), other_customer.date_of_birth
  end
  
  test "date_of_birth is a date" do
    assert @customer.date_of_birth.is_a?(Date)
  end
  
  test "should not let you assign junk to a date column" do
    assert_raise(TypeError) do
      @customer.date_of_birth=24.5
    end
  end
  
  test "should return nil for attributes without a value" do
    assert_nil @customer.preferences
  end
  
  test "should let a user set a Hash valued attribute" do
    val = {"a"=>"b"}
    @customer.preferences = val
    assert_equal val, @customer.preferences
    @customer.save
    
    other_customer = Customer.get(@customer_key)
    assert_equal val, other_customer.preferences
  end

  test "should validate strings passed to a typed column" do
    @customer.date_of_birth = "35345908"
    assert !@customer.valid?
    assert @customer.errors[:date_of_birth]
  end
  
  test "should have a schema version of 0" do
    assert_equal 0, @customer.schema_version
  end

  test "multiget" do
    custs = Customer.multi_get([@customer_key, "This is not a key either"])
    customer, nothing = custs.values

    assert_equal @customer, customer
    assert_nil nothing
  end

  test "creating a new record starts with the right version" do
    @invoice  = mock_invoice

    raw_result = Invoice.connection.get("Invoices", @invoice.key.to_s)
    assert_equal Invoice.current_schema_version, ActiveSupport::JSON.decode(raw_result["schema_version"])
  end
  
  test "to_param works" do
    invoice = mock_invoice
    param = invoice.to_param
    assert_match /[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}/, param
    assert_equal invoice.key, Invoice.parse_key(param)
  end
  
  context "destroying a customer with invoices" do
    setup do
      @invoice = mock_invoice
      @customer.invoices << @invoice
      
      @customer.destroy
    end
    
    should "Have removed the customer" do
      assert Customer.connection.get("Customers", @customer.key.to_s).empty?
    end
    
    should "Have removed the associations too" do
      assert_equal Hash.new, Customer.connection.get("CustomerRelationships", @customer.key.to_s)
    end
  end

  context "An object with a natural key" do
    setup do
      @payment = Payment.new :reference_number => "12345",
                             :amount           => 1001
      @payment.save!
    end

    should "create a natural key based on that attr" do
      assert_equal "12345", @payment.key.to_s
    end

    should "have a key equal to another object with that key" do
      p = Payment.new(:reference_number => "12345",
                      :amount           => 1001)
      p.save

      assert_equal @payment.key, p.key
    end
  end
end
