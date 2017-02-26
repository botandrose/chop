require 'chop/dsl'

describe Chop::DSL do
  subject do
    Module.new do
      extend Chop::DSL
    end
  end

  describe ".create!" do
    it "delegates to Chop::Builder.build!" do
      table, klass, block = double, double, Proc.new {}
      builder = stub_const "Chop::Builder", double
      expect(builder).to receive(:build!).with(table, klass, &block)
      subject.create! table, klass, &block
    end
  end

  describe ".diff!" do
    it "delegates to a class determined by selected element" do
      selector, table, session, block = double, double, double, Proc.new {}
      table_class = stub_const "Chop::Table", double
      expect(session).to receive(:find).with(selector).and_return(double(tag_name: "table"))
      expect(table_class).to receive(:diff!).with(selector, table, session: session, &block)
      subject.diff! selector, table, session: session, &block
    end
  end
end
