require "spec_helper"
require "chop/form"
require "cucumber"
require "slim"

module FileFieldFiles
  refine Capybara::Node::Element do
    def files
      session.evaluate_script("Array.prototype.map.call(document.getElementById('#{self["id"]}').files, function(file) { return file.name })")
    end
  end
end
using FileFieldFiles

describe Chop::Form do
  describe ".diff!" do
    let(:app) do
      Proc.new { [200, {"Content-Type" => "text/html"}, [body]] }
    end

    before do
      Capybara.app = app
      Capybara.current_session.visit("/")
    end

    describe ".diff!" do
      context "text boxes" do
        let(:body) do
          slim """
            form
              label for='a' A
              input id='a' name='a' value='1'
              label for='b' B
              input id='b' name='b' value='2'
          """
        end

        let(:form) do
          [
            ["A", "1"],
            ["B", "2"],
          ]
        end

        it "converts the selector to a table and diffs it with the supplied table" do
          described_class.diff! "form", table_from(form)
        end

        it "fails the diff when the tables are different" do
          expect {
            described_class.diff! "form", table_from([["A","2"]])
          }.to raise_exception(Cucumber::MultilineArgument::DataTable::Different)
        end

        it "doesn't fail the diff when the rows are missing from assertion" do
          expect {
            described_class.diff! "form", table_from([[]])
          }.to_not raise_exception
        end

        it "accepts a capybara element as a diff target" do
          form_element = Capybara.current_session.find("form")
          described_class.diff! form_element, table_from(form)
        end
      end

      context "multiple checkboxes" do
        let(:body) do
          slim <<~SLIM
            form
              label for="f_p" F
              input type="checkbox" value="P" name="f[]" id="f_p"
              label for="f_p" P
              input type="checkbox" value="V" name="f[]" id="f_v" checked=true
              label for="f_v" V
              input type="checkbox" value="W" name="f[]" id="f_w" checked=true
              label for="f_w" W
          SLIM
        end

        it "joins the values with a comma" do
          described_class.diff! "form", table_from([["F", "V, W"]])
        end
      end

      context "select fields" do
        before do
          Capybara.current_driver = :cuprite
          Capybara.current_session.visit("/")
        end

        after do
          Capybara.use_default_driver
        end

        let(:body) do
          slim <<~SLIM
            form
              label for="F" F
              select id="F" name="F"
                option selected=true value="v" V
          SLIM
        end

        it "it gets the selected option's text" do
          described_class.diff! "form", table_from([["F", "V"]])
        end
      end
    end
  end

  describe ".fill_in!" do
    describe "finding fields" do
      it "finds fields by id, name, placeholder, and aria-label" do
        session = test_app <<-SLIM
          input id="by-id"
          input name="by-name"
          input placeholder="by-placeholder"
          input aria-label="by-aria"
        SLIM
        described_class.fill_in! table_from([["by-id", "1"], ["by-name", "2"], ["by-placeholder", "3"], ["by-aria", "4"]])
        expect(session.all("input").map(&:value)).to eq %w[1 2 3 4]
      end

      it "prefers a direct attribute match over a label match" do
        session = test_app <<-SLIM
          label for="labelled" F
          input id="labelled"
          input name="F"
        SLIM
        described_class.fill_in! table_from([["F", "V"]])
        expect(session.find("input[name=F]").value).to eq "V"
        expect(session.find("#labelled").value).to eq ""
      end

      it "matches the start of an associated label's whitespace-normalized text" do
        session = test_app <<-SLIM
          label for="f"
            | First
            br
            |   Name (required)
          input id="f"
        SLIM
        described_class.fill_in! table_from([["First Name", "V"]])
        expect(session.find("#f").value).to eq "V"
      end

      it "finds a field wrapped in its label" do
        session = test_app <<-SLIM
          label
            | Wrapped
            input id="f"
        SLIM
        described_class.fill_in! table_from([["Wrapped", "V"]])
        expect(session.find("#f").value).to eq "V"
      end

      it "skips hidden fields" do
        session = test_app <<-SLIM
          div style="display: none"
            label for="hidden" F
            input id="hidden"
          label for="shown" F
          input id="shown"
        SLIM
        described_class.fill_in! table_from([["F", "V"]])
        expect(session.find("#shown").value).to eq "V"
      end

      it "finds hidden fields when Capybara is told not to ignore them" do
        session = test_app <<-SLIM
          div style="display: none"
            label for="hidden" F
            input id="hidden"
          label for="shown" F
          input id="shown"
        SLIM
        Capybara.ignore_hidden_elements = false
        field = described_class::FieldFinder.new(session, "input").find("F")
        expect(field[:id]).to eq "hidden"
      ensure
        Capybara.ignore_hidden_elements = true
      end

      it "stays within the current scope" do
        session = test_app <<-SLIM
          div id="outside"
            label for="a" F
            input id="a"
          div id="inside"
            label for="b" F
            input id="b"
        SLIM
        session.within("#inside") { described_class.fill_in! table_from([["F", "V"]]) }
        expect(session.find("#a").value).to eq ""
        expect(session.find("#b").value).to eq "V"
      end

      it "waits for a field that hasn't rendered yet" do
        session = test_app <<-SLIM
          div id="target"
          javascript:
            setTimeout(function() {
              document.getElementById("target").innerHTML = '<label for="f">F</label><input id="f">';
            }, 200);
        SLIM
        described_class.fill_in! table_from([["F", "V"]])
        expect(session.find("#f").value).to eq "V"
      end

      it "raises when no field matches" do
        test_app "input id='f'"
        expect {
          described_class.fill_in! table_from([["Missing", "V"]])
        }.to raise_error(Capybara::ElementNotFound, /Unable to find field "Missing"/)
      end

      it "works with drivers that can't run javascript" do
        Capybara.reset_sessions!
        Capybara.app = slim_app <<-SLIM
          label for="f" F
          input id="f"
        SLIM
        Capybara.using_driver(:rack_test) do
          session = Capybara.current_session
          session.visit("/")
          described_class.fill_in! table_from([["F", "V"]])
          expect(session.find("#f").value).to eq "V"
        end
      end

      it "doesn't make a browser round trip for each field on the page" do
        fields = (1..50).map { |i| %(label for="f#{i}" Field #{i}\ninput id="f#{i}") }
        session = test_app fields.join("\n")

        reads = 0
        allow_any_instance_of(Capybara::Cuprite::Node).to receive(:[]).and_wrap_original do |original, *args|
          reads += 1
          original.call(*args)
        end

        described_class.fill_in! table_from([["Field 50", "V"]])
        expect(session.find("#f50").value).to eq "V"
        expect(reads).to be < 20
      end

      it "still finds a field when narrowing comes up empty" do
        session = test_app <<-SLIM
          label for="f" F
          input id="f"
        SLIM
        allow_any_instance_of(described_class::FieldFinder).to receive(:narrowed_fields).and_return([])
        described_class.fill_in! table_from([["F", "V"]])
        expect(session.find("#f").value).to eq "V"
      end

      it "looks inside a shadow root when scoped to one" do
        session = test_app <<-SLIM
          div id="host"
          label for="outer" F
          input id="outer"
          javascript:
            document.getElementById("host").attachShadow({ mode: "open" }).innerHTML =
              '<label for="inner">F</label><input id="inner">';
        SLIM
        field = session.within(session.find("#host").shadow_root) do
          described_class::FieldFinder.new(session, "input").find("F")
        end
        expect(field[:id]).to eq "inner"
      end

      it "looks inside the current frame" do
        session = test_app <<-SLIM
          label for="outer" F
          input id="outer"
          iframe id="frame" srcdoc="<label for='inner'>F</label><input id='inner'>"
        SLIM
        session.within_frame("frame") do
          field = described_class::FieldFinder.new(session, "input").find("F")
          expect(field[:id]).to eq "inner"
        end
      end

      describe "custom elements" do
        def find_in template, locator
          session = test_app <<~SLIM
            javascript:
              customElements.define("x-field", class extends HTMLElement {
                get name() { return this.dataset.name }
                get placeholder() { return this.dataset.placeholder }
              })
            #{template}
          SLIM
          described_class::FieldFinder.new(session, "input, x-field").find(locator)[:id]
        end

        it "matches a name that only exists as a property" do
          expect(find_in(%(x-field id="a" data-name="F"), "F")).to eq "a"
        end

        it "reads the property rather than the attribute, as the driver does" do
          expect {
            find_in(%(x-field id="a" name="F" data-name="Q"), "F")
          }.to raise_error(Capybara::ElementNotFound)
        end

        it "keeps a property match ahead of a later attribute match" do
          expect(find_in(<<~SLIM, "F")).to eq "a"
            x-field id="a" data-name="F"
            input id="b" name="F"
          SLIM
        end

        it "keeps a property match ahead of an earlier label match" do
          expect(find_in(<<~SLIM, "F")).to eq "a"
            label for="b" F
            input id="b"
            x-field id="a" data-placeholder="F"
          SLIM
        end

        it "finds one by its label" do
          expect(find_in(<<~SLIM, "F")).to eq "a"
            label for="a" F
            x-field id="a"
          SLIM
        end
      end
    end

    describe "texty fields" do
      %w(text email search tel url password datetime).each do |type|
        it "fills in #{type} fields" do
          session = test_app <<-SLIM
            label for="f" F
            input id="f" type="#{type}"
          SLIM
          described_class.fill_in! table_from([["F", "V"]])
          expect(session.find_field("F").value).to eq "V"
        end
      end
    end

    it "fills in time fields" do
      session = test_app <<-SLIM
        label for="f" F
        input id="f" type="time"
      SLIM
      described_class.fill_in! table_from([["F", "12:33:45"]])
      expect(session.find_field("F").value).to eq "12:33:45"
    end

    it "fills in date fields" do
      session = test_app <<-SLIM
        label for="f" F
        input id="f" type="date"
      SLIM
      described_class.fill_in! table_from([["F", "2020-06-19"]])
      expect(session.find_field("F").value).to eq "2020-06-19"
    end

    it "fills in week fields" do
      session = test_app <<-SLIM
        label for="f" F
        input id="f" type="week"
      SLIM
      described_class.fill_in! table_from([["F", "2020-W06"]])
      expect(session.find_field("F").value).to eq "2020-W06"
    end

    it "fills in month fields" do
      session = test_app <<-SLIM
        label for="f" F
        input id="f" type="month"
      SLIM
      described_class.fill_in! table_from([["F", "2020-06"]])
      expect(session.find_field("F").value).to eq "2020-06"
    end

    it "fills in range fields" do
      session = test_app <<-SLIM
        label for="f" F
        input id="f" type="range" min="0" max="100"
      SLIM
      described_class.fill_in! table_from([["F", "100"]])
      expect(session.find_field("F").value).to eq "100"
    end

    it "fills in number fields" do
      session = test_app <<-SLIM
        label for="f" F
        input id="f" type="number"
      SLIM
      described_class.fill_in! table_from([["F", "50"]])
      expect(session.find_field("F").value).to eq "50"
    end

    it "fills in color fields" do
      session = test_app <<-SLIM
        label for="f" F
        input id="f" type="color"
      SLIM
      described_class.fill_in! table_from([["F", "#000000"]])
      expect(session.find_field("F").value).to eq "#000000"
    end

    it "fills in textareas" do
      session = test_app <<-SLIM
        label for="f" F
        textarea id="f"
      SLIM
      described_class.fill_in! table_from([["F", "V"]])
      expect(session.find_field("F").value).to eq "V"
    end

    it "selects select boxes" do
      session = test_app <<-SLIM
        label for="f" F
        select id="f"
          option
          option T
          option V
      SLIM
      described_class.fill_in! table_from([["F", "V"]])
      expect(session.find_field("F").value).to eq "V"
    end

    it "selects multiple select boxes delimited by comma-space" do
      session = test_app <<-SLIM
        label for="f" F
        select id="f" multiple="multiple"
          option
          option T
          option U
          option V
      SLIM
      described_class.fill_in! table_from([["F", "T, V"]])
      expect(session.find_field("F").value).to eq ["T","V"]
    end

    describe "radio buttons" do
      it "chooses a radio button" do
        session = test_app <<-SLIM
          label for="f" F
          input id="f" type="radio" name="f"
        SLIM
        described_class.fill_in! table_from([["F", "V"]])
        expect(session.find_field("F")).to be_checked
      end

      context "with non-standard labelling for groups" do
        it "chooses a radio button by value" do
          session = test_app <<-SLIM
            label for="f_p" F
            input type="radio" value="P" name="f" id="f_p"
            label for="f_p" Power
            input type="radio" value="V" name="f" id="f_v"
            label for="f_v" Value
          SLIM
          described_class.fill_in! table_from([["F", "V"]])
          expect(session.find_field("f_v")).to be_checked
        end

        it "chooses a radio button by label" do
          session = test_app <<-SLIM
            label for="f_p" F
            input type="radio" value="Power" name="f" id="f_p"
            label for="f_p" P
            input type="radio" value="Value" name="f" id="f_v"
            label for="f_v" V
          SLIM
          described_class.fill_in! table_from([["F", "V"]])
          expect(session.find_field("f_v")).to be_checked
        end

        it "favors later radio buttons if multiple match (to avoid initial label if group label matches selection label)" do
          session = test_app <<-SLIM
            label for="f_p" F?
            input type="radio" value="Power" name="f" id="f_p"
            label for="f_p" P
            input type="radio" value="Value" name="f" id="f_v"
            label for="f_v" F
          SLIM
          described_class.fill_in! table_from([["F", "F"]])
          expect(session.find_field("f_v")).to be_checked
        end
      end
    end

    describe "checkboxes" do
      it "checks a checkbox" do
        session = test_app <<-SLIM
          label for="f" F
          input id="f" type="checkbox"
        SLIM
        described_class.fill_in! table_from([["F", "V"]])
        expect(session.find_field("F")).to be_checked
      end

      it "unchecks a checkbox" do
        session = test_app <<-SLIM
          label for="f" F
          input id="f" type="checkbox"
        SLIM
        described_class.fill_in! table_from([["F", ""]])
        expect(session.find_field("F")).to_not be_checked
      end

      context "with non-standard labelling for groups" do
        it "checks a checkbox" do
          session = test_app <<-SLIM
            label for="f_p" F
            input type="checkbox" value="P" name="f[]" id="f_p"
            label for="f_p" P
            input type="checkbox" value="V" name="f[]" id="f_v"
            label for="f_v" V
          SLIM
          described_class.fill_in! table_from([["F", "V"]])
          expect(session.find_field("f_p")).to_not be_checked
          expect(session.find_field("f_v")).to be_checked
        end

        it "checks multiple checkboxes" do
          session = test_app <<-SLIM
            label for="f_p" F
            input type="checkbox" value="P" name="f[]" id="f_p"
            label for="f_p" P
            input type="checkbox" value="V" name="f[]" id="f_v"
            label for="f_v" V
            input type="checkbox" value="W" name="f[]" id="f_w"
            label for="f_w" W
          SLIM
          described_class.fill_in! table_from([["F", "V, W"]])
          expect(session.find_field("f_p")).to_not be_checked
          expect(session.find_field("f_v")).to be_checked
          expect(session.find_field("f_w")).to be_checked
        end
      end
    end

    describe "file fields" do
      before do
        Capybara.current_driver = :cuprite
      end

      after do
        Capybara.use_default_driver
      end

      context "single file field" do
        let!(:session) { test_app <<-SLIM }
          label for="f" F
          input id="f" type="file"
        SLIM

        it "attaches a file to a file field" do
          described_class.fill_in! table_from([["F", "README.md"]]), path: "./"
          expect(session.find_field("F").files).to eq ["README.md"]
        end

        it "complains when file does not exist" do
          expect {
            described_class.fill_in! table_from([["F", "DOES-NOT-EXIST"]]), path: "./"
          }.to raise_error(Errno::ENOENT)
        end

        it "complains when trying to attach multiple files" do
          expect {
            described_class.fill_in! table_from([["F", "README.md chop.gemspec"]]), path: "./"
          }.to raise_error(TypeError)
        end
      end

      context "multiple file field" do
        let!(:session) { test_app <<-SLIM }
          label for="f" F
          input id="f" type="file" multiple="multiple"
        SLIM

        it "attaches multiple files to a file field" do
          described_class.fill_in! table_from([["F", "README.md chop.gemspec"]]), path: "./"
          expect(session.find_field("F").files).to eq ["README.md", "chop.gemspec"]
        end

        it "attaches a single file to a file field" do
          described_class.fill_in! table_from([["F", "README.md"]]), path: "./"
          expect(session.find_field("F").files).to eq ["README.md"]
        end

        it "complains when a file does not exist" do
          expect {
            described_class.fill_in! table_from([["F", "README.md DOES-NOT-EXIST"]]), path: "./"
          }.to raise_error(Errno::ENOENT)
        end
      end
    end
  end 

  def table_from table
    Cucumber::MultilineArgument::DataTable.from table
  end

  def test_app template
    Capybara.reset_sessions!
    Capybara.app = slim_app(template)
    Capybara.current_driver = :cuprite
    session = Capybara.current_session
    session.visit("/")
    session
  end

  def slim_app template
    Proc.new { [200, {"Content-Type" => "text/html"}, [slim(template)]] }
  end

  def slim template
    Slim::Template.new { template }.render
  end
end

