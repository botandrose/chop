require "spec_helper"
require "chop/create"

describe Chop::Create do
  describe ".create!" do
    it "delegates to new(*args).create!" do
      klass, table, block = double, double, Proc.new {}
      create = double
      expect(described_class).to receive(:new).with(klass, table, block).and_return(create)
      expect(create).to receive(:create!)
      described_class.create! klass, table, &block
    end
  end

  let(:table) { double(hashes: [{"a" => 1}, {"a" => 2}]) }

  let(:klass) { double }


  describe "#create!" do
    it "creates a record for each row in the table" do
      expect(klass).to receive(:create!).with("a" => 1)
      expect(klass).to receive(:create!).with("a" => 2)
      described_class.new(klass, table).create!
    end

    it "returns an array of created records" do
      record_1, record_2 = double, double
      allow(klass).to receive(:create!).and_return(record_1, record_2)
      records = described_class.new(klass, table).create!
      expect(records).to eq [record_1, record_2]
    end

    it "supports integration with FactoryGirl" do
      factory_girl = double
      stub_const("FactoryGirl", factory_girl)
      allow(factory_girl).to receive(:create).with("factory_name", "a" => 1)
      allow(factory_girl).to receive(:create).with("factory_name", "a" => 2)
      described_class.new({ factory_girl: "factory_name" }, table).create!
    end

    it "optionally can accept a table as an argument" do
      expect(klass).to receive(:create!).with("a" => 1)
      expect(klass).to receive(:create!).with("a" => 2)
      described_class.new(klass).create! table
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
      it "adds a transformation to the create pipeline" do
        records = described_class.create! klass, table do
          transformation do |attributes|
            attributes["a"] *= 2
            attributes
          end
        end
        expect(records).to eq [{"a" => 2}, {"a" => 4}]
      end
    end

    describe "#rename" do
      it "renames fields by hash map" do
        records = described_class.create! klass, table do
          rename :a => :b
        end
        expect(records).to eq [{"b" => 1}, {"b" => 2}]
      end
    end

    describe "#field" do
      it "adds a transformation to the create pipeline scoped to one field" do
        records = described_class.create! klass, table do
          field(:a) { |a| a * 2 }
        end
        expect(records).to eq [{"a" => 2}, {"a" => 4}]
      end

      it "supports syntactic sugar for renaming on the fly" do
        records = described_class.create! klass, table do
          field(:a => :b) { |a| a * 2 }
        end
        expect(records).to eq [{"b" => 2}, {"b" => 4}]
      end
    end

    describe "#delete" do
      it "removes specified keys from the attributes hash" do
        records = described_class.create! klass, table do
          delete :a
        end
        expect(records).to eq [{}, {}]
      end
    end

    describe "#underscore_keys" do
      let(:table) { double(hashes: [{"First Name" => "Micah"}, {"Last Name" => "Geisel"}]) }

      it "adds a transformation to the create pipeline scoped to one field" do
        records = described_class.create! klass, table do
          underscore_keys
        end
        expect(records).to eq [{"first_name" => "Micah"}, {"last_name" => "Geisel"}]
      end
    end

    describe "#file" do
      it "treats the column as a file path and transforms it into the opened file" do
        file = double
        expect(File).to receive(:open).with("features/support/fixtures/example.jpg").and_return(file)
        table = double(hashes: [{"image" => "example.jpg"}])
        records = described_class.create! klass, table do
          file(:image)
        end
        expect(records).to eq [{"image" => file}]
      end

      it "treats an empty value as nil" do
        table = double(hashes: [{"image" => ""}])
        records = described_class.create! klass, table do
          file(:image)
        end
        expect(records).to eq [{"image" => nil}]
      end

      it "allows configuration of the path" do
        file = double
        expect(File).to receive(:open).with("tmp/example.jpg").and_return(file)
        table = double(hashes: [{"image" => "example.jpg"}])
        records = described_class.create! klass, table do
          file(:image, path: "tmp")
        end
        expect(records).to eq [{"image" => file}]
      end

      it "supports syntactic sugar for renaming on the fly" do
        image, icon = double, double
        expect(File).to receive(:open).with("features/support/fixtures/image.jpg").and_return(image)
        expect(File).to receive(:open).with("features/support/fixtures/icon.jpg").and_return(icon)
        table = double(hashes: [{"image" => "image.jpg", "icon" => "icon.jpg"}])
        records = described_class.create! klass, table do
          file(:image => :image_file, :icon => :icon_file)
        end
        expect(records).to eq [{"image_file" => image, "icon_file" => icon}]
      end

      it "allows configuration of the path with renaming syntax" do
        file = double
        expect(File).to receive(:open).with("tmp/example.jpg").and_return(file)
        table = double(hashes: [{"image" => "example.jpg"}])
        records = described_class.create! klass, table do
          file({ :image => :image_file }, path: "tmp")
        end
        expect(records).to eq [{"image_file" => file}]
      end
    end

    describe "#files" do
      let(:table) { double(hashes: [{"images" => "example.jpg example.png"}]) }

      it "treats the column as a list of file paths and transforms it into an array of opened files" do
        file_1, file_2 = double, double
        expect(File).to receive(:open).with("features/support/fixtures/example.jpg").and_return(file_1)
        expect(File).to receive(:open).with("features/support/fixtures/example.png").and_return(file_2)
        records = described_class.create! klass, table do
          files(:images)
        end
        expect(records).to eq [{"images" => [file_1, file_2]}]
      end

      it "allows configuration of the path and delimiter" do
        table = double(hashes: [{"images" => "example.jpg, example.png"}])
        file_1, file_2 = double, double
        expect(File).to receive(:open).with("tmp/example.jpg").and_return(file_1)
        expect(File).to receive(:open).with("tmp/example.png").and_return(file_2)
        records = described_class.create! klass, table do
          files(:images, path: "tmp", delimiter: ", ")
        end
        expect(records).to eq [{"images" => [file_1, file_2]}]
      end

      it "supports syntactic sugar for renaming on the fly" do
        table = double(hashes: [{"images" => "image.jpg image.png", "icons" => "icon.jpg icon.png"}])
        image_1, image_2, icon_1, icon_2 = double, double, double, double
        expect(File).to receive(:open).with("features/support/fixtures/image.jpg").and_return(image_1)
        expect(File).to receive(:open).with("features/support/fixtures/image.png").and_return(image_2)
        expect(File).to receive(:open).with("features/support/fixtures/icon.jpg").and_return(icon_1)
        expect(File).to receive(:open).with("features/support/fixtures/icon.png").and_return(icon_2)
        records = described_class.create! klass, table do
          files(:images => :image_files, :icons => :icon_files)
        end
        expect(records).to eq [{"image_files" => [image_1, image_2], "icon_files" => [icon_1, icon_2]}]
      end

      it "allows configuration of the path and delimiter with renaming syntax" do
        table =  double(hashes: [{"images" => "example.jpg, example.png"}])
        file_1, file_2 = double, double
        expect(File).to receive(:open).with("tmp/example.jpg").and_return(file_1)
        expect(File).to receive(:open).with("tmp/example.png").and_return(file_2)
        records = described_class.create! klass, table do
          files({ :images => :image_files }, path: "tmp", delimiter: ", ")
        end
        expect(records).to eq [{"image_files" => [file_1, file_2]}]
      end

    end

    describe "#has_one/#belongs_to" do
      it "treats the column as the name of a record of the specified class, and transforms it into that record" do
        user_class, micah = double, double
        allow(user_class).to receive(:find_by!).with(name: "Micah Geisel").and_return(micah)
        stub_const("User", user_class)
        table = double(hashes: [{"user" => "Micah Geisel"}])
        records = described_class.create! klass, table do
          has_one(:user, User)
        end
        expect(records).to eq [{"user" => micah}]
      end

      it "treats an empty value as nil" do
        stub_const("User", double)
        table = double(hashes: [{"user" => ""}])
        records = described_class.create! klass, table do
          has_one(:user, User)
        end
        expect(records).to eq [{"user" => nil}]
      end

      it "supports syntactic sugar for renaming on the fly" do
        user_class, micah = double, double
        allow(user_class).to receive(:find_by!).with(name: "Micah Geisel").and_return(micah)
        stub_const("User", user_class)
        table = double(hashes: [{"user" => "Micah Geisel"}])
        records = described_class.create! klass, table do
          has_one({ :user => :admin }, User)
        end
        expect(records).to eq [{"admin" => micah}]
      end
    end

    describe "#has_many" do
      let(:table) { double(hashes: [{"users" => "Micah Geisel, Michael Gubitosa"}]) }

      it "treats the column as a list of names of records of the specified class, and transforms it into those records" do
        user_class, micah, michael = double, double, double
        allow(user_class).to receive(:find_by!).with(name: "Micah Geisel").and_return(micah)
        allow(user_class).to receive(:find_by!).with(name: "Michael Gubitosa").and_return(michael)
        stub_const("User", user_class)
        records = described_class.create! klass, table do
          has_many(:users, User)
        end
        expect(records).to eq [{"users" => [micah, michael]}]
      end

      it "supports syntactic sugar for renaming on the fly" do
        user_class, micah, michael = double, double, double
        allow(user_class).to receive(:find_by!).with(name: "Micah Geisel").and_return(micah)
        allow(user_class).to receive(:find_by!).with(name: "Michael Gubitosa").and_return(michael)
        stub_const("User", user_class)
        records = described_class.create! klass, table do
          has_many({ :users => :admins }, User)
        end
        expect(records).to eq [{"admins" => [micah, michael]}]
      end
    end
  end
end
