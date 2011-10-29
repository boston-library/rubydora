require 'spec_helper'

describe Rubydora::DigitalObject do
  before do
    @mock_repository = mock(Rubydora::Repository)

  end
  describe "new" do
    it "should load a DigitalObject instance" do
      Rubydora::DigitalObject.new("pid").should be_a_kind_of(Rubydora::DigitalObject)
    end
  end

  describe "profile" do
    before(:each) do
      @object = Rubydora::DigitalObject.new 'pid', @mock_repository
    end

    it "should convert object profile to a simple hash" do
      @mock_repository.should_receive(:object).with(:pid => 'pid').and_return("<objectProfile><a>1</a><b>2</b><objModels><model>3</model><model>4</model></objectProfile>")
      h = @object.profile

      h.should have_key("a")
      h['a'].should == '1'
      h.should have_key("b")
      h['b'].should == '2'
      h.should have_key("objModels")
      h['objModels'].should == ['3', '4']

    end
  end

  describe "new" do
    before(:each) do
      @mock_repository.stub(:object) { raise "" }
      @object = Rubydora::DigitalObject.new 'pid', @mock_repository
    end

    it "should be new" do
      @object.new?.should == true
    end

    it "should call ingest on save" do
      @object.stub(:datastreams) { {} }
      @mock_repository.should_receive(:ingest).with(hash_including(:pid => 'pid')).and_return('pid')
      @object.save
    end

    it "should create a new Fedora object with a generated PID if no PID is provided" do 
      object = Rubydora::DigitalObject.new nil, @mock_repository
      @mock_repository.should_receive(:ingest).with(hash_including(:pid => nil)).and_return('pid')
      @mock_repository.should_receive(:datastreams).with(hash_including(:pid => 'pid')).and_raise(RestClient::ResourceNotFound)
      object.save
      object.pid.should == 'pid'
    end
  end

  describe "create" do
    it "should call the Fedora REST API to create a new object" do
      @mock_repository.should_receive(:ingest).with(instance_of(Hash)).and_return("pid")
      obj = Rubydora::DigitalObject.create "pid", { :a => 1, :b => 2}, @mock_repository
      obj.should be_a_kind_of(Rubydora::DigitalObject)
    end

    it "should return a new object with the Fedora response pid when no pid is provided" do
      @mock_repository.should_receive(:ingest).with(instance_of(Hash)).and_return("pid")
      obj = Rubydora::DigitalObject.create "new", { :a => 1, :b => 2}, @mock_repository
      obj.should be_a_kind_of(Rubydora::DigitalObject)
      obj.pid.should == "pid"
    end
  end

  describe "retreive" do
    before(:each) do
      @mock_repository.stub :datastreams do |hash|
        "<objectDatastreams><datastream dsid='a'></datastream>><datastream dsid='b'></datastream>><datastream dsid='c'></datastream></objectDatastreams>"
      end
      @object = Rubydora::DigitalObject.new 'pid', @mock_repository
    end

    describe "datastreams" do
      it "should provide a hash populated by the existing datastreams" do

        @object.datastreams.should have_key("a")
        @object.datastreams.should have_key("b")
        @object.datastreams.should have_key("c")
      end

      it "should allow other datastreams to be added" do
        @mock_repository.should_receive(:datastream).with(:pid => 'pid', :dsid => 'z').and_raise(RestClient::ResourceNotFound)

        @object.datastreams.length.should == 3

        ds = @object.datastreams["z"]
        ds.should be_a_kind_of(Rubydora::Datastream)
        ds.new?.should == true

        @object.datastreams.length.should == 4
      end

      it "should let datastreams be accessed via hash notation" do

        @object['a'].should be_a_kind_of(Rubydora::Datastream)
        @object['a'].should == @object.datastreams['a']
      end

      it "should provide a way to override the type of datastream object to use" do
        class MyCustomDatastreamClass < Rubydora::Datastream; end
        object = Rubydora::DigitalObject.new 'pid', @mock_repository
        object.stub(:datastream_object_for) do |dsid|
          MyCustomDatastreamClass.new(self, dsid)
        end

        object.datastreams['asdf'].should be_a_kind_of(MyCustomDatastreamClass)
      end
      
    end

  end

  describe "retrieve" do

  end

  describe "save" do
    before(:each) do
      @mock_repository.stub(:object) { <<-XML
      <objectProfile>
        <not>empty</not>
      </objectProfile>
      XML
      }

      @object = Rubydora::DigitalObject.new 'pid', @mock_repository
    end

    describe "saving an object's datastreams" do
      before do
        @new_ds = mock(Rubydora::Datastream)
        @new_ds.stub(:new? => true, :changed? => true, :content_changed? => true, :content => 'XXX')
        @new_empty_ds = mock(Rubydora::Datastream)
        @new_empty_ds.stub(:new? => true, :changed? => false, :content_changed? => false, :content => nil)
        @existing_ds = mock(Rubydora::Datastream)
        @existing_ds.stub(:new? => false, :changed? => false, :content_changed? => false, :content => 'YYY')
        @changed_attr_ds = mock(Rubydora::Datastream)
        @changed_attr_ds.stub(:new? => false, :changed? => true, :content_changed? => false, :content => 'YYY')
        @changed_ds = mock(Rubydora::Datastream)
        @changed_ds.stub(:new? => false, :changed? => true, :content_changed? => true, :content => 'ZZZ')
        @changed_empty_ds = mock(Rubydora::Datastream)
        @changed_empty_ds.stub(:new? => false, :changed? => true, :content_changed? => true, :content => nil)

      end
      it "should save a new datastream with content" do
        @object.stub(:datastreams) { { :new_ds => @new_ds } }
        @new_ds.should_receive(:save)
        @object.save
      end

      it "should save a datastream whose content has changed" do
        @object.stub(:datastreams) { { :changed_ds => @changed_ds } }
        @changed_ds.should_receive(:save)
        @object.save
      end

      it "should save a datastream whose attributes have changed" do
        @object.stub(:datastreams) { { :changed_attr_ds => @changed_attr_ds } }
        @changed_attr_ds.should_receive(:save)
        @object.save
      end

      it "should save an existing datastream whose content is nil" do
        @object.stub(:datastreams) { { :changed_empty_ds => @changed_empty_ds } }
        @changed_empty_ds.should_receive(:save)
        @object.save
      end

      it "should not save a datastream that is unchanged" do
        @object.stub(:datastreams) { { :existing_ds => @existing_ds } }
        @existing_ds.should_not_receive(:save)
        @object.save
      end

      it "should not save a new datastream that never received content" do
        @object.stub(:datastreams) { { :new_empty_ds => @new_empty_ds } }
        @new_empty_ds.should_not_receive(:save)
        @object.save
      end
    end

    it "should save all changed attributes" do
      @object.label = "asdf"
      @object.should_receive(:datastreams).and_return({})
      @mock_repository.should_receive(:modify_object).with(hash_including(:pid => 'pid'))
      @object.save
    end

    it "should reset the object state on save" do
      @object.label = "asdf"
      @object.should_receive(:datastreams).and_return({})
      @mock_repository.should_receive(:modify_object).with(hash_including(:pid => 'pid'))
      @object.profile.should_not be_nil
      expect { @object.save }.to change { @object.instance_variable_get('@profile') }.to nil
    end
  end

  describe "delete" do
    before(:each) do
      @object = Rubydora::DigitalObject.new 'pid', @mock_repository
    end

    it "should call the Fedora REST API" do
      @mock_repository.should_receive(:purge_object).with({:pid => 'pid'})
      @object.delete
    end
  end

  describe "models" do
    before(:each) do
      @mock_repository.stub(:object) { <<-XML
      <objectProfile>
      </objectProfile>
      XML
      }
      @object = Rubydora::DigitalObject.new 'pid', @mock_repository
    end

    it "should add models to fedora" do
      @mock_repository.should_receive(:add_relationship) do |params|
        params.should have_key(:subject)
        params[:predicate].should == 'info:fedora/fedora-system:def/model#hasModel'
        params[:object].should == 'asdf'
      end
      @object.models << "asdf"
    end

    it "should remove models from fedora" do
      @object.should_receive(:profile).any_number_of_times.and_return({"objModels" => ['asdf']})
      @mock_repository.should_receive(:purge_relationship) do |params|
        params.should have_key(:subject)
        params[:predicate].should == 'info:fedora/fedora-system:def/model#hasModel'
        params[:object].should == 'asdf'
      end
      @object.models.delete("asdf")
    end

    it "should be able to handle complete model replacemenet" do
      @object.should_receive(:profile).any_number_of_times.and_return({"objModels" => ['asdf']})
      @mock_repository.should_receive(:add_relationship).with(instance_of(Hash))
      @mock_repository.should_receive(:purge_relationship).with(instance_of(Hash))
      @object.models = '1234'

    end
  end

  describe "relations" do
    before(:each) do
      @mock_repository.stub(:object) { <<-XML
      <objectProfile>
      </objectProfile>
      XML
      }
      @object = Rubydora::DigitalObject.new 'pid', @mock_repository
    end

    it "should fetch related objects using sparql" do
      @mock_repository.should_receive(:find_by_sparql_relationship).with('info:fedora/pid', 'info:fedora/fedora-system:def/relations-external#hasPart').and_return([1])
      @object.parts.should == [1]
    end

    it "should add related objects" do
      @mock_repository.should_receive(:add_relationship) do |params|
        params.should have_key(:subject)
        params[:predicate].should == 'info:fedora/fedora-system:def/relations-external#hasPart'
        params[:object].should == 'asdf'
      end
      @mock_object = mock(Rubydora::DigitalObject)
      @mock_object.should_receive(:fqpid).and_return('asdf')
      @mock_repository.should_receive(:find_by_sparql_relationship).with('info:fedora/pid', 'info:fedora/fedora-system:def/relations-external#hasPart').and_return([])
      @object.parts << @mock_object
    end

    it "should remove related objects" do
      @mock_repository.should_receive(:purge_relationship) do |params|
        params.should have_key(:subject)
        params[:predicate].should == 'info:fedora/fedora-system:def/relations-external#hasPart'
        params[:object].should == 'asdf'
      end
      @mock_object = mock(Rubydora::DigitalObject)
      @mock_object.should_receive(:fqpid).and_return('asdf')
      @mock_repository.should_receive(:find_by_sparql_relationship).with('info:fedora/pid', 'info:fedora/fedora-system:def/relations-external#hasPart').and_return([@mock_object])
      @object.parts.delete(@mock_object)
    end
  end

  describe "to_api_params" do
    before(:each) do
      @object = Rubydora::DigitalObject.new 'pid', @mock_repository
    end
    it "should compile parameters to hash" do
      @object.send(:to_api_params).should == {}
    end
  end
end