require 'cucumber'
require 'chop/dsl'

describe Chop::DSL do
  subject do
    Module.new do
      extend Chop::DSL
    end
  end

  describe ".create!" do
    it "delegates to Chop::Create.create!" do
      table, klass, block = double, double, Proc.new {}
      create = stub_const "Chop::Create", double
      expect(create).to receive(:create!).with(table, klass, &block)
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

  describe ".fill_in!" do
    it "delegates to Chop::Form.fill_in!" do
      table = double
      klass = stub_const("Chop::Form", double)
      expect(klass).to receive(:fill_in!).with(table)
      subject.fill_in! table
    end
  end

  describe "monkeypatched methods on Cucumber::MultilineArgument::DataTable" do
    let(:table) { Cucumber::MultilineArgument::DataTable.from([[]]) }

    describe "#create!" do
      it "delegates to Chop.create" do
        klass = double
        expect(Chop).to receive(:create!).with(klass, table)
        table.create!(klass)
      end
    end

    describe "#diff!" do
      it "delegates to Chop.diff!" do
        selector = "table"
        expect(Chop).to receive(:diff!).with(selector, table)
        table.diff!(selector)
      end

      it "assumes a 'table' selector" do
        expect(Chop).to receive(:diff!).with("table", table)
        table.diff!
      end
    end

    describe "#fill_in!" do
      it "delegates to Chop.fill_in!" do
        expect(Chop).to receive(:fill_in!).with(table)
        table.fill_in!
      end
    end
  end
end
