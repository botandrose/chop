require "spec_helper"
require "chop/definition_list"
require "cucumber"
require "capybara"
require "puma"
require "slim"

Capybara.server = :puma, { Silent: true }

describe Chop::DefinitionList do
  let(:app) do
    Proc.new { [200, {"Content-Type" => "text/html"}, [body]] }
  end

  before do
    Capybara.reset_sessions!
    Capybara.app = app
    Capybara.use_default_driver
    Capybara.current_session.visit("/")
  end

  [false, true].each do |atomic|
    context "atomic: #{atomic}" do
      around do |example|
        Chop.atomic_diff = atomic
        example.run
      ensure
        Chop.atomic_diff = nil
      end

      describe ".diff!" do
        let(:body) do
          slim """
            dl
              dt A
              dd 1
              dt B
              dd 2
          """
        end

        let(:dl) do
          [
            ["A", "1"],
            ["B", "2"],
          ]
        end

        it "converts the selector to a table and diffs it with the supplied table" do
          described_class.diff! "dl", table_from(dl)
        end

        it "fails the diff when the tables are different" do
          expect {
            described_class.diff! "dl", table_from([[]])
          }.to raise_exception(Cucumber::MultilineArgument::DataTable::Different)
        end

        describe "block methods" do
          describe "#column" do
            it "transforms a column by index" do
              dl = [
                ["A", "2"],
                ["B", "4"],
              ]
              described_class.diff! "dl", table_from(dl) do
                column 1 do |cell|
                  cell.text.to_i * 2
                end
              end
            end

            it "doesn't yield to the block if the index is out-of-bounds" do
              dl = [
                ["A", "1"],
                ["B", "2"],
              ]
              described_class.diff! "dl", table_from(dl) do
                column 5 do |cell|
                  raise "this block should not be called"
                end
              end
            end
          end

          describe "#field" do
            it "transforms a cell by key, assuming a 'key-value' table structure" do
              dl = [
                ["A", "1"],
                ["B", "4"],
              ]
              described_class.diff! "dl", table_from(dl) do
                field :b do |cell|
                  cell.text.to_i * 2
                end
              end
            end
          end

          describe "#image" do
            let(:body) do
              slim """
                dl
                  dt A
                  dd: img src='/path/to/1.jpg?123456'
                  dt B
                  dd: img src='http://example.com/path/2-3a679bd0da8d45d2bf257420f948e1fe1b981b0d8cbac67d9992f22d61d5767e.jpg'
              """
            end

            let(:dl) do
              [
                ["A","1.jpg"],
                ["B","2.jpg"],
              ]
            end

            it "replaces the cell with the image's filename, normalized, by key" do
              described_class.diff! "dl", table_from(dl) do
                image :a, :b
              end
            end

            it "replaces the cell with the image's filename, normalized, by column index" do
              described_class.diff! "dl", table_from(dl) do
                image 1
              end
            end
          end
        end
      end
    end
  end

  def table_from table
    Cucumber::MultilineArgument::DataTable.from table
  end

  def slim template
    Slim::Template.new { template }.render
  end
end
