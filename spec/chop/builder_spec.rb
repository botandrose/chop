require "chop/builder"

describe Chop::Builder do
  describe ".build!" do
    it "delegates to new(*args).build!" do
      table, klass, block = double, double, Proc.new {}
      builder = double
      expect(described_class).to receive(:new).with(table, klass, block).and_return(builder)
      expect(builder).to receive(:build!)
      described_class.build! table, klass, &block
    end
  end

  let(:table) { double(hashes: [{"a" => 1}, {"a" => 2}]) }

  let(:klass) { double }


  describe "#build!" do
    subject { described_class.new(table, klass) }

    it "creates a record for each row in the table" do
      expect(klass).to receive(:create!).with("a" => 1)
      expect(klass).to receive(:create!).with("a" => 2)
      subject.build!
    end

    it "returns an array of created records" do
      record_1, record_2 = double, double
      allow(klass).to receive(:create!).and_return(record_1, record_2)
      expect(subject.build!).to eq [record_1, record_2]
    end
  end

  describe "block methods" do
    let(:klass) do
      Class.new do
        def self.create! attributes
          attributes
        end
      end
    end

    describe "#transformation" do
      it "adds a transformation to the build pipeline" do
        records = described_class.build! table, klass do
          transformation do |attributes|
            attributes["a"] *= 2
          end
        end
        expect(records).to eq [{"a" => 2}, {"a" => 4}]
      end
    end

    describe "#field" do
      it "adds a transformation to the build pipeline scoped to one field" do
        records = described_class.build! table, klass do
          field(:a) { |a| a * 2 }
        end
        expect(records).to eq [{"a" => 2}, {"a" => 4}]
      end
    end

    describe "#underscore_keys" do
      let(:table) { double(hashes: [{"First Name" => "Micah"}, {"Last Name" => "Geisel"}]) }

      it "adds a transformation to the build pipeline scoped to one field" do
        records = described_class.build! table, klass do
          underscore_keys
        end
        expect(records).to eq [{"first_name" => "Micah"}, {"last_name" => "Geisel"}]
      end
    end

    describe "#file" do
      let(:table) { double(hashes: [{"image" => "example.jpg"}]) }

      it "treats the column as a file path and transforms it into the opened file" do
        file = double
        expect(File).to receive(:open).with("features/support/fixtures/example.jpg").and_return(file)
        records = described_class.build! table, klass do
          file(:image)
        end
        expect(records).to eq [{"image" => file}]
      end
    end

    describe "#files" do
      let(:table) { double(hashes: [{"images" => "example.jpg example.png"}]) }

      it "treats the column as a list of file paths and transforms it into an array of opened files" do
        file_1, file_2 = double, double
        expect(File).to receive(:open).with("features/support/fixtures/example.jpg").and_return(file_1)
        expect(File).to receive(:open).with("features/support/fixtures/example.png").and_return(file_2)
        records = described_class.build! table, klass do
          files(:images)
        end
        expect(records).to eq [{"images" => [file_1, file_2]}]
      end
    end

    describe "#has_one/#belongs_to" do
      let(:table) { double(hashes: [{"user" => "Micah Geisel"}]) }

      it "treats the column as the name of a record of the specified class, and transforms it into that record" do
        user_class, micah = double, double
        allow(user_class).to receive(:find_by!).with(name: "Micah Geisel").and_return(micah)
        stub_const("User", user_class)
        records = described_class.build! table, klass do
          has_one(:user, User)
        end
        expect(records).to eq [{"user" => micah}]
      end
    end

    describe "#has_many" do
      let(:table) { double(hashes: [{"users" => "Micah Geisel, Michael Gubitosa"}]) }

      it "treats the column as a list of names of records of the specified class, and transforms it into those records" do
        user_class, micah, michael = double, double, double
        allow(user_class).to receive(:find_by!).with(name: "Micah Geisel").and_return(micah)
        allow(user_class).to receive(:find_by!).with(name: "Michael Gubitosa").and_return(michael)
        stub_const("User", user_class)
        records = described_class.build! table, klass do
          has_many(:users, User)
        end
        expect(records).to eq [{"users" => [micah, michael]}]
      end
    end
  end
end
