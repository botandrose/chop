require 'cucumber'
require 'chop'
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

    it "accepts a capybara element as a diff target" do
      element, table, session, block = double(tag_name: "Table"), double, double, Proc.new {}
      table_class = stub_const "Chop::Table", double
      expect(table_class).to receive(:diff!).with(element, table, session: session, &block)
      subject.diff! element, table, session: session, &block
    end

    it "accepts a 'timeout' option" do
      element, table, session, block = double(tag_name: "Table"), double, double, Proc.new {}
      table_class = stub_const "Chop::Table", double
      expect(table_class).to receive(:diff!).with(element, table, session: session, timeout: 30, &block)
      subject.diff! element, table, session: session, timeout: 30, &block
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
    subject { Chop::DSL }

    let(:table) { Cucumber::MultilineArgument::DataTable.from([[]]) }

    describe "#create!" do
      it "delegates to Chop::DSL.create" do
        klass = double
        expect(subject).to receive(:create!).with(klass, table)
        table.create!(klass)
      end
    end

    describe "#diff!" do
      it "delegates to Chop::DSL.diff!" do
        selector = "table"
        options = { as: :table }
        expect(subject).to receive(:diff!).with(selector, table, **options)
        table.diff!(selector, **options)
      end

      it "accepts a capybara element as a diff target" do
        element = double(tag_name: "Table")
        expect(subject).to receive(:diff!).with(element, table, **{})
        table.diff! element
      end

      it "assumes a 'table' selector and empty options" do
        expect(subject).to receive(:diff!).with("table", table, **{})
        table.diff!
      end

      it "accepts a 'timeout' option" do
        expect(subject).to receive(:diff!).with("table", table, timeout: 30)
        table.diff! timeout: 30
      end
    end

    describe "#fill_in!" do
      it "delegates to Chop::DSL.fill_in!" do
        expect(subject).to receive(:fill_in!).with(table)
        table.fill_in!
      end
    end
  end
end
